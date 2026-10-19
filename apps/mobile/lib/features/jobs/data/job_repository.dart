import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/job_summary.dart';

/// Data access for the customer's own jobs (approved screen #7).
/// Everything here relies on PG-005's RLS for what a caller can
/// actually see — no authorization logic of its own, matching
/// CatalogueRepository's and QuoteRepository's design from PG-006/007.
///
/// UNTESTED against a live backend.
class JobRepository {
  JobRepository(this._client);

  final SupabaseClient _client;

  Future<List<JobSummary>> fetchMyJobs() async {
    final rows = await _client
        .from('jobs')
        .select('id, job_ref, current_stage, status')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => JobSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JobDetail> fetchJobDetail(String jobId) async {
    final job = await _client
        .from('jobs')
        .select(
            'id, job_ref, current_stage, status, hold_reason, hold_note, cancel_reason, cancel_note, quote_id')
        .eq('id', jobId)
        .single();

    // drafts/quotes may legitimately be empty at this stage of the
    // build (no payment/pricing wired to auto-issue a quote yet outside
    // decide-quote-request) — absence is handled gracefully, not
    // treated as an error.
    String? previewPath;
    var hasReleasedDraft = false;
    try {
      final drafts = await _client
          .from('drafts')
          .select('preview_path, release_status')
          .eq('job_id', jobId)
          .order('version', ascending: false);
      for (final row in drafts as List<dynamic>) {
        final draft = row as Map<String, dynamic>;
        previewPath ??= draft['preview_path'] as String?;
        if (draft['release_status'] == 'released') hasReleasedDraft = true;
      }
    } catch (_) {
      // No access or none exist yet — fine, leave defaults.
    }

    int? totalKobo;
    final quoteId = job['quote_id'] as String?;
    if (quoteId != null) {
      try {
        final quoteRow = await _client
            .from('quotes')
            .select('total_kobo')
            .eq('id', quoteId)
            .maybeSingle();
        totalKobo = (quoteRow?['total_kobo'] as num?)?.toInt();
      } catch (_) {
        // No access or not found — fine.
      }
    }

    return JobDetail.fromJson(job,
        hasReleasedDraft: hasReleasedDraft,
        previewPath: previewPath,
        totalKobo: totalKobo);
  }

  Future<List<Map<String, dynamic>>> fetchStageHistory(String jobId) async {
    final rows = await _client
        .from('job_stage_history')
        .select('stage, entered_at, customer_action, note')
        .eq('job_id', jobId)
        .order('entered_at');
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> approve(String jobId) async {
    final response = await _client.functions.invoke(
      'respond-to-design',
      body: {'job_id': jobId, 'action': 'approve'},
    );
    _throwIfError(response.data);
  }

  Future<void> requestChange(String jobId, String note) async {
    final response = await _client.functions.invoke(
      'respond-to-design',
      body: {'job_id': jobId, 'action': 'request_change', 'request_note': note},
    );
    _throwIfError(response.data);
  }

  void _throwIfError(dynamic data) {
    final map = data as Map<String, dynamic>;
    if (map['error'] != null) {
      throw Exception(map['error'] as String);
    }
  }
}
