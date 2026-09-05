import 'package:flutter/material.dart';

import '../../../shared/design_system/design_system.dart';
import '../data/notification_repository.dart';

/// In-app notification inbox (PG-013). No push delivery (FCM) is wired
/// up anywhere in this codebase — see docs/notifications.md for why —
/// so this in-app list is currently the only way a customer or staff
/// member sees a notification at all; there is no external ping telling
/// them to open it.
///
/// UNTESTED against a live backend.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.repository});

  final NotificationRepository repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification>? _notifications;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notifications = await widget.repository.fetchAll();
      if (!mounted) return;
      setState(() => _notifications = notifications);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load notifications.');
    }
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.isRead) {
      try {
        await widget.repository.markRead(notification.id);
        _load();
      } catch (_) {
        // Non-fatal — the notification is still readable even if
        // marking it read fails.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PGColors.paper,
      appBar: AppBar(
        backgroundColor: PGColors.paper,
        elevation: 0,
        title: Text('Notifications', style: PGTextStyles.cardTitle.copyWith(color: PGColors.ink, fontSize: 20)),
      ),
      body: SafeArea(
        child: _error != null
            ? Center(child: Text(_error!, style: PGTextStyles.body.copyWith(color: PGColors.dangerFg)))
            : _notifications == null
                ? const Center(child: CircularProgressIndicator())
                : _notifications!.isEmpty
                    ? Center(child: Text('No notifications yet.', style: PGTextStyles.body.copyWith(color: PGColors.textSoft)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(PGSpacing.screenHorizontal),
                        itemCount: _notifications!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final notification = _notifications![index];
                          return PGPressable(
                            onTap: () => _open(notification),
                            child: PGCard(
                              background: notification.isRead ? Colors.white : PGColors.paperWarm,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notification.title,
                                          style: PGTextStyles.body.copyWith(
                                            fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w700,
                                            color: PGColors.ink,
                                          ),
                                        ),
                                      ),
                                      if (!notification.isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(color: PGColors.ember, shape: BoxShape.circle),
                                        ),
                                    ],
                                  ),
                                  if (notification.body != null) ...[
                                    const SizedBox(height: 4),
                                    Text(notification.body!, style: PGTextStyles.caption.copyWith(color: PGColors.textSoft)),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
