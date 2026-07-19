import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../models/booking.dart';
import '../../models/booking_draft.dart';
import '../../theme/app_theme.dart';

final NumberFormat _priceFormat = NumberFormat('#,###');

const Map<String, String> _installAreaLabels = {
  'FULL': 'รอบคัน',
  'FRONT_BACK': 'กระจกหน้า-หลัง',
  'FRONT': 'กระจกหน้า',
  'BACK': 'กระจกหลัง',
};

/// Step 5/5 ของ booking flow (Figma page 13): หน้าสำเร็จหลังยิงจองจริง —
/// แสดงหลังทั้งโหมดฟิล์ม/ล้างรถ (มัดจำ/ชำระเต็มจำนวนแล้ว) และโหมดซ่อมกระจก
/// (ส่งคำจองแล้ว รอใบเสนอราคา).
class Step5Success extends StatelessWidget {
  const Step5Success({
    super.key,
    required this.draft,
    required this.booking,
    required this.onDone,
  });

  final BookingDraft draft;
  final Booking booking;

  /// "ไปยังหน้าติดตามสถานะ" — ปิด flow แล้วสลับไปแท็บการจอง.
  final VoidCallback onDone;

  bool get _isRepair => bookingModeFor(draft.service) == BookingMode.repair;

  String get _titleText => _isRepair
      ? 'ส่งคำจองเรียบร้อย รอใบเสนอราคาจากร้าน'
      : 'ชำระเงินมัดจำเสร็จสิ้น';

  String get _selectionSummaryText {
    final productName = draft.product?.name;
    if (productName == null) return 'รอใบเสนอราคาหลังส่งคำจอง';
    final area = draft.installArea;
    if (area != null) {
      final areaLabel = _installAreaLabels[area] ?? area;
      return '$productName บริเวณที่ติดตั้ง: $areaLabel';
    }
    return productName;
  }

  String get _installDateText {
    final date = draft.date;
    if (date == null) return '-';
    // The "th" locale's symbol data is bundled synchronously, so this is
    // safe to call directly from build() without awaiting anything.
    initializeDateFormatting('th');
    final dateLabel = DateFormat('EEEE d MMMM', 'th').format(date);
    final slot = draft.timeSlot ?? '-';
    return '$dateLabel เวลา $slot';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                _buildSuccessIcon(),
                const SizedBox(height: 20),
                Text(
                  _titleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'เลขที่คำสั่งจอง #${booking.orderCode}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                _buildSummaryCard(),
                const SizedBox(height: 16),
                _buildAmountCard(),
              ],
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 48),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectionSummaryText,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'วันที่ติดตั้ง: $_installDateText',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard() {
    if (_isRepair) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'รอใบเสนอราคา',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }

    final total = bookingTotalAmount(draft);
    final paid = booking.paidAmount;
    final remaining = total - paid;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ยอดรวมทั้งหมด ${_priceFormat.format(total)} บาท'),
          const SizedBox(height: 4),
          Text('มัดจำที่ชำระแล้ว -${_priceFormat.format(paid)} บาท'),
          const SizedBox(height: 4),
          Text(
            'ยอดเงินคงเหลือชำระวันติดตั้ง '
            '${_priceFormat.format(remaining)} บาท',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: onDone,
          child: const Text('ไปยังหน้าติดตามสถานะ'),
        ),
      ),
    );
  }
}
