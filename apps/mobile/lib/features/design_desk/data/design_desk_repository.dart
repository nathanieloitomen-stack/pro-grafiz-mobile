import 'package:supabase_flutter/supabase_flutter.dart';

/// The five mandatory checks, exact keys per Master Spec §11/CLAUDE.md
/// CAD RULES — not invented, not extended.
const mandatoryCheckKeys = [
  'minimum_bridge_width',
  'thickness_floor',
  'closed_cut_paths',
  'fixing_positions',
  'nesting_efficiency',
];

class DesignJob {
  const DesignJob({required this.id, required this.jobRef, required this.currentStage});

  final String id;
  final String jobRef;
  final String currentStage;

  factory DesignJob.fromJson(Map<String, dynamic> json) {
    return DesignJob(
      id: json['id'] as String,
      jobRef: json['job_ref'] as String,
      currentStage: json['current_stage'] as String,
    );
  }
}

class DraftRecord {
  const DraftRecord({
    required this.id,
    required this.jobId,
    required this.version,
    required this.releaseStatus,
    this.previewPath,
    this.overrideReason,
  });

  final String id;
  final String jobId;
  final int version;
  final String releaseStatus;
  final String? previewPath;
  final String? overrideReason;

  factory DraftRecord.fromJson(Map<String, dynamic> json) {
    return DraftRecord(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      version: json['version'] as int,
      releaseStatus: json['release_status'] as String,
      previewPath: json['preview_path'] as String?,
      overrideReason: json['override_reason'] as String?,
    );
  }
}

class DraftCheckResult {
  const DraftCheckResult({required this.checkKey, required this.result, this.message});

  final String checkKey;
  final String result;
  final String? message;

  factory DraftCheckResult.fromJson(Map<String, dynamic> json) {
    return DraftCheckResult(
      checkKey: json['check_key'] as String,
      result: json['result'] as String,
      message: json['message'] as String?,
    );
  }
}

/// Data access for the Design Desk (PG-010). Draft/draft_checks
/// creation goes directly through Supabase queries — RLS
/// (`drafts_write_designer_or_super_admin`,
/// `draft_checks_write_designer_or_super_admin`, both PG-005) already
/// fully authorizes this, no Edge Function needed. Job-stage
/// transitions and file storage DO need the service-role-backed Edge
/// Functions, since jobs has zero client write policies and the
/// job-drafts bucket has zero client storage policies (both by design).
///
/// UNTESTED against a live backend.
class DesignDeskRepository {
  DesignDeskRepository(this._client);

  final SupabaseClient _client;

  Future<List<DesignJob>> fetchJobsNeedingDesign() async {
    final rows = await _client
        .from('jobs')
        .select('id, job_ref, current_stage')
        .inFilter('current_stage', ['PAYMENT_CONFIRMED', 'DESIGN_IN_PROGRESS'])
        .eq('status', 'active')
        .order('created_at');
    return (rows as List<dynamic>).map((e) => DesignJob.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> startDesign(String jobId) async {
    final response = await _client.functions.invoke('start-design', body: {'job_id': jobId});
    _throwIfError(response.data);
  }

  Future<List<DraftRecord>> fetchDrafts(String jobId) async {
    final rows = await _client
        .from('drafts')
        .select('id, job_id, version, release_status, preview_path, override_reason')
        .eq('job_id', jobId)
        .order('version', ascending: false);
    return (rows as List<dynamic>).map((e) => DraftRecord.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DraftRecord> createDraft(String jobId) async {
    final job = await _client.from('jobs').select('material_id').eq('id', jobId).single();
    final existing = await _client
        .from('drafts')
        .select('version')
        .eq('job_id', jobId)
        .order('version', ascending: false)
        .limit(1);
    final nextVersion = (existing as List<dynamic>).isNotEmpty ? (existing.first['version'] as int) + 1 : 1;
    final row = await _client
        .from('drafts')
        .insert({'job_id': jobId, 'version': nextVersion, 'material_id': job['material_id']})
        .select()
        .single();
    return DraftRecord.fromJson(row);
  }

  Future<List<DraftCheckResult>> fetchChecks(String draftId) async {
    final rows = await _client.from('draft_checks').select('check_key, result, message').eq('draft_id', draftId);
    return (rows as List<dynamic>).map((e) => DraftCheckResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Manual entry only — the designer records what THEY found reviewing
  /// the file. Nothing here computes or infers a result automatically
  /// (automated manufacturing checks are Master Spec §6 V2 scope).
  Future<void> recordCheck(String draftId, String checkKey, String result, {String? message}) async {
    await _client.from('draft_checks').upsert({
      'draft_id': draftId,
      'check_key': checkKey,
      'result': result,
      'message': message,
    }, onConflict: 'draft_id,check_key');
  }

  Future<Map<String, String>> requestUploadUrl(String draftId, String assetType, {String extension = 'png'}) async {
    final response = await _client.functions.invoke(
      'request-draft-upload-url',
      body: {'draft_id': draftId, 'asset_type': assetType, 'extension': extension},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error'] as String);
    return {'signed_url': data['signed_url'] as String, 'token': data['token'] as String, 'path': data['path'] as String};
  }

  Future<String> requestFileUrl(String draftId, String assetType) async {
    final response = await _client.functions.invoke(
      'get-draft-file-url',
      body: {'draft_id': draftId, 'asset_type': assetType},
    );
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error'] as String);
    return data['signed_url'] as String;
  }

  Future<void> release(String draftId, {String? overrideReason}) async {
    final response = await _client.functions.invoke(
      'release-draft',
      body: {'draft_id': draftId, if (overrideReason != null) 'override_reason': overrideReason},
    );
    _throwIfError(response.data);
  }

  void _throwIfError(dynamic data) {
    final map = data as Map<String, dynamic>;
    if (map['error'] != null) throw Exception(map['error'] as String);
  }
}
