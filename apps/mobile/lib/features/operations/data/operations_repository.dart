import 'package:supabase_flutter/supabase_flutter.dart';

class PendingQuoteRequest {
  const PendingQuoteRequest({required this.id, required this.status, required this.createdAt});

  final String id;
  final String status;
  final DateTime createdAt;

  factory PendingQuoteRequest.fromJson(Map<String, dynamic> json) {
    return PendingQuoteRequest(
      id: json['id'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class OperationalJob {
  const OperationalJob({
    required this.id,
    required this.jobRef,
    required this.currentStage,
    required this.status,
    required this.stageStartedAt,
  });

  final String id;
  final String jobRef;
  final String currentStage;
  final String status;
  final DateTime stageStartedAt;

  factory OperationalJob.fromJson(Map<String, dynamic> json) {
    return OperationalJob(
      id: json['id'] as String,
      jobRef: json['job_ref'] as String,
      currentStage: json['current_stage'] as String,
      status: json['status'] as String,
      stageStartedAt: DateTime.parse(json['stage_started_at'] as String),
    );
  }
}

/// Data access for Intake, Job Queue, and the operations dashboard
/// (PG-012). Every list here is a plain query — visibility comes
/// entirely from existing RLS (`quote_requests_select_own_or_staff`,
/// `jobs_select_own_or_staff`, both PG-005, unmodified): a Centre
/// Manager session automatically sees only their own branch, with no
/// extra filtering logic in this class. This is the concrete
/// implementation of "no client-side authorization as a substitute for
/// database/server authorization" — this repository could not leak
/// another branch's data even if its own filtering logic had a bug,
/// because RLS is the actual boundary, not this code.
///
/// UNTESTED against a live backend.
class OperationsRepository {
  OperationsRepository(this._client);

  final SupabaseClient _client;

  Future<List<PendingQuoteRequest>> fetchPendingQuoteRequests() async {
    final rows = await _client
        .from('quote_requests')
        .select('id, status, created_at')
        .eq('status', 'pending')
        .order('created_at');
    return (rows as List<dynamic>).map((e) => PendingQuoteRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> decideQuoteRequest(String id, {required bool accept, String? reason}) async {
    final response = await _client.functions.invoke(
      'decide-quote-request',
      body: {'quote_request_id': id, 'decision': accept ? 'accept' : 'decline', if (reason != null) 'decision_reason': reason},
    );
    _throwIfError(response.data);
  }

  Future<List<OperationalJob>> fetchActiveJobs() async {
    final rows = await _client
        .from('jobs')
        .select('id, job_ref, current_stage, status, stage_started_at')
        .neq('current_stage', 'RELEASED')
        .order('stage_started_at');
    return (rows as List<dynamic>).map((e) => OperationalJob.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> hold(String jobId, String reason, {String? note}) async {
    final response = await _client.functions.invoke(
      'hold-job',
      body: {'job_id': jobId, 'hold_reason': reason, if (note != null) 'hold_note': note},
    );
    _throwIfError(response.data);
  }

  Future<void> resume(String jobId) async {
    final response = await _client.functions.invoke('resume-job', body: {'job_id': jobId});
    _throwIfError(response.data);
  }

  Future<void> cancel(String jobId, String reason, {String? note}) async {
    final response = await _client.functions.invoke(
      'cancel-job',
      body: {'job_id': jobId, 'cancel_reason': reason, if (note != null) 'cancel_note': note},
    );
    _throwIfError(response.data);
  }

  Future<void> reopen(String jobId) async {
    final response = await _client.functions.invoke('reopen-job', body: {'job_id': jobId});
    _throwIfError(response.data);
  }

  /// Basic counts for the operations dashboard — no approved pixel
  /// design exists for this screen (Master Spec names "Basic management
  /// dashboard" as a V1 bullet with no further detail); this reflects
  /// whatever the caller's own RLS-scoped view already shows elsewhere,
  /// just summarized.
  Future<Map<String, int>> fetchDashboardCounts() async {
    final jobs = await fetchActiveJobs();
    final pendingRequests = await fetchPendingQuoteRequests();
    final counts = <String, int>{'pending_requests': pendingRequests.length};
    for (final job in jobs) {
      counts[job.currentStage] = (counts[job.currentStage] ?? 0) + 1;
    }
    counts['on_hold'] = jobs.where((j) => j.status == 'on_hold').length;
    counts['cancelled'] = jobs.where((j) => j.status == 'cancelled').length;
    return counts;
  }

  void _throwIfError(dynamic data) {
    final map = data as Map<String, dynamic>;
    if (map['error'] != null) throw Exception(map['error'] as String);
  }
}
