import 'package:supabase_flutter/supabase_flutter.dart';

/// Data access for generated PGJO/PGAO documents (PG-011). No
/// authorization logic of its own — `documents_select_own_or_staff`
/// (PG-005) decides what the caller can see.
///
/// UNTESTED against a live backend.
class DocumentRepository {
  DocumentRepository(this._client);

  final SupabaseClient _client;

  /// Which document types exist for this job — used to decide whether
  /// to show a "View" button at all, without needing a signed URL just
  /// to check existence.
  Future<Set<String>> fetchAvailableTypes(String jobId) async {
    final rows =
        await _client.from('documents').select('type').eq('job_id', jobId);
    return (rows as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['type'] as String)
        .toSet();
  }

  Future<String> requestUrl(String jobId, String type) async {
    final response = await _client.functions
        .invoke('get-document-url', body: {'job_id': jobId, 'type': type});
    final data = response.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error'] as String);
    return data['signed_url'] as String;
  }
}
