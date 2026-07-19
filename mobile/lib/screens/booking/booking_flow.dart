import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/catalog_service.dart';
import '../../models/product.dart';
import '../../models/service_item.dart';
import '../../models/vehicle.dart';
import '../../theme/app_theme.dart';
import 'step1_vehicle.dart';
import 'step2_product.dart';
import 'step3_schedule.dart';

/// Mutable holder for everything collected across the 5-step booking flow.
/// Passed down to every step widget so each one can read/write its slice
/// without the flow screen needing per-field callbacks.
class BookingDraft {
  BookingDraft({this.service});

  ServiceItem? service;
  Vehicle? vehicle;
  Product? product;
  String? installArea;
  String? imageUrl;
  double? budget;
  DateTime? date;
  String? timeSlot;
  String paymentType = 'DEPOSIT';
}

const List<String> _stepTitles = [
  'เลือกรถ',
  'เลือกสินค้า',
  'นัดเวลา',
  'ขั้นตอน 4',
  'ขั้นตอน 5',
];

/// Full-screen booking flow: header (back button, "BKK CAR GLASS & FLIM",
/// step name, "N / 5" badge, 5-segment progress bar) over a 5-step body.
///
/// When [initialService] is null (generic entry via "จองบริการ", the center
/// FAB, or the banner), a simple service-picker is shown first ("step 0")
/// before step 1.
class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({super.key, this.initialService});

  final ServiceItem? initialService;

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  late final BookingDraft _draft = BookingDraft(service: widget.initialService);
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

  void _goNext() {
    if (_step < 5) {
      setState(() => _step++);
    }
  }

  void _handleBack() {
    if (_step > 1) {
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
              child: _pickingService ? _buildServicePicker() : _buildStep(),
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
      color: AppColors.splashBg,
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Text(
                'BKK CAR GLASS & FLIM',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stepLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (stepIndex != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$stepIndex / 5',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (stepIndex != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(5, (i) {
                  final filled = i < stepIndex!;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: filled ? AppColors.primary : Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
