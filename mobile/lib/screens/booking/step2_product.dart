import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_client.dart';
import '../../api/catalog_service.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import 'booking_flow.dart';

enum _BookingMode { film, wash, repair }

class _InstallAreaOption {
  const _InstallAreaOption(this.label, this.value);
  final String label;
  final String value;
}

const List<_InstallAreaOption> _installAreaOptions = [
  _InstallAreaOption('รอบคัน', 'FULL'),
  _InstallAreaOption('กระจกหน้า-หลัง', 'FRONT_BACK'),
  _InstallAreaOption('กระจกหน้า', 'FRONT'),
  _InstallAreaOption('กระจกหลัง', 'BACK'),
];

/// Step 2/5 ของ booking flow (Figma page 10): เลือกสินค้า/รูป ตามโหมดของ
/// บริการที่เลือกไว้ใน step 1 (พิจารณาจากชื่อบริการ) —
/// - ฟิล์ม (ชื่อมี "ฟิล์ม"): เลือกพื้นที่ติดตั้ง + เลือกฟิล์มจาก
///   `CatalogService.fetchProducts`
/// - ล้างรถ (ชื่อมี "ล้าง"): เลือกแพ็กเกจจาก `fetchProducts` — ไม่มีพื้นที่ติดตั้ง
/// - ซ่อม/เปลี่ยนกระจก (อื่นๆ): ถ่าย/เลือกรูปความเสียหายผ่าน `uploadImage` +
///   กรอกงบประมาณ — ไม่มีการเลือกสินค้า
///
/// ปุ่มล่าง "ไปยังหน้านัดเวลา" enable เมื่อเลือกครบตามโหมด.
class Step2Product extends StatefulWidget {
  const Step2Product({
    super.key,
    required this.draft,
    required this.onNext,
    required this.onBack,
  });

  final BookingDraft draft;
  final VoidCallback onNext;

  /// Invoked by the "เปลี่ยน" button next to the vehicle summary card, to go
  /// back to step 1.
  final VoidCallback onBack;

  @override
  State<Step2Product> createState() => _Step2ProductState();
}

class _Step2ProductState extends State<Step2Product> {
  List<Product> _products = [];
  bool _loadingProducts = false;
  String? _loadError;

  late final TextEditingController _budgetController = TextEditingController(
    text: widget.draft.budget != null
        ? widget.draft.budget!.toStringAsFixed(0)
        : '',
  );

  bool _uploading = false;
  String? _uploadError;

  _BookingMode get _mode {
    final name = widget.draft.service?.name ?? '';
    if (name.contains('ฟิล์ม')) return _BookingMode.film;
    if (name.contains('ล้าง')) return _BookingMode.wash;
    return _BookingMode.repair;
  }

