import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../models/booking.dart';
import '../../models/booking_draft.dart';
import '../../theme/app_theme.dart';
import '../../widgets/payment_slip_card.dart';

final NumberFormat _priceFormat = NumberFormat('#,###');

const Map<String, String> _installAreaLabels = {
  'FULL': 'รอบคัน',
  'FRONT_BACK': 'กระจกหน้า-หลัง',
  'FRONT': 'กระจกหน้า',
  'BACK': 'กระจกหลัง',
};

/// Step 5/5 ของ booking flow (Figma page 13): หน้าหลังยิงจองจริง — แสดงหลัง
/// ทั้งโหมดฟิล์ม/ล้างรถและโหมดซ่อมกระจก (ส่งคำจองแล้ว รอใบเสนอราคา).
///
/// เงินสด/ซ่อมกระจก: การจองเสร็จสมบูรณ์ทันทีที่มาถึงหน้านี้ ("...เสร็จสิ้น").
/// QR ([BookingDraft.paymentChannel] == 'QR'): การจองถูกสร้างแล้วก็จริง แต่
/// "เสร็จสิ้น" ยังไม่ถูกต้องจนกว่าจะตรวจสอบสลิปผ่าน — หน้านี้เลยโชว์การ์ด
/// QR+แนบสลิป ([PaymentSlipCard], widget เดียวกับหน้าติดตามสถานะ) และ
/// เปลี่ยนหัวข้อ/ไอคอนตาม [Booking.paymentStatus] แทนที่จะขึ้น "เสร็จสิ้น"
/// ตายตัวทันที.
class Step5Success extends StatefulWidget {
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

  @override
  State<Step5Success> createState() => _Step5SuccessState();
}

class _Step5SuccessState extends State<Step5Success> {
  late Booking _booking = widget.booking;

  BookingDraft get _draft => widget.draft;

  bool get _isRepair => bookingModeFor(_draft.service) == BookingMode.repair;

  bool get _showPaymentSlipCard =>
      !_isRepair && _draft.paymentChannel == 'QR' && _booking.paidAmount > 0;

  /// The "done" message once payment is actually confirmed — distinct
  /// wording for a 30% deposit vs paying in full, matching what step4 shows.
  String get _paidDoneTitleText => _draft.paymentType == 'FULL'
      ? 'ชำระเงินเต็มจำนวนเสร็จสิ้น'
      : 'ชำระเงินมัดจำเสร็จสิ้น';

  /// Cash (or repair, which never reaches this screen with money owed) is
  /// done the moment the booking is created. QR isn't "เสร็จสิ้น" until the
  /// slip is actually verified — showing that message before verification
  /// would be misleading, so this reflects [Booking.paymentStatus] instead.
  String get _titleText {
    if (_isRepair) return 'ส่งคำจองเรียบร้อย รอใบเสนอราคาจากร้าน';
    if (!_showPaymentSlipCard) return _paidDoneTitleText;
    switch (_booking.paymentStatus) {
      case 'VERIFIED':
        return _paidDoneTitleText;
      case 'PENDING_REVIEW':
        return 'ส่งสลิปแล้ว กำลังรอตรวจสอบการชำระเงิน';
      case 'REJECTED':
        return 'การชำระเงินมีปัญหา กรุณาแนบสลิปใหม่';
      case 'AWAITING_PAYMENT':
      default:
        return 'สแกน QR แล้วแนบสลิปเพื่อยืนยันการชำระเงิน';
    }
  }

  String get _selectionSummaryText {
    final productName = _draft.product?.name;
    if (productName == null) return 'รอใบเสนอราคาหลังส่งคำจอง';
    final area = _draft.installArea;
    if (area != null) {
      final areaLabel = _installAreaLabels[area] ?? area;
      return '$productName บริเวณที่ติดตั้ง: $areaLabel';
    }
    return productName;
  }

  String get _installDateText {
    final date = _draft.date;
    if (date == null) return '-';
    // The "th" locale's symbol data is bundled synchronously, so this is
    // safe to call directly from build() without awaiting anything.
    initializeDateFormatting('th');
    final dateLabel = DateFormat('EEEE d MMMM', 'th').format(date);
    final slot = _draft.timeSlot ?? '-';
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
                  'เลขที่คำสั่งจอง #${_booking.orderCode}',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                _buildSummaryCard(),
                const SizedBox(height: 16),
                _buildAmountCard(),
                if (_showPaymentSlipCard) ...[
                  const SizedBox(height: 16),
                  PaymentSlipCard(
                    booking: _booking,
                    onBookingUpdated: (updated) =>
                        setState(() => _booking = updated),
                  ),
                ],
              ],
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildSuccessIcon() {
    var icon = Icons.check;
    var background = AppColors.primary;
    if (!_isRepair && _showPaymentSlipCard) {
      switch (_booking.paymentStatus) {
        case 'PENDING_REVIEW':
          icon = Icons.hourglass_top;
          background = Colors.black45;
        case 'REJECTED':
          icon = Icons.error_outline;
          background = Colors.red;
        case 'AWAITING_PAYMENT':
          icon = Icons.qr_code;
          background = Colors.black45;
      }
    }
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 48),
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

    final total = bookingTotalAmount(_draft);
    final paid = _booking.paidAmount;
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
          onPressed: widget.onDone,
          child: const Text('ไปยังหน้าติดตามสถานะ'),
        ),
      ),
    );
  }
}
