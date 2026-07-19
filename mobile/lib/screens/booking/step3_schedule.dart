import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/booking_service.dart';
import '../../models/slot.dart';
import '../../theme/app_theme.dart';
import 'booking_flow.dart';

const Map<String, String> _installAreaLabels = {
  'FULL': 'รอบคัน',
  'FRONT_BACK': 'กระจกหน้า-หลัง',
  'FRONT': 'กระจกหน้า',
  'BACK': 'กระจกหลัง',
};

/// Step 3/5 ของ booking flow (Figma page 11): เลือกวันที่และเวลานัดหมาย.
///
/// - การ์ดสรุปสิ่งที่เลือกใน step 2 (ฟิล์ม/แพ็กเกจ/รอใบเสนอราคา) + ปุ่ม
///   "เปลี่ยน" (ย้อน step 2)
/// - "01 เลือกวันที่": แถบเลื่อนแนวนอน 14 วันข้างหน้า (รวมวันนี้)
/// - เลือกวันแล้วโหลด `BookingService.fetchSlots` → "02 เลือกเวลา": grid
///   ชิปเวลา (ว่าง/เต็ม)
/// - แถบล่าง: สรุปวันเวลาที่เลือก + ปุ่ม "ยืนยันเวลา"
class Step3Schedule extends StatefulWidget {
  const Step3Schedule({
    super.key,
    required this.draft,
    required this.onNext,
    required this.onBack,
  });

  final BookingDraft draft;
  final VoidCallback onNext;

  /// Invoked by the "เปลี่ยน" button next to the selection summary card, to
  /// go back to step 2.
  final VoidCallback onBack;

  @override
  State<Step3Schedule> createState() => _Step3ScheduleState();
}

class _Step3ScheduleState extends State<Step3Schedule> {
  late final List<DateTime> _days;
  DateTime? _selectedDate;
  String? _selectedSlot;

  List<Slot> _slots = [];
  bool _loadingSlots = false;
  String? _slotsError;

  @override
  void initState() {
    super.initState();
    // The symbol data for all locales (including "th") is bundled directly
    // in the intl package and populated synchronously by the time this
    // call returns, so it's safe to use DateFormat(..., 'th') immediately
    // afterwards without awaiting anything or gating the first build.
    initializeDateFormatting('th');

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    _days = List.generate(14, (i) => todayMidnight.add(Duration(days: i)));

    final restoredDate = widget.draft.date;
    _selectedDate =
        restoredDate != null && _days.any((d) => _isSameDay(d, restoredDate))
        ? restoredDate
        : null;
    _selectedSlot = widget.draft.timeSlot;
    if (_selectedDate != null) {
      _loadSlots(_selectedDate!);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedSlot = null;
      _slots = [];
    });
    _loadSlots(date);
  }

  Future<void> _loadSlots(DateTime date) async {
    final serviceId = widget.draft.service?.id;
    if (serviceId == null) return;
    setState(() {
      _loadingSlots = true;
      _slotsError = null;
    });
    try {
      final slots = await BookingService.instance.fetchSlots(serviceId, date);
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _loadingSlots = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _slotsError = e.message;
        _loadingSlots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _slotsError = 'โหลดเวลาว่างไม่สำเร็จ';
        _loadingSlots = false;
      });
    }
  }

  void _selectSlot(String slot) {
    setState(() => _selectedSlot = slot);
  }

  bool get _canConfirm => _selectedDate != null && _selectedSlot != null;

  void _confirm() {
    widget.draft.date = _selectedDate;
    widget.draft.timeSlot = _selectedSlot;
    widget.onNext();
  }

  String get _summaryCardText {
    final name = widget.draft.service?.name ?? '';
    if (name.contains('ฟิล์ม')) {
      final productName = widget.draft.product?.name ?? '-';
      final area = _installAreaLabels[widget.draft.installArea] ?? '-';
      return 'ฟิล์มที่เลือก $productName บริเวณที่ติดตั้ง: $area';
    }
    if (name.contains('ล้าง')) {
      return widget.draft.product?.name ?? 'แพ็กเกจที่เลือก';
    }
    return 'รอใบเสนอราคาหลังส่งคำจอง';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(),
                const SizedBox(height: 20),
                const Text(
                  '01 เลือกวันที่',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildDateStrip(),
                const SizedBox(height: 24),
                const Text(
                  '02 เลือกเวลา',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildSlotGrid(),
              ],
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _summaryCardText,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: widget.onBack, child: const Text('เปลี่ยน')),
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = _days[index];
          final selected =
              _selectedDate != null && _isSameDay(day, _selectedDate!);
          final dayLabel = DateFormat('EEEEE', 'th').format(day);
          return GestureDetector(
            onTap: () => _selectDate(day),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: selected ? AppColors.primaryDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primaryDark : Colors.grey.shade300,
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dayLabel,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotGrid() {
    if (_selectedDate == null) {
      return const Text(
        'กรุณาเลือกวันที่ก่อน',
        style: TextStyle(color: Colors.black54),
      );
    }
    if (_loadingSlots) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_slotsError != null) {
      return Text(_slotsError!, style: const TextStyle(color: Colors.red));
    }
    if (_slots.isEmpty) {
      return const Text(
        'ไม่มีเวลาว่างในวันนี้',
        style: TextStyle(color: Colors.black54),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _slots.map((slot) {
        final selected = _selectedSlot == slot.timeSlot;
        return _SlotChip(
          slot: slot,
          selected: selected,
          onTap: slot.available ? () => _selectSlot(slot.timeSlot) : null,
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar() {
    final summaryText = _canConfirm
        ? 'วันเวลาที่เลือก: '
              '${DateFormat('EEEE d MMMM', 'th').format(_selectedDate!)} '
              'เวลา $_selectedSlot'
        : 'กรุณาเลือกวันและเวลา';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summaryText,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _canConfirm ? _confirm : null,
              child: const Text('ยืนยันเวลา'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot, required this.selected, this.onTap});

  final Slot slot;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final full = !slot.available;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: full
              ? Colors.grey.shade200
              : (selected ? AppColors.primaryDark : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: full ? Colors.grey.shade300 : AppColors.primary,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slot.timeSlot,
              style: TextStyle(
                color: full
                    ? Colors.grey.shade500
                    : (selected ? Colors.white : AppColors.primary),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (full) ...[
              const SizedBox(height: 2),
              Text('เต็ม', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ],
        ),
      ),
    );
  }
}
