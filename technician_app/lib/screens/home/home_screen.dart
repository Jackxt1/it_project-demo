import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/auth_service.dart';
import '../../models/booking.dart';
import '../../state/technician_queue_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/thai_date.dart';
import '../../widgets/bounce_on_change.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/job_card.dart';
import '../../widgets/tech_header.dart';
import '../calendar/calendar_screen.dart';
import '../jobs/job_detail_screen.dart';
import '../notifications/notifications_screen.dart';

/// "ตารางงานของฉัน" — today's queue. Scoped to today (rather than the
/// mockup's flat all-time job list) so it reads as an actual daily work
/// schedule; other dates are reachable via the calendar icon, and completed
/// jobs from any date live in the ประวัติ tab.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TechnicianQueueController.instance;
  StreamSubscription<Booking>? _newJobSub;

  /// The id of whatever job the live socket most recently pushed in, so its
  /// card can pop/glow for a moment — otherwise a new job silently joining
  /// the list reads as "nothing happened" even though it did.
  int? _justArrivedId;
  Timer? _justArrivedTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    if (!_controller.loadedOnce) {
      _controller.refresh();
    }
    _newJobSub = _controller.onNewJobAssigned.listen((booking) {
      if (!mounted) return;
      setState(() => _justArrivedId = booking.id);
      _justArrivedTimer?.cancel();
      _justArrivedTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _justArrivedId = null);
      });
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _newJobSub?.cancel();
    _justArrivedTimer?.cancel();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayJobs = _controller.bookings
        .where((b) => b.status != 'CANCELLED' && isSameDay(b.bookingDate, today))
        .toList();
    final total = todayJobs.length;
    final done = todayJobs.where((b) => b.status == 'COMPLETED').length;
    final remaining = total - done;
    final technicianName = AuthService.instance.session?.fullName ?? '';

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: TechHeader.brand(
        title: 'ตารางงานของฉัน',
        date: thaiFullDate(today),
        brandRow: TechBrandRow(
          technicianName: technicianName,
          hasUnreadNotifications: _controller.unreadNotifications > 0,
          onCalendarTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          ),
          onNotificationsTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _controller.refresh,
        child: _controller.loading && !_controller.loadedOnce
            ? const Center(child: CircularProgressIndicator())
            : _controller.error != null && todayJobs.isEmpty
                ? _ErrorState(message: _controller.error!, onRetry: _controller.refresh)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(child: _StatCard(label: 'งานทั้งหมด', value: total, color: AppColors.primary)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(label: 'เหลืออยู่', value: remaining, color: AppColors.amber)),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(label: 'เสร็จแล้ว', value: done, color: AppColors.green)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (todayJobs.isEmpty)
                        const _EmptyToday()
                      else
                        for (final entry in todayJobs.asMap().entries) ...[
                          FadeSlideIn(
                            index: entry.key,
                            child: _HighlightableJobCard(
                              booking: entry.value,
                              justArrived: entry.value.id == _justArrivedId,
                              onTap: () => _openDetail(context, entry.value),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                    ],
                  ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Booking booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JobDetailScreen(bookingId: booking.id)),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        children: [
          BounceOnChange(
            trigger: value,
            child: Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.ink700)),
        ],
      ),
    );
  }
}

/// Wraps [JobCard] with a temporary red glow/border while [justArrived] is
/// true — the visible cue that a job on screen just came in live, not just
/// "a card that happens to be there". See [_HomeScreenState._justArrivedId].
class _HighlightableJobCard extends StatelessWidget {
  const _HighlightableJobCard({
    required this.booking,
    required this.justArrived,
    required this.onTap,
  });

  final Booking booking;
  final bool justArrived;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: justArrived ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
        boxShadow: justArrived
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, spreadRadius: 1)]
            : const [],
      ),
      child: JobCard(booking: booking, onTap: onTap),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.event_available, size: 40, color: AppColors.ink300),
          const SizedBox(height: 10),
          const Text('วันนี้ไม่มีงานที่ได้รับมอบหมาย', style: TextStyle(color: AppColors.ink500, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
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
          ),
        ),
      ),
    );
  }
}
