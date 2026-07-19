import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/booking_service.dart';
import '../../models/booking.dart';
import '../../theme/app_theme.dart';
import 'booking_detail_screen.dart';

/// Per-status chip colors (Figma spec): PENDING orange, CONFIRMED blue,
/// IN_PROGRESS red (brand primary), COMPLETED green, CANCELLED grey.
const Map<String, Color> _statusColors = {
  'PENDING': Colors.orange,
  'CONFIRMED': Colors.blue,
  'IN_PROGRESS': AppColors.primary,
  'COMPLETED': Colors.green,
  'CANCELLED': Colors.grey,
};

/// แท็บ "การจอง" (Task 7): รายการการจองทั้งหมดของผู้ใช้ เรียงใหม่→เก่า (ตามที่
/// backend ส่งมา — ไม่มีการ sort เพิ่มฝั่งแอป), แตะการ์ดเพื่อเปิดหน้ารายละเอียด
/// ([BookingDetailScreen]), ดึงลงเพื่อรีเฟรช, และ empty state เมื่อยังไม่มี
/// การจองเลย.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  List<Booking>? _bookings;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final bookings = await BookingService.instance.fetchMine();
      if (!mounted) return;
      setState(() => _bookings = bookings);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดข้อมูลไม่สำเร็จ');
    }
  }

  Future<void> _openDetail(Booking booking) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingDetailScreen(bookingId: booking.id),
      ),
    );
    // The detail screen may have changed the booking's status (e.g. after
    // accepting a quote), so refresh the list once the user comes back.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'การจอง',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final bookings = _bookings;
    if (bookings == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && bookings == null) {
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
    if (bookings!.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 96),
            Center(
              child: Text(
                'ยังไม่มีการจอง',
                style: TextStyle(color: Colors.black54, fontSize: 15),
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: bookings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return _BookingCard(
            booking: booking,
            onTap: () => _openDetail(booking),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  String get _titleText {
    final product = booking.productName;
    return product != null
        ? '${booking.serviceName} • $product'
        : booking.serviceName;
  }

  @override
  Widget build(BuildContext context) {
    // The "th" locale's symbol data is bundled synchronously, so this is
    // safe to call directly from build() without awaiting anything.
    initializeDateFormatting('th');
    final dateLabel = DateFormat(
      'd MMMM yyyy',
      'th',
    ).format(booking.bookingDate);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _titleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: booking.status, label: booking.statusLabel),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'เลขที่คำสั่งจอง #${booking.orderCode}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              '$dateLabel เวลา ${booking.timeSlot}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _statusColors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
