import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/technician_booking_service.dart';
import '../../models/booking.dart';
import '../../state/technician_queue_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/thai_date.dart';
import '../../widgets/job_card.dart';
import '../../widgets/tech_header.dart';

/// Job detail + status stepper. There is no `GET /api/technician/bookings/{id}`
/// endpoint on the backend — only the list endpoint and the status-update
/// endpoint exist — so this screen reads the booking out of the shared
/// [TechnicianQueueController] cache (already populated by whichever list
/// screen navigated here) rather than fetching it individually.
class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({super.key, required this.bookingId});

  final int bookingId;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _controller = TechnicianQueueController.instance;
  bool _updating = false;

  Booking? get _booking {
    for (final b in _controller.bookings) {
      if (b.id == widget.bookingId) return b;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    if (_booking == null && !_controller.loading) {
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

  Future<void> _advance(Booking booking, TechnicianStatusUpdate next) async {
    setState(() => _updating = true);
    try {
      final updated = await TechnicianBookingService.instance.updateStatus(booking.id, next);
      _controller.replace(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            next == TechnicianStatusUpdate.inProgress ? 'อัปเดตสถานะ: กำลังดำเนินการ' : 'อัปเดตสถานะ: งานเสร็จสิ้น',
          ),
        ));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('อัปเดตสถานะไม่สำเร็จ')));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  void _openPhoto(String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: InteractiveViewer(child: Center(child: Image.network(url))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: TechHeader.withBack(title: 'รายละเอียดงาน', onBack: () => Navigator.of(context).pop()),
      body: booking == null
          ? (_controller.loading
              ? const Center(child: CircularProgressIndicator())
              : const Center(child: Text('ไม่พบข้อมูลงานนี้', style: TextStyle(color: AppColors.ink500))))
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _CustomerInfoCard(booking: booking),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _InfoField(
                              icon: Icons.checkroom_outlined,
                              label: 'บริการ',
                              value: booking.serviceName,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoField(
                              icon: Icons.inventory_2_outlined,
                              label: 'สินค้า',
                              value: booking.productName ?? '-',
                            ),
                          ),
                        ],
                      ),
                      if (booking.installArea != null) ...[
                        const SizedBox(height: 10),
                        _InfoField(
                          icon: Icons.crop_free,
                          label: 'พื้นที่ติดตั้ง',
                          value: installAreaLabel(booking.installArea)!,
                        ),
                      ],
                      if (booking.displayAmount != null) ...[
                        const SizedBox(height: 10),
                        _InfoField(
                          icon: Icons.payments_outlined,
                          label: 'มูลค่างาน',
                          value: formatBaht(booking.displayAmount!),
                        ),
                      ],
                      if (booking.notes != null && booking.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _InfoField(icon: Icons.notes, label: 'หมายเหตุ', value: booking.notes!),
                      ],
                      const SizedBox(height: 20),
                      const Text('รูปสภาพรถจากลูกค้า', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink900)),
                      const SizedBox(height: 10),
                      if (booking.imageUrl == null)
                        Container(
                          height: 120,
                          decoration: BoxDecoration(color: const Color(0xFFE4E0E0), borderRadius: BorderRadius.circular(12)),
                          child: const Center(child: Icon(Icons.photo_outlined, size: 28, color: AppColors.ink500)),
                        )
                      else
                        GestureDetector(
                          onTap: () => _openPhoto(booking.imageUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 16 / 10,
                              child: Image.network(
                                booking.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: const Color(0xFFE4E0E0),
                                  child: const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.ink500)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.storefront_outlined, size: 13, color: AppColors.ink500),
                          const SizedBox(width: 4),
                          const Text('บริการทุกรายการทำที่ร้านเท่านั้น', style: TextStyle(fontSize: 11.5, color: AppColors.ink500)),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text('อัปเดตสถานะงาน', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink900)),
                      const SizedBox(height: 10),
                      _StatusStepper(
                        booking: booking,
                        updating: _updating,
                        onStart: () => _advance(booking, TechnicianStatusUpdate.inProgress),
                        onComplete: () => _advance(booking, TechnicianStatusUpdate.completed),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _CustomerInfoCard extends StatelessWidget {
  const _CustomerInfoCard({required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary, width: 1.3),
      ),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 64),
                      child: Text(
                        booking.userFullName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink900),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (booking.vehicleLicensePlate != null || booking.vehicleBrandModel != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (booking.vehicleLicensePlate != null) ...[
                            const Icon(Icons.vpn_key, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(booking.vehicleLicensePlate!, style: const TextStyle(fontSize: 13, color: AppColors.ink700)),
                            const SizedBox(width: 12),
                          ],
                          if (booking.vehicleBrandModel != null) ...[
                            const Icon(Icons.directions_car, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                booking.vehicleBrandModel!,
                                style: const TextStyle(fontSize: 13, color: AppColors.ink700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${thaiShortDate(booking.bookingDate)}  ·  เวลา ${booking.timeSlot}',
                            style: const TextStyle(fontSize: 13, color: AppColors.ink700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(top: 0, right: 0, child: StatusBadge(status: booking.status)),
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.ink500),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.ink500)),
            ],
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink900)),
        ],
      ),
    );
  }
}

