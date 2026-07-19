import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/booking_service.dart';
import '../../models/booking.dart';
import '../../theme/app_theme.dart';
import 'booking_flow.dart';

final NumberFormat _priceFormat = NumberFormat('#,###');

const Map<String, String> _installAreaLabels = {
  'FULL': 'รอบคัน',
  'FRONT_BACK': 'กระจกหน้า-หลัง',
  'FRONT': 'กระจกหน้า',
  'BACK': 'กระจกหลัง',
};

/// Step 4/5 ของ booking flow (Figma page 12): มัดจำ/ชำระเงิน mock — เฉพาะ
/// โหมดฟิล์ม/ล้างรถ (ซ่อมกระจกข้ามหน้านี้ทั้งหน้า, ดู [Step3Schedule]).
///
/// - การ์ดสรุป (ของที่เลือก + "วันที่ติดตั้ง: {วันเวลาไทย}")
/// - "01 รายการค่าใช้จ่าย": ราคาสินค้า/แพ็กเกจ + "ค่าช่างติดตั้ง" (เมื่อ
///   `service.basePrice > 0`) + "ยอดรวมทั้งหมด"
/// - "02 เลือกวิธีชำระเงิน": มัดจำ 30% (default) / ชำระเต็มจำนวน
/// - "03 ช่องทางชำระเงิน": ข้อความชำระเงินสด/โอนที่ร้าน (ระบบออนไลน์เร็วๆ นี้)
/// - ปุ่ม "ยืนยันการชำระเงิน" → `BookingService.createBooking` พร้อม
///   `paymentType`/`paidAmount` ตามที่เลือก
class Step4Payment extends StatefulWidget {
  const Step4Payment({
    super.key,
    required this.draft,
    required this.onBookingCreated,
  });

  final BookingDraft draft;

  /// Invoked with the created booking once `createBooking` succeeds, so the
  /// flow can move on to step 5.
  final void Function(Booking booking) onBookingCreated;

  @override
  State<Step4Payment> createState() => _Step4PaymentState();
}

class _Step4PaymentState extends State<Step4Payment> {
  String _paymentType = 'DEPOSIT';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // See Step3Schedule's initState: the "th" locale's symbol data is
    // bundled synchronously, so this is safe to call without awaiting.
    initializeDateFormatting('th');
    _paymentType = widget.draft.paymentType;
  }

  double get _productPrice => widget.draft.product?.price ?? 0;

  double get _installFee {
    final basePrice = widget.draft.service?.basePrice ?? 0;
    return basePrice > 0 ? basePrice : 0;
  }

  double get _total => bookingTotalAmount(widget.draft);

  double get _depositAmount => _roundTo2(_total * 0.3);

  double get _selectedAmount =>
      _paymentType == 'DEPOSIT' ? _depositAmount : _total;

  double _roundTo2(double value) => (value * 100).round() / 100;

  String get _installDateText {
    final date = widget.draft.date;
    if (date == null) return '-';
    final dateLabel = DateFormat('EEEE d MMMM', 'th').format(date);
    final slot = widget.draft.timeSlot ?? '-';
    return '$dateLabel เวลา $slot';
  }

  String get _selectionSummaryText {
    final productName = widget.draft.product?.name ?? '-';
    final area = widget.draft.installArea;
    if (area != null) {
      final areaLabel = _installAreaLabels[area] ?? area;
      return '$productName บริเวณที่ติดตั้ง: $areaLabel';
    }
    return productName;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    widget.draft.paymentType = _paymentType;
    widget.draft.paidAmount = _selectedAmount;
    try {
      final booking = await BookingService.instance.createBooking(
        widget.draft,
      );
      if (!mounted) return;
      widget.onBookingCreated(booking);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('ชำระเงินไม่สำเร็จ')));
    }
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
                  '01 รายการค่าใช้จ่าย',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildCostCard(),
                const SizedBox(height: 24),
                const Text(
                  '02 เลือกวิธีชำระเงิน',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildPaymentOptions(),
                const SizedBox(height: 24),
                const Text(
                  '03 ช่องทางชำระเงิน',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                _buildPaymentChannelCard(),
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

  Widget _buildCostCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDarker,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _costRow('ราคาสินค้า/แพ็กเกจ', _productPrice),
          if (_installFee > 0) ...[
            const SizedBox(height: 8),
            _costRow('ค่าช่างติดตั้ง', _installFee),
          ],
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Text(
            'ยอดรวมทั้งหมด : ${_priceFormat.format(_total)} บาท',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _costRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        Text(
          '${_priceFormat.format(amount)} บาท',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildPaymentOptions() {
    return Column(
      children: [
        _PaymentOptionCard(
          title: 'มัดจำ 30%',
          subtitle: 'ชำระวันนี้ ${_priceFormat.format(_depositAmount)} บาท',
          selected: _paymentType == 'DEPOSIT',
          onTap: () => setState(() => _paymentType = 'DEPOSIT'),
        ),
        const SizedBox(height: 12),
        _PaymentOptionCard(
          title: 'ชำระเต็มจำนวน',
          subtitle: '${_priceFormat.format(_total)} บาท',
          selected: _paymentType == 'FULL',
          onTap: () => setState(() => _paymentType = 'FULL'),
        ),
      ],
    );
  }

  Widget _buildPaymentChannelCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.primaryDark),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'ชำระเงินสด/โอนที่ร้านในวันติดตั้ง (ระบบชำระออนไลน์เร็วๆ นี้)',
              style: TextStyle(fontSize: 13),
            ),
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
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('ยืนยันการชำระเงิน'),
        ),
      ),
    );
  }
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceLight : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
