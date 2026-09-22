import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/notification_service.dart';
import '../../models/notification_item.dart';
import '../../theme/app_theme.dart';
import '../bookings/booking_detail_screen.dart';

/// แท็บ "แจ้งเตือน" (Task 8, Figma page 14): รายการแจ้งเตือนของผู้ใช้ จัดกลุ่ม
/// ตามวัน "วันนี้/เมื่อวานนี้/ก่อนหน้า", แตะแถวเพื่อ mark read (แล้วเปิดหน้า
/// รายละเอียดการจองถ้ามี `bookingId`), ปุ่ม "อ่านทั้งหมด" มุมบนเพื่อ mark
/// ทุกรายการเป็นอ่านแล้วในคราวเดียว.
///
/// [onUnreadCountChanged] lets [MainShell] keep the bottom-nav badge in
/// sync without this screen needing to know about the shell at all.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.onUnreadCountChanged});

  final ValueChanged<int>? onUnreadCountChanged;

  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

/// Public so [MainShell] can hold a `GlobalKey<NotificationsScreenState>`
/// and call [reload] whenever the notifications tab is switched to, or a
/// live push arrives — the tab body lives inside an `IndexedStack` and stays
/// mounted, so without this a notification created while the screen was
/// already built would stay invisible until the next full app restart.
class NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem>? _notifications;
  String? _error;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th');
    _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await NotificationService.instance.fetchMine();
      if (!mounted) return;
      setState(() => _notifications = items);
      _reportUnreadCount();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดข้อมูลไม่สำเร็จ');
    }
  }

  void _reportUnreadCount() {
    final items = _notifications;
    if (items == null) return;
    widget.onUnreadCountChanged?.call(items.where((n) => !n.isRead).length);
  }

  Future<void> _handleTap(NotificationItem item) async {
    if (!item.isRead) {
      _markReadLocally(item.id);
      try {
        await NotificationService.instance.markRead(item.id);
      } catch (_) {
        // Best-effort: the row already flipped to read locally, and a
        // failed mark-read isn't worth interrupting navigation for.
      }
    }
    final bookingId = item.bookingId;
    if (bookingId != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingDetailScreen(bookingId: bookingId),
        ),
      );
    }
  }

  void _markReadLocally(int id) {
    final items = _notifications;
    if (items == null) return;
    setState(() {
      _notifications = [
        for (final n in items)
          if (n.id == id)
            NotificationItem(
              id: n.id,
              title: n.title,
              body: n.body,
              type: n.type,
              bookingId: n.bookingId,
              createdAt: n.createdAt,
              readAt: DateTime.now(),
            )
          else
            n,
      ];
    });
    _reportUnreadCount();
  }

  Future<void> _markAllRead() async {
    final items = _notifications;
    if (items == null || items.every((n) => n.isRead)) return;
    final now = DateTime.now();
    setState(() {
      _notifications = [
        for (final n in items)
          NotificationItem(
            id: n.id,
            title: n.title,
            body: n.body,
            type: n.type,
            bookingId: n.bookingId,
            createdAt: n.createdAt,
            readAt: n.readAt ?? now,
          ),
      ];
    });
    _reportUnreadCount();
    try {
      await NotificationService.instance.markAllRead();
    } catch (_) {
      // Best-effort, same rationale as _handleTap.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แจ้งเตือน'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('อ่านทั้งหมด'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final items = _notifications;
    if (items == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && items == null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 96),
            Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
    if (items!.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 96),
            Center(
              child: Text(
                'ยังไม่มีการแจ้งเตือน',
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }

    final groups = _groupByDay(items);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                ),
              ),
            ),
            ...entry.value.map(
              (item) => _NotificationTile(
                item: item,
                onTap: () => _handleTap(item),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Groups notifications under "วันนี้"/"เมื่อวานนี้"/"ก่อนหน้า" headers
  /// (only non-empty groups are included, in that fixed order), preserving
  /// the order the backend returned them in within each group.
  Map<String, List<NotificationItem>> _groupByDay(
    List<NotificationItem> items,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<NotificationItem>>{
      'วันนี้': [],
      'เมื่อวานนี้': [],
      'ก่อนหน้า': [],
    };
    for (final item in items) {
      final createdLocal = item.createdAt.toLocal();
      final day = DateTime(
        createdLocal.year,
        createdLocal.month,
        createdLocal.day,
      );
      if (day == today) {
        groups['วันนี้']!.add(item);
      } else if (day == yesterday) {
        groups['เมื่อวานนี้']!.add(item);
      } else {
        groups['ก่อนหน้า']!.add(item);
      }
    }
    groups.removeWhere((_, value) => value.isEmpty);
    return groups;
  }
}

/// Relative time per the Figma spec: minutes for <1h, hours for <1 day, and
/// a Thai-formatted date beyond that.
String _relativeTime(DateTime createdAt) {
  final now = DateTime.now();
  final diff = now.difference(createdAt.toLocal());
  if (diff.inDays >= 1) {
    return DateFormat('d MMM yyyy', 'th').format(createdAt.toLocal());
  }
  if (diff.inHours >= 1) {
    return '${diff.inHours} ชม.ที่ผ่านมา';
  }
  final minutes = diff.inMinutes < 1 ? 1 : diff.inMinutes;
  return '$minutes นาทีที่แล้ว';
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unread ? AppColors.surfaceLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.surfaceLight,
              child: Icon(Icons.notifications, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: unread ? AppColors.primary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.body,
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(item.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                key: ValueKey('unread-dot-${item.id}'),
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
