import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../api/api_client.dart';
import '../../api/booking_service.dart';
import '../../api/payment_service.dart';
import '../../api/review_service.dart';
import '../../models/booking.dart';
import '../../theme/app_theme.dart';
import '../../utils/promptpay_qr.dart';
import '../../widgets/star_rating.dart';
import '../chat/booking_chat_screen.dart';

final NumberFormat _priceFormat = NumberFormat('#,###');

/// หน้ารายละเอียด/ติดตามสถานะการจอง (Task 7, Figma page 20 ปรับให้ตรง
/// backend): การ์ดแดง gradient แสดงสถานะปัจจุบัน, timeline `statusHistory`,
/// การ์ดใบเสนอราคา (เมื่อร้านตั้งราคาแล้วแต่ผู้ใช้ยังไม่เลือกวิธีชำระ),
/// แถวข้อมูลการจอง และปุ่มติดต่อเจ้าหน้าที่.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Booking? _booking;
  String? _error;
  bool _loading = true;

  String _selectedPaymentType = 'DEPOSIT';
  bool _submittingQuote = false;
  bool _reviewSubmitted = false;

  bool _loadingPromptPayId = true;
  String? _promptPayId;
  bool _uploadingSlip = false;
  String? _slipUploadError;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th');
    _load();
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

  Future<void> _pickAndSubmitSlip() async {
    final booking = _booking;
    if (booking == null) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    setState(() {
      _uploadingSlip = true;
      _slipUploadError = null;
    });
    try {
      final imageUrl = await ApiClient.instance.uploadImage(file);
      final updated = await BookingService.instance.submitPaymentSlip(
        booking.id,
        imageUrl,
        booking.paidAmount,
      );
      if (!mounted) return;
      setState(() {
        _booking = updated;
        _uploadingSlip = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _slipUploadError = e.message;
        _uploadingSlip = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _slipUploadError = 'แนบสลิปไม่สำเร็จ';
        _uploadingSlip = false;
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booking = await BookingService.instance.fetchById(
        widget.bookingId,
      );
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ';
        _loading = false;
      });
    }
  }

  Future<void> _acceptQuote() async {
    if (_submittingQuote) return;
    setState(() => _submittingQuote = true);
    try {
      final updated = await BookingService.instance.acceptQuote(
        widget.bookingId,
        _selectedPaymentType,
      );
      if (!mounted) return;
      setState(() {
        _booking = updated;
        _submittingQuote = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submittingQuote = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submittingQuote = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('ยืนยันใบเสนอราคาไม่สำเร็จ')));
    }
  }

  void _contactStaff() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingChatScreen(bookingId: widget.bookingId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ติดตามสถานะ')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
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

    final booking = _booking!;
    // Per Task 7 spec: the quote card only shows while there's a quote the
    // customer hasn't responded to yet (paymentType is set as soon as they
    // accept it, via acceptQuote).
    final showQuoteCard =
        booking.quotePrice != null && booking.paymentType == null;
    // The payment/slip card only makes sense once something is actually
    // owed — repair bookings owe nothing until a quote is accepted, at
    // which point paidAmount becomes > 0 same as film/wash bookings.
    final showPaymentCard = booking.paidAmount > 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(booking),
          const SizedBox(height: 24),
          const Text(
            'สถานะการดำเนินการ',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildTimeline(booking),
          if (showQuoteCard) ...[
            const SizedBox(height: 20),
            _buildQuoteCard(booking),
          ],
          if (showPaymentCard) ...[
            const SizedBox(height: 20),
            _buildPaymentSlipCard(booking),
          ],
          const SizedBox(height: 20),
          _buildInfoCard(booking),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _contactStaff,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('ติดต่อเจ้าหน้าที่'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
          if (booking.status == 'COMPLETED') ...[
            const SizedBox(height: 12),
            _buildReviewAction(booking),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewAction(Booking booking) {
    if (_reviewSubmitted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppColors.primary),
            SizedBox(width: 8),
            Text('ขอบคุณสำหรับรีวิว'),
          ],
        ),
      );
    }
    return FilledButton.icon(
      onPressed: () => _openReviewDialog(booking),
      icon: const Icon(Icons.star_outline),
      label: const Text('ให้คะแนนบริการ'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }

  Future<void> _openReviewDialog(Booking booking) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _ReviewDialog(bookingId: booking.id),
    );
    if (submitted == true && mounted) {
      setState(() => _reviewSubmitted = true);
    }
  }

  Widget _buildStatusCard(Booking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDarker],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            booking.serviceName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (booking.vehicleLicensePlate != null) ...[
            const SizedBox(height: 4),
            Text(
              booking.vehicleLicensePlate!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            booking.statusLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Booking booking) {
    final entries = booking.statusHistory;
    if (entries.isEmpty) {
      return const Text(
        'ยังไม่มีประวัติสถานะ',
        style: TextStyle(color: Colors.black54),
      );
    }
    return Column(
      children: List.generate(entries.length, (index) {
        final entry = entries[index];
        final isLast = index == entries.length - 1;
        return _TimelineTile(entry: entry, isLast: isLast);
      }),
    );
  }

  Widget _buildQuoteCard(Booking booking) {
    final quotePrice = booking.quotePrice!;
    final depositAmount = _roundTo2(quotePrice * 0.3);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ร้านเสนอราคา ${_priceFormat.format(quotePrice)} บาท',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _QuotePaymentOption(
            title: 'มัดจำ 30%',
            subtitle: '${_priceFormat.format(depositAmount)} บาท',
            selected: _selectedPaymentType == 'DEPOSIT',
            onTap: () => setState(() => _selectedPaymentType = 'DEPOSIT'),
          ),
          const SizedBox(height: 8),
          _QuotePaymentOption(
            title: 'เต็มจำนวน',
            subtitle: '${_priceFormat.format(quotePrice)} บาท',
            selected: _selectedPaymentType == 'FULL',
            onTap: () => setState(() => _selectedPaymentType = 'FULL'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: _submittingQuote ? null : _acceptQuote,
            child: _submittingQuote
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('ยืนยันใบเสนอราคา'),
          ),
        ],
      ),
    );
  }

  /// QR-payment + slip-review card, shown whenever `paidAmount > 0`:
  /// - `AWAITING_PAYMENT`: QR code (or "ยังไม่ได้ตั้งค่า" if the shop hasn't
  ///   set a PromptPay ID) + "แนบสลิปการโอนเงิน" button.
  /// - `PENDING_REVIEW`: "รอตรวจสอบสลิป" — nothing more to do but wait.
  /// - `VERIFIED`: a confirmation banner.
  /// - `REJECTED`: the admin's note (if any) + a button to try again.
  Widget _buildPaymentSlipCard(Booking booking) {
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
            'ยอดที่ต้องชำระ ${_priceFormat.format(booking.paidAmount)} บาท',
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 12),
          ..._buildPaymentSlipBody(booking),
        ],
      ),
    );
  }

  List<Widget> _buildPaymentSlipBody(Booking booking) {
    switch (booking.paymentStatus) {
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
                  booking.slipReviewNote != null && booking.slipReviewNote!.isNotEmpty
                      ? 'สลิปมีปัญหา: ${booking.slipReviewNote}'
                      : 'สลิปมีปัญหา กรุณาลองใหม่อีกครั้ง',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildQrAndUploadButton(booking, buttonLabel: 'ส่งสลิปใหม่'),
        ];
      case 'AWAITING_PAYMENT':
      default:
        return _buildQrAndUploadButton(booking, buttonLabel: 'แนบสลิปการโอนเงิน');
    }
  }

  List<Widget> _buildQrAndUploadButton(Booking booking, {required String buttonLabel}) {
    return [
      _buildQrCode(booking),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _uploadingSlip ? null : _pickAndSubmitSlip,
        icon: _uploadingSlip
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.upload_outlined),
        label: Text(buttonLabel),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
      if (_slipUploadError != null) ...[
        const SizedBox(height: 8),
        Text(_slipUploadError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
      ],
    ];
  }

  Widget _buildQrCode(Booking booking) {
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
      amount: booking.paidAmount,
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

  Widget _buildInfoCard(Booking booking) {
    final dateLabel = DateFormat(
      'EEEE d MMMM yyyy',
      'th',
    ).format(booking.bookingDate);
    final vehicleText = booking.vehicleBrandModel != null
        ? '${booking.vehicleBrandModel}'
              '${booking.vehicleLicensePlate != null ? ' (${booking.vehicleLicensePlate})' : ''}'
        : '-';
    final priceText = _budgetOrPriceText(booking);

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
          _infoRow('รถ', vehicleText),
          const SizedBox(height: 10),
          _infoRow('วันนัด', '$dateLabel เวลา ${booking.timeSlot}'),
          const SizedBox(height: 10),
          _infoRow(
            'ยอดชำระแล้ว',
            '${_priceFormat.format(booking.paidAmount)} บาท',
          ),
          const SizedBox(height: 10),
          _infoRow('งบประมาณ/ราคา', priceText),
        ],
      ),
    );
  }

  /// Repair bookings show the admin's quote once set, else the customer's
  /// rough budget estimate. Film/wash bookings have neither — they show
  /// [Booking.totalAmount], the price agreed at booking time (product +
  /// install fee), snapshotted server-side so a later catalog price change
  /// never makes this disagree with what the customer actually paid for.
  String _budgetOrPriceText(Booking booking) {
    final quote = booking.quotePrice;
    if (quote != null) return '${_priceFormat.format(quote)} บาท';
    final total = booking.totalAmount;
    if (total != null) return '${_priceFormat.format(total)} บาท';
    final budget = booking.budget;
    if (budget != null) return '${_priceFormat.format(budget)} บาท';
    return '-';
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  double _roundTo2(double value) => (value * 100).round() / 100;
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.entry, required this.isLast});

  final BookingStatusHistoryEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat(
      'd MMM yyyy, HH:mm',
      'th',
    ).format(entry.changedAt);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade300),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookingStatusLabel(entry.status),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (entry.note != null && entry.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.note!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    [
                      dateLabel,
                      if (entry.changedByName != null) entry.changedByName!,
                    ].join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Star-rating + comment dialog for reviewing a completed booking. Pops with
/// `true` once the review is successfully submitted, `null`/`false` otherwise.
class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.bookingId});

  final int bookingId;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ReviewService.instance.create(
        bookingId: widget.bookingId,
        rating: _rating,
        comment: _commentController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'ส่งรีวิวไม่สำเร็จ';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ให้คะแนนบริการ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarRatingInput(
            value: _rating,
            onChanged: (v) => setState(() => _rating = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'เขียนความคิดเห็น (ไม่บังคับ)',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('ส่งรีวิว'),
        ),
      ],
    );
  }
}

class _QuotePaymentOption extends StatelessWidget {
  const _QuotePaymentOption({
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
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
            const SizedBox(width: 10),
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
                      fontSize: 12,
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
