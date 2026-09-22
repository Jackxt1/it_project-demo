import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/notification_service.dart';
import '../../models/notification_item.dart';
import '../../state/technician_queue_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tech_header.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await NotificationService.instance.fetchMine();
      if (!mounted) return;
      setState(() => _items = items);
      // Resyncs the shared badge (see MainShell/TechBrandRow) with reality
      // — the live socket only ever increments it, so without this a
      // manual refresh/mark-read here would otherwise leave it stale.
      TechnicianQueueController.instance.setUnreadNotificationCount(
        items.where((n) => !n.isRead).length,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดการแจ้งเตือนไม่สำเร็จ');
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.isRead) return;
    try {
      await NotificationService.instance.markRead(item.id);
      await _load();
    } catch (_) {
      // Best-effort — the list will just show it unread until next refresh.
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationService.instance.markAllRead();
      await _load();
    } catch (_) {
      // no-op
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final hasUnread = items != null && items.any((n) => !n.isRead);
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: TechHeader.withBack(title: 'การแจ้งเตือน', onBack: () => Navigator.of(context).pop()),
      body: RefreshIndicator(
        onRefresh: _load,
        child: items == null
            ? (_error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator()))
            : items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: Center(child: Text('ไม่มีการแจ้งเตือน', style: TextStyle(color: AppColors.ink500))),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    children: [
                      if (hasUnread)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _markAllRead,
                            child: const Text('อ่านทั้งหมด', style: TextStyle(color: AppColors.primaryDark)),
                          ),
                        ),
                      for (final item in items)
                        _NotificationTile(item: item, onTap: () => _markRead(item)),
                    ],
                  ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.ink100)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: item.isRead ? AppColors.ink300 : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink900)),
                  const SizedBox(height: 3),
                  Text(item.body, style: const TextStyle(fontSize: 11.5, color: AppColors.ink500)),
                ],
              ),
            ),
            Text(_relativeTime(item.createdAt), style: const TextStyle(fontSize: 10.5, color: AppColors.ink500)),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
    return '${diff.inDays} วันที่แล้ว';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.ink300),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.ink500)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onRetry, child: const Text('ลองใหม่')),
          ],
        ),
      ),
    );
  }
}