class _StatusStepper extends StatelessWidget {
  const _StatusStepper({
    required this.booking,
    required this.updating,
    required this.onStart,
    required this.onComplete,
  });

  final Booking booking;
  final bool updating;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    if (booking.status == 'CANCELLED') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.ink100, borderRadius: BorderRadius.circular(12)),
        child: const Row(
          children: [
            Icon(Icons.block, size: 18, color: AppColors.ink500),
            SizedBox(width: 10),
            Expanded(child: Text('งานนี้ถูกยกเลิกแล้ว', style: TextStyle(color: AppColors.ink700, fontSize: 13))),
          ],
        ),
      );
    }

    // CONFIRMED -> 1, IN_PROGRESS -> 2, COMPLETED -> 3. PENDING (shouldn't
    // normally reach a technician, but handled defensively) reads as step 1.
    final step = booking.status == 'COMPLETED' ? 3 : (booking.status == 'IN_PROGRESS' ? 2 : 1);

    return Column(
      children: [
        _Step(
          label: 'รับงานแล้ว',
          state: step > 1 ? _StepState.done : (step == 1 ? _StepState.current : _StepState.todo),
          showLine: true,
        ),
        _Step(
          label: 'กำลังดำเนินการ',
          state: step > 2 ? _StepState.done : (step == 2 ? _StepState.current : _StepState.todo),
          showLine: true,
          action: step == 1
              ? _StepAction(label: 'เริ่มดำเนินการ', onTap: updating ? null : onStart, loading: updating)
              : (step == 2 ? _StepAction(label: 'งานเสร็จสิ้น', onTap: updating ? null : onComplete, loading: updating) : null),
        ),
        _Step(
          label: 'ดำเนินการเสร็จสิ้น',
          state: step >= 3 ? _StepState.done : _StepState.todo,
          showLine: false,
        ),
      ],
    );
  }
}

enum _StepState { done, current, todo }

class _StepAction extends StatelessWidget {
  const _StepAction({required this.label, required this.onTap, required this.loading});
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 36,
        child: FilledButton.icon(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          icon: loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.flag, size: 15),
          label: Text(label),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.state, required this.showLine, this.action});

  final String label;
  final _StepState state;
  final bool showLine;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (state) {
      _StepState.done => AppColors.primary,
      _StepState.current => Colors.white,
      _StepState.todo => Colors.white,
    };
    final dotBorder = state == _StepState.current ? AppColors.primary : (state == _StepState.todo ? AppColors.ink300 : AppColors.primary);
    final labelColor = state == _StepState.todo ? AppColors.ink500 : AppColors.ink900;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle, border: Border.all(color: dotBorder, width: 2)),
                child: state == _StepState.done
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : (state == _StepState.current ? const Icon(Icons.circle, size: 8, color: AppColors.primary) : null),
              ),
              if (showLine)
                Expanded(
                  child: Container(width: 2, color: state == _StepState.done ? AppColors.primary : AppColors.ink300),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: labelColor)),
                  ?action,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