  @override
  void initState() {
    super.initState();
    if (_mode != _BookingMode.repair) {
      _loadProducts();
    }
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loadingProducts = true;
      _loadError = null;
    });
    try {
      final products = await CatalogService.instance.fetchProducts(
        serviceId: widget.draft.service?.id,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _loadingProducts = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingProducts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'โหลดข้อมูลไม่สำเร็จ';
        _loadingProducts = false;
      });
    }
  }

  void _selectArea(String value) {
    setState(() => widget.draft.installArea = value);
  }

  void _selectProduct(Product product) {
    setState(() => widget.draft.product = product);
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source);
    if (file == null || !mounted) return;
    setState(() {
      _uploading = true;
      _uploadError = null;
    });
    try {
      final imageUrl = await ApiClient.instance.uploadImage(file);
      if (!mounted) return;
      setState(() {
        widget.draft.imageUrl = imageUrl;
        _uploading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadError = e.message;
        _uploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _uploadError = 'อัปโหลดรูปไม่สำเร็จ';
        _uploading = false;
      });
    }
  }

  void _removeImage() {
    setState(() => widget.draft.imageUrl = null);
  }

  double? get _enteredBudget => double.tryParse(_budgetController.text.trim());

  bool get _canProceed {
    switch (_mode) {
      case _BookingMode.film:
        return widget.draft.installArea != null &&
            widget.draft.product != null;
      case _BookingMode.wash:
        return widget.draft.product != null;
      case _BookingMode.repair:
        final budget = _enteredBudget;
        return widget.draft.imageUrl != null && budget != null && budget > 0;
    }
  }

  void _confirm() {
    if (_mode == _BookingMode.repair) {
      widget.draft.budget = _enteredBudget;
    }
    widget.onNext();
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
                _VehicleSummaryCard(
                  draft: widget.draft,
                  onChange: widget.onBack,
                ),
                const SizedBox(height: 20),
                ..._buildModeSections(),
              ],
            ),
          ),
        ),
        _buildBottomButton(),
      ],
    );
  }

  List<Widget> _buildModeSections() {
    switch (_mode) {
      case _BookingMode.film:
        return [
          const _SectionTitle('01 เลือกพื้นที่สำหรับติดฟิล์ม'),
          const SizedBox(height: 12),
          _buildAreaChips(),
          const SizedBox(height: 24),
          const _SectionTitle('02 เลือกฟิล์ม'),
          const SizedBox(height: 12),
          _buildProductList(showSpecs: true),
        ];
      case _BookingMode.wash:
        return [
          const _SectionTitle('01 เลือกแพ็กเกจ'),
          const SizedBox(height: 12),
          _buildProductList(showSpecs: false),
        ];
      case _BookingMode.repair:
        return [
          const _SectionTitle('01 รูปความเสียหาย'),
          const SizedBox(height: 12),
          _buildPhotoPicker(),
          const SizedBox(height: 24),
          const _SectionTitle('02 งบประมาณ'),
          const SizedBox(height: 12),
          _buildBudgetField(),
        ];
    }
  }

  Widget _buildAreaChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _installAreaOptions.map((opt) {
        final selected = widget.draft.installArea == opt.value;
        return ChoiceChip(
          label: Text(opt.label),
          selected: selected,
          selectedColor: AppColors.surfaceLight,
          onSelected: (_) => _selectArea(opt.value),
        );
      }).toList(),
    );
  }

  Widget _buildProductList({required bool showSpecs}) {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Text(_loadError!, style: const TextStyle(color: Colors.red));
    }
    if (_products.isEmpty) {
      return const Text(
        'ไม่พบรายการ',
        style: TextStyle(color: Colors.black54),
      );
    }
    return Column(
      children: _products
          .map(
            (p) => _ProductCard(
              product: p,
              selected: widget.draft.product?.id == p.id,
              showSpecs: showSpecs,
              onTap: () => _selectProduct(p),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPhotoPicker() {
    final imageUrl = widget.draft.imageUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  onPressed: _removeImage,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('ถ่ายรูป'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploading
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('เลือกรูป'),
                ),
              ),
            ],
          ),
        if (_uploading) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        if (_uploadError != null) ...[
          const SizedBox(height: 8),
          Text(_uploadError!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _buildBudgetField() {
    return TextField(
      controller: _budgetController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        hintText: 'ระบุงบประมาณโดยประมาณ',
        border: OutlineInputBorder(),
        suffixText: 'บาท',
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBottomButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _canProceed ? _confirm : null,
          child: const Text('ไปยังหน้านัดเวลา'),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
  );
}

class _VehicleSummaryCard extends StatelessWidget {
  const _VehicleSummaryCard({required this.draft, required this.onChange});

  final BookingDraft draft;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final vehicle = draft.vehicle;
    final title = vehicle == null
        ? 'ยังไม่ได้เลือกรถ'
        : (vehicle.year != null
              ? '${vehicle.brandModel} ${vehicle.year}'
              : vehicle.brandModel);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'รถของคุณ',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (vehicle != null) Text(vehicle.licensePlate),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('เปลี่ยน')),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.selected,
    required this.showSpecs,
    required this.onTap,
  });

  final Product product;
  final bool selected;
  final bool showSpecs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final specs = <String>[];
    if (showSpecs) {
      if (product.heatRejectionPct != null) {
        specs.add('กันร้อน ${product.heatRejectionPct}%');
      }
      if (product.uvRejectionPct != null) {
        specs.add('กัน UV ${product.uvRejectionPct}%');
      }
      if (product.vltPct != null) {
        specs.add('ความเข้ม ${product.vltPct}%');
      }
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.grey.shade300,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.brand != null) Text(product.brand!),
            if (product.description != null) Text(product.description!),
            if (specs.isNotEmpty) Text(specs.join(' · ')),
            Text(
              '${product.price.toStringAsFixed(0)} บาท',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? AppColors.primary : Colors.grey,
        ),
      ),
    );
  }
}
