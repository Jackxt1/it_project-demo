import 'package:flutter/material.dart';

import '../../models/booking.dart';
import '../../state/technician_queue_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/job_card.dart';
import '../../widgets/tech_header.dart';
import '../jobs/job_detail_screen.dart';

/// "ประวัติงาน" — completed (and cancelled) jobs, most recent first.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _controller = TechnicianQueueController.instance;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    if (!_controller.loadedOnce) {
      _controller.refresh();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final history = _controller.bookings
        .where((b) => b.status == 'COMPLETED' || b.status == 'CANCELLED')
        .toList()
      ..sort((a, b) {
        final byDate = b.bookingDate.compareTo(a.bookingDate);
        if (byDate != 0) return byDate;
        return b.timeSlot.compareTo(a.timeSlot);
      });

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: TechHeader.simple(title: 'ประวัติงาน'),
      body: RefreshIndicator(
        onRefresh: _controller.refresh,
        child: _controller.loading && !_controller.loadedOnce
            ? const Center(child: CircularProgressIndicator())
            : history.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 64),
                        child: Center(
                          child: Text('ยังไม่มีงานที่เสร็จสิ้น', style: TextStyle(color: AppColors.ink500)),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    children: [
                      Text(
                        'งานที่เสร็จสิ้นแล้ว (${history.length})',
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink900),
                      ),
                      const SizedBox(height: 10),
                      for (final booking in history) ...[
                        JobCard(
                          booking: booking,
                          showDate: true,
                          onTap: () => _openDetail(context, booking),
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
