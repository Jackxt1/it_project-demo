import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/catalog_service.dart';
import '../../models/booking.dart';
import '../../models/booking_draft.dart';
import '../../models/product.dart';
import '../../models/service_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bounce_on_change.dart';
import 'step1_vehicle.dart';
import 'step2_product.dart';
import 'step3_schedule.dart';
import 'step4_payment.dart';
import 'step5_success.dart';

const List<String> _stepTitles = [
  'เลือกรถ',
  'เลือกสินค้า',
  'นัดเวลา',
  'ชำระเงิน',
  'สำเร็จ',
];

/// Full-screen booking flow: header (back button, "BKK CAR GLASS & FLIM",
/// step name, "N / 5" badge, 5-segment progress bar) over a 5-step body.
///
/// When [initialService] is null (generic entry via "จองบริการ", the center
/// FAB, or the banner), a simple service-picker is shown first ("step 0")
/// before step 1.
///
/// [initialProduct] preselects step 2's product/package (used by the Task 9
/// chatbot's "จองตัวนี้" button after a recommendation) — ignored when
/// [initialService] is null, since there's no service yet for it to belong
/// to.
class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({
    super.key,
    this.initialService,
    this.initialProduct,
    this.initialInstallArea,
  });

  final ServiceItem? initialService;
  final Product? initialProduct;

  /// Preselects step 2's film install area — set by the chatbot's
  /// "ต้องการติดฟิล์มบริเวณไหนครับ" step so a customer arriving via "จองตัวนี้"
  /// isn't asked the same question twice. Ignored when [initialService] is
  /// null, same as [initialProduct].
  final String? initialInstallArea;

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  late final BookingDraft _draft = BookingDraft(service: widget.initialService)
    ..product = widget.initialService != null ? widget.initialProduct : null
    ..installArea =
        widget.initialService != null ? widget.initialInstallArea : null;
  late bool _pickingService = widget.initialService == null;
  int _step = 1;

  List<ServiceItem> _services = [];
  bool _loadingServices = false;
  String? _servicesError;

  @override
  void initState() {
    super.initState();
    if (_pickingService) {
      _loadServices();
    }
  }

  Future<void> _loadServices() async {
    setState(() {
      _loadingServices = true;
      _servicesError = null;
    });
    try {
      final services = await CatalogService.instance.fetchServices();
      if (!mounted) return;
      setState(() {
        _services = services;
        _loadingServices = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _servicesError = e.message;
        _loadingServices = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _servicesError = 'โหลดบริการไม่สำเร็จ';
        _loadingServices = false;
      });
    }
  }

  void _selectService(ServiceItem service) {
    setState(() {
      _draft.service = service;
      _pickingService = false;
    });
  }

  Booking? _createdBooking;

  void _goNext() {
    if (_step < 5) {
      setState(() => _step++);
    }
  }

  /// Called by step3 (repair drafts, which skip step 4 entirely) and step4
  /// (film/wash drafts, after payment) once `createBooking` succeeds.
  void _handleBookingCreated(Booking booking) {
    setState(() {
      _createdBooking = booking;
      _step = 5;
    });
  }

  /// "ไปยังหน้าติดตามสถานะ" on step 5 — closes the flow and tells
  /// [MainShell] to switch to the bookings tab.
  void _handleDone() {
    Navigator.of(context).pop('bookings');
  }

  void _handleBack() {
    if (_step == 5) {
      // Going back from the success screen makes no sense (the booking is
      // already created) — treat it the same as "ไปยังหน้าติดตามสถานะ".
      _handleDone();
    } else if (_step > 1) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Next-button label on step 1, chosen from the selected service's name.
  String get _step1NextLabel {
    final name = _draft.service?.name ?? '';
    if (name.contains('ฟิล์ม')) return 'ถัดไป : เลือกฟิล์ม';
    if (name.contains('ล้าง')) return 'ถัดไป : เลือกแพ็กเกจ';
    return 'ถัดไป : ถ่ายรูปความเสียหาย';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _BookingHeader(
              stepLabel: _pickingService
                  ? 'เลือกบริการ'
                  : _stepTitles[_step - 1],
              stepIndex: _pickingService ? null : _step,
              onBack: _pickingService
                  ? () => Navigator.of(context).pop()
                  : _handleBack,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.06, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                  );
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_pickingService ? 'picker' : _step),
                  child: _pickingService
                      ? _buildServicePicker()
                      : _buildStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicePicker() {
    if (_loadingServices) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_servicesError != null) {
      return Center(child: Text(_servicesError!));
    }
    if (_services.isEmpty) {
      return const Center(child: Text('ไม่พบบริการ'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _services.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final service = _services[index];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.surfaceLight,
              child: Icon(Icons.build_outlined, color: AppColors.primary),
            ),
            title: Text(service.name),
            onTap: () => _selectService(service),
          ),
        );
      },
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return Step1Vehicle(
          draft: _draft,
          nextLabel: _step1NextLabel,
          onNext: _goNext,
        );
      case 2:
        return Step2Product(
          draft: _draft,
          onNext: _goNext,
          onBack: () => setState(() => _step = 1),
        );
      case 3:
        return Step3Schedule(
          draft: _draft,
          onNext: _goNext,
          onBack: () => setState(() => _step = 2),
          onBookingCreated: _handleBookingCreated,
        );
      case 4:
        return Step4Payment(
          draft: _draft,
          onBookingCreated: _handleBookingCreated,
        );
      case 5:
        return Step5Success(
          draft: _draft,
          booking: _createdBooking!,
          onDone: _handleDone,
        );
      default:
        return Center(child: Text('ขั้นตอน $_step'));
    }
  }
}

class _BookingHeader extends StatelessWidget {
  const _BookingHeader({
    required this.stepLabel,
    required this.stepIndex,
    required this.onBack,
  });

  /// Name of the current step (e.g. "เลือกรถ"), or "เลือกบริการ" while
  /// picking a service before step 1.
  final String stepLabel;

  /// 1-5 for the "N / 5" badge and progress bar; null while picking a
  /// service (no badge/progress shown yet).
  final int? stepIndex;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'BKK CAR GLASS & FLIM',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (stepIndex != null)
                BounceOnChange(
                  trigger: stepIndex!,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$stepIndex / 5',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            stepLabel,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (stepIndex != null) ...[
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (i) {
                final filled = i < stepIndex!;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutBack,
                    height: filled ? 5 : 4,
                    margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: filled ? AppColors.primary : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
