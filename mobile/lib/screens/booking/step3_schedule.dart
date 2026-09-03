import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/booking_service.dart';
import '../../models/booking.dart';
import '../../models/booking_draft.dart';
import '../../models/slot.dart';
import '../../theme/app_theme.dart';

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
    required this.onBookingCreated,
  });

  final BookingDraft draft;

  /// Advances to step 4 (payment) — used for film/wash drafts only.
  final VoidCallback onNext;

  /// Invoked by the "เปลี่ยน" button next to the selection summary card, to
  /// go back to step 2.
  final VoidCallback onBack;

  /// Repair drafts skip step 4 entirely: confirming here calls
  /// `createBooking` directly (without paymentType/paidAmount) and, on
  /// success, this callback jumps the flow straight to step 5.
  final void Function(Booking booking) onBookingCreated;

  @override
  State<Step3Schedule> createState() => _Step3ScheduleState();
}

class _Step3ScheduleState extends State<Step3Schedule> {
  late final DateTime _today;
  late final DateTime _lastSelectableDate;
  DateTime? _selectedDate;
  String? _selectedSlot;

  List<Slot> _slots = [];
  bool _loadingSlots = false;
  String? _slotsError;

  bool _submitting = false;
  String? _submitError;

  BookingMode get _mode => bookingModeFor(widget.draft.service);

  @override
  void initState() {
    super.initState();
    // The symbol data for all locales (including "th") is bundled directly
    // in the intl package and populated synchronously by the time this
    // call returns, so it's safe to use DateFormat(..., 'th') immediately
    // afterwards without awaiting anything or gating the first build.
    initializeDateFormatting('th');

    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    // A generous one-year booking horizon — the calendar itself lets staff
    // and customers browse month to month, this just bounds how far ahead
    // slots can be requested at all.
    _lastSelectableDate = DateTime(now.year + 1, now.month, now.day);

    final restoredDate = widget.draft.date;
    _selectedDate = restoredDate != null && !restoredDate.isBefore(_today)
        ? DateTime(restoredDate.year, restoredDate.month, restoredDate.day)
        : null;
    _selectedSlot = widget.draft.timeSlot;
    if (_selectedDate != null) {
      _loadSlots(_selectedDate!);
    }
  }

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

  bool get _hasSelection => _selectedDate != null && _selectedSlot != null;

  bool get _canConfirm => _hasSelection && !_submitting;

  void _confirm() {
    widget.draft.date = _selectedDate;
    widget.draft.timeSlot = _selectedSlot;
    if (_mode == BookingMode.repair) {
      _submitRepairBooking();
    } else {
      widget.onNext();
    }
  }

  /// Repair drafts have no step 4 (payment) — this sends the booking
  /// straight to the backend with `budget`/`imageUrl` (no
  /// `paymentType`/`paidAmount`, since nothing has been paid yet) and hands
  /// the result to [Step3Schedule.onBookingCreated] to jump to step 5.
  Future<void> _submitRepairBooking() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final booking = await BookingService.instance.createBooking(
        widget.draft,
      );
      if (!mounted) return;
      widget.onBookingCreated(booking);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitError = e.message;
        _submitting = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitError = 'ส่งคำจองไม่สำเร็จ';
        _submitting = false;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('ส่งคำจองไม่สำเร็จ')));
    }
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
                _buildCalendar(),
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

  /// Full month-grid calendar (Flutter's built-in [CalendarDatePicker], no
  /// extra dependency needed) so customers can browse forward/back by month
  /// instead of only the next 14 days. `key` forces a fresh widget whenever
  /// the restored/selected date changes externally (e.g. going back to step
  /// 2 and returning) so the calendar's own internal "displayed month"
  /// state doesn't go stale.
  Widget _buildCalendar() {
    return CalendarDatePicker(
      key: ValueKey(_selectedDate),
      initialDate: _selectedDate ?? _today,
      firstDate: _today,
      lastDate: _lastSelectableDate,
      onDateChanged: _selectDate,
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
    final summaryText = _hasSelection
        ? 'วันเวลาที่เลือก: '
              '${DateFormat('EEEE d MMMM', 'th').format(_selectedDate!)} '
              'เวลา $_selectedSlot'
        : 'กรุณาเลือกวันและเวลา';
    final confirmLabel = _mode == BookingMode.repair
        ? 'ส่งคำจอง'
        : 'ยืนยันเวลา';
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
            if (_submitError != null) ...[
              const SizedBox(height: 4),
              Text(
                _submitError!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _canConfirm ? _confirm : null,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(confirmLabel),
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
