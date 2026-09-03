import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/api_client.dart';
import '../api/booking_service.dart';
import '../api/payment_service.dart';
import '../models/booking.dart';
import '../theme/app_theme.dart';
import '../utils/promptpay_qr.dart';

final NumberFormat _priceFormat = NumberFormat('#,###');

/// QR-payment + slip-review card, shared by [BookingDetailScreen] (tracking
/// an existing booking) and [Step5Success] (right after creating one with
/// the "QR" payment channel) — same PromptPay QR + upload/status UI either
/// way, just driven by whichever [Booking] the caller currently has:
/// - `AWAITING_PAYMENT`: QR code (or "ยังไม่ได้ตั้งค่า" if the shop hasn't
///   set a PromptPay ID) + "แนบสลิปการโอนเงิน" button. Picking an image
///   shows a preview first — nothing is uploaded until the customer taps
///   "ยืนยันการชำระเงิน" to submit it for verification.
/// - `PENDING_REVIEW`: submitted, but the automatic (Gemini) check couldn't
///   confidently confirm the amount — "รอร้านตรวจสอบ", nothing more to do
///   but wait for a human admin.
/// - `VERIFIED`: a confirmation banner (set immediately when the automatic
///   check matches, or later by an admin).
/// - `REJECTED`: the admin's note (if any) + a button to try again.
class PaymentSlipCard extends StatefulWidget {
  const PaymentSlipCard({
    super.key,
    required this.booking,
    required this.onBookingUpdated,
  });

  final Booking booking;

  /// Called with the refreshed [Booking] after a slip is successfully
  /// submitted, so the caller can keep its own copy (and thus this widget's
  /// `booking` input) in sync.
  final ValueChanged<Booking> onBookingUpdated;

  @override
  State<PaymentSlipCard> createState() => _PaymentSlipCardState();
}

class _PaymentSlipCardState extends State<PaymentSlipCard> {
  bool _loadingPromptPayId = true;
  String? _promptPayId;

  XFile? _pickedFile;
  Uint8List? _pickedImageBytes;
  bool _submittingSlip = false;
  String? _slipUploadError;

  @override
  void initState() {
    super.initState();
    _loadPromptPayId();
  }

  Future<void> _loadPromptPayId() async {
    try {
      final id = await PaymentService.instance.fetchPromptPayId();
      if (!mounted) return;
      setState(() {
        _promptPayId = id;
        _loadingPromptPayId = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Best-effort: a failed config fetch just means the QR card shows
      // "not configured" rather than blocking the whole screen.
      setState(() => _loadingPromptPayId = false);
    }
  }

  /// Just picks an image and shows it as a preview — nothing is uploaded
  /// yet. The customer confirms with [_confirmAndSubmitSlip] once they've
  /// checked it's the right slip.
  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedFile = file;
      _pickedImageBytes = bytes;
      _slipUploadError = null;
    });
  }

  Future<void> _confirmAndSubmitSlip() async {
    final file = _pickedFile;
    if (file == null || _submittingSlip) return;
    setState(() {
      _submittingSlip = true;
      _slipUploadError = null;
    });
    try {
      final imageUrl = await ApiClient.instance.uploadImage(file);
      final updated = await BookingService.instance.submitPaymentSlip(
        widget.booking.id,
        imageUrl,
        widget.booking.paidAmount,
      );
      if (!mounted) return;
      setState(() {
        _submittingSlip = false;
        _pickedFile = null;
        _pickedImageBytes = null;
      });
      widget.onBookingUpdated(updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _slipUploadError = e.message;
        _submittingSlip = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _slipUploadError = 'แนบสลิปไม่สำเร็จ';
        _submittingSlip = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ชำระเงินผ่าน QR พร้อมเพย์',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'ยอดที่ต้องชำระ ${_priceFormat.format(widget.booking.paidAmount)} บาท',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildBody(),
        ],
      ),
    );
  }

  List<Widget> _buildBody() {
    switch (widget.booking.paymentStatus) {
      case 'PENDING_REVIEW':
        return const [
          Row(
            children: [
              Icon(Icons.hourglass_top, color: AppColors.primaryDark),
              SizedBox(width: 8),
              Expanded(child: Text('ส่งสลิปแล้ว กำลังรอร้านตรวจสอบ')),
            ],
          ),
        ];
      case 'VERIFIED':
        return const [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Expanded(child: Text('ยืนยันการชำระเงินแล้ว')),
            ],
          ),
        ];
      case 'REJECTED':
        return [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.booking.slipReviewNote != null &&
                          widget.booking.slipReviewNote!.isNotEmpty
                      ? 'สลิปมีปัญหา: ${widget.booking.slipReviewNote}'
                      : 'สลิปมีปัญหา กรุณาลองใหม่อีกครั้ง',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildQrAndUploadSection(buttonLabel: 'ส่งสลิปใหม่'),
        ];
      case 'AWAITING_PAYMENT':
      default:
        return _buildQrAndUploadSection(buttonLabel: 'แนบสลิปการโอนเงิน');
    }
  }

  List<Widget> _buildQrAndUploadSection({required String buttonLabel}) {
    return [
      _buildQrCode(),
      const SizedBox(height: 12),
      if (_pickedImageBytes != null)
        ..._buildPreviewAndConfirm()
      else
        _buildPickButton(buttonLabel),
      if (_slipUploadError != null) ...[
        const SizedBox(height: 8),
        Text(
          _slipUploadError!,
          style: const TextStyle(color: Colors.red, fontSize: 12),
        ),
      ],
    ];
  }

  Widget _buildPickButton(String buttonLabel) {
    return OutlinedButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.upload_outlined),
      label: Text(buttonLabel),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        foregroundColor: AppColors.primaryDark,
        side: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  List<Widget> _buildPreviewAndConfirm() {
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _pickedImageBytes!,
          height: 160,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _submittingSlip ? null : _pickImage,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: AppColors.primaryDark,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('เปลี่ยนรูป'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: _submittingSlip ? null : _confirmAndSubmitSlip,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(44),
              ),
              child: _submittingSlip
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('ยืนยันการชำระเงิน'),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildQrCode() {
    if (_loadingPromptPayId) {
      return const Center(child: CircularProgressIndicator());
    }
    final promptPayId = _promptPayId;
    if (promptPayId == null) {
      return const Text(
        'ร้านค้ายังไม่ได้ตั้งค่า QR รับชำระเงิน กรุณาชำระเงินสด/โอนที่ร้าน',
        style: TextStyle(color: Colors.black54),
      );
    }
    final payload = buildPromptPayPayload(
      promptPayId: promptPayId,
      amount: widget.booking.paidAmount,
    );
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: QrImageView(data: payload, size: 200),
      ),
    );
  }
}
