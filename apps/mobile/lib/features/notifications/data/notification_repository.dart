import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Data access for the caller's own notifications (PG-013). No
/// authorization logic of its own — `notifications_select_own`/
/// `notifications_update_own` (both PG-005, unmodified) determine
/// visibility and what can be marked read. Every notification here was
/// created by a service-role Edge Function or the
/// `quote_requests` submission trigger — this class never inserts one.
///
/// UNTESTED against a live backend.
class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  Future<List<AppNotification>> fetchAll() async {
    final rows = await _client
        .from('notifications')
        .select('id, type, title, body, read_at, created_at')
        .order('created_at', ascending: false);
    return (rows as List<dynamic>)
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    await _client.from('notifications').update(
        {'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
  }
}
