import 'package:flutter/material.dart';

import '../../models/booking.dart';
import '../../state/technician_queue_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/thai_date.dart';
import '../../widgets/job_card.dart';
import '../../widgets/tech_header.dart';
import '../jobs/job_detail_screen.dart';

/// "ปฏิทิน" — month grid of assigned jobs, matching the mockup but backed
/// by the real queue instead of a single hardcoded month of demo data.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _controller = TechnicianQueueController.instance;
  late DateTime _month;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
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

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final jobsThisMonth = _controller.bookings
        .where((b) => b.status != 'CANCELLED' && b.bookingDate.year == _month.year && b.bookingDate.month == _month.month)
        .toList();
    final daysWithJobs = jobsThisMonth.map((b) => b.bookingDate.day).toSet();

    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1; // Monday = 1 -> 0 blanks

    final selectedInMonth = _selectedDay.year == _month.year && _selectedDay.month == _month.month;
    final dayJobs = selectedInMonth
        ? (_controller.bookings.where((b) => b.status != 'CANCELLED' && isSameDay(b.bookingDate, _selectedDay)).toList()
          ..sort((a, b) => a.timeSlot.compareTo(b.timeSlot)))
        : <Booking>[];

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: TechHeader.withBack(title: 'ปฏิทิน', onBack: () => Navigator.of(context).pop()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MonthArrow(icon: Icons.chevron_left, onTap: () => _changeMonth(-1)),
              Text(
                '${monthsTh[_month.month - 1]} ${buddhistYear(_month.year)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink900),
              ),
              _MonthArrow(icon: Icons.chevron_right, onTap: () => _changeMonth(1)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final label in weekdaysThShort)
                Expanded(
                  child: Center(
                    child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.ink500, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            children: [
              for (int i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
              for (int day = 1; day <= daysInMonth; day++)
                _DayCell(
                  day: day,
                  hasJob: daysWithJobs.contains(day),
                  selected: selectedInMonth && _selectedDay.day == day,
                  onTap: () => setState(() => _selectedDay = DateTime(_month.year, _month.month, day)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              _LegendDot(),
              SizedBox(width: 6),
              Text('มีงาน', style: TextStyle(fontSize: 12, color: AppColors.ink700)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.ink100))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedInMonth ? thaiFullDate(_selectedDay) : '',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink900),
                  ),
                ),
                Text(
                  'มีทั้งหมด ${dayJobs.length} งาน',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ],
            ),
          ),
          if (dayJobs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('ไม่มีงานในวันนี้', style: TextStyle(color: AppColors.ink500, fontSize: 12.5))),
            )
          else
            for (final booking in dayJobs) ...[
              JobCard(
                booking: booking,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => JobDetailScreen(bookingId: booking.id)),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, size: 18, color: Colors.white)),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.hasJob, required this.selected, required this.onTap});

  final int day;
  final bool hasJob;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primaryDark : (hasJob ? AppColors.surfaceLight : Colors.transparent);
    final fg = selected ? Colors.white : (hasJob ? AppColors.primary : AppColors.ink900);
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Center(
          child: Text(
            '$day',
            style: TextStyle(fontSize: 13, fontWeight: selected || hasJob ? FontWeight.w800 : FontWeight.w600, color: fg),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2),
      ),
    );
  }
}
