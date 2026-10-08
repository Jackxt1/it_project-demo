import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/catalog_service.dart';
import '../../models/booking_draft.dart';
import '../../models/install_area.dart';
import '../../models/product.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bounce_on_change.dart';
import '../../widgets/booking_summary_card.dart';
import '../../widgets/bouncy_button.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/section_number_title.dart';

enum _BookingMode { film, wash, repair }

final NumberFormat _priceFormat = NumberFormat('#,###');

const _pageBackground = Color(0xFFF7F4F4);
const _hairline = Color(0xFFEDE4E4);

/// Label shown for a film whose `brand` the admin hasn't set yet — groups
/// those products under one selectable chip instead of hiding them.
const String _unspecifiedBrand = 'ไม่ระบุแบรนด์';

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

  /// Film mode only: brand chosen in "02 เลือกแบรนด์" before the film list
  /// (filtered to that brand) appears in "03 เลือกฟิล์ม". Restored from an
  /// already-selected product (e.g. the chatbot's "จองตัวนี้" recommendation)
  /// so returning users don't lose their pick.
  String? _selectedBrand;

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
    final existingProduct = widget.draft.product;
    if (existingProduct != null) {
      _selectedBrand = _brandOf(existingProduct);
    }
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

  /// Switching brand clears any film picked under the previous brand so the
  /// draft never ends up holding a product that no longer matches "02
  /// เลือกแบรนด์"'s selection.
  void _selectBrand(String brand) {
    setState(() {
      _selectedBrand = brand;
      final currentProduct = widget.draft.product;
      if (currentProduct != null && _brandOf(currentProduct) != brand) {
        widget.draft.product = null;
      }
    });
  }

  String _brandOf(Product product) => product.brand ?? _unspecifiedBrand;

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
          const _SectionTitle('02 เลือกแบรนด์'),
          const SizedBox(height: 12),
          _buildBrandChips(),
          const SizedBox(height: 24),
          const _SectionTitle('03 เลือกฟิล์ม'),
          const SizedBox(height: 12),
          _selectedBrand == null
              ? const _NoticeBox('กรุณาเลือกแบรนด์ก่อน')
              : _buildProductList(showSpecs: true, brand: _selectedBrand),
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
      children: installAreaOptions.map((opt) {
        final selected = widget.draft.installArea == opt.value;
        return _PillChip(
          label: opt.label,
          selected: selected,
          onTap: () => _selectArea(opt.value),
        );
      }).toList(),
    );
  }

  /// Distinct brands among the loaded film products, in first-seen order,
  /// with unbranded products grouped under [_unspecifiedBrand] so nothing
  /// is hidden while admins are still filling in `brand` values.
  List<String> get _availableBrands {
    final brands = <String>[];
    for (final product in _products) {
      final brand = _brandOf(product);
      if (!brands.contains(brand)) brands.add(brand);
    }
    return brands;
  }

  Widget _buildBrandChips() {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _NoticeBox(_loadError!, isError: true);
    }
    final brands = _availableBrands;
    if (brands.isEmpty) {
      return const _NoticeBox('ยังไม่มีฟิล์มในระบบ');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: brands.map((brand) {
        final selected = _selectedBrand == brand;
        return _PillChip(
          label: brand,
          selected: selected,
          onTap: () => _selectBrand(brand),
        );
      }).toList(),
    );
  }

  Widget _buildProductList({required bool showSpecs, String? brand}) {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _NoticeBox(_loadError!, isError: true);
    }
    final products = brand == null
        ? _products
        : _products.where((p) => _brandOf(p) == brand).toList();
    if (products.isEmpty) {
      return const _NoticeBox('ไม่พบรายการ');
    }
    return Column(
      children: products
          .asMap()
          .entries
          .map(
            (entry) => FadeSlideIn(
              index: entry.key,
              child: _ProductCard(
                product: entry.value,
                selected: widget.draft.product?.id == entry.value.id,
                showSpecs: showSpecs,
                showBrand: brand == null,
                onTap: () => _selectProduct(entry.value),
              ),
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
      decoration: InputDecoration(
        hintText: 'ระบุงบประมาณโดยประมาณ',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        filled: true,
        fillColor: Colors.white,
        suffixText: 'บาท',
        suffixStyle: const TextStyle(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: BouncyButton(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _canProceed ? _confirm : null,
              child: const Text('ไปยังหน้านัดเวลา'),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded outline chip — white bg/red border/red text when unselected,
/// solid red fill/white text when selected. Same visual language as step
/// 3's time-slot chips.
class _PillChip extends StatelessWidget {
  const _PillChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: BounceOnChange(
        trigger: selected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => SectionNumberTitle(text);
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
    return BookingSummaryCard(
      icon: Icons.directions_car,
      title: title,
      subtitle: vehicle?.licensePlate,
      trailing: TextButton(onPressed: onChange, child: const Text('เปลี่ยน')),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.selected,
    required this.showSpecs,
    required this.showBrand,
    required this.onTap,
  });

  final Product product;
  final bool selected;
  final bool showSpecs;

  /// ซ่อนแบรนด์เมื่อรายการถูกกรองด้วยชิปแบรนด์อยู่แล้ว — ทุกการ์ดจะเป็น
  /// แบรนด์เดียวกันหมด เขียนซ้ำทุกใบก็ไม่ได้บอกอะไรเพิ่ม
  final bool showBrand;
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? const Color(0xFFFFF5F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppColors.primary : _hairline,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.3,
                          color: Color(0xFF2B2B2B),
                        ),
                      ),
                      if (showBrand && product.brand != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.brand!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      if (product.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      if (specs.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: specs.map((s) => _SpecPill(s)).toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _priceFormat.format(product.price),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              height: 1,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'บาท',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                BounceOnChange(
                  trigger: selected,
                  child: Icon(
                    selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? AppColors.primary : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecPill extends StatelessWidget {
  const _SpecPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _pageBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _hairline),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
      ),
    );
  }
}

/// ข้อความแทนรายการที่ยังแสดงไม่ได้ (ยังไม่เลือกแบรนด์ / ไม่มีของ / โหลดพลาด)
/// ทำเป็นกล่องแทนบรรทัดลอยๆ ให้เห็นว่าตรงนี้คือที่ของรายการ ไม่ใช่หน้าพัง
class _NoticeBox extends StatelessWidget {
  const _NoticeBox(this.text, {this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tint = isError ? const Color(0xFFD92020) : Colors.grey.shade500;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFDE9E9) : _pageBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isError ? const Color(0xFFF5C9C9) : _hairline),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 18,
            color: tint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: isError ? const Color(0xFF8F1313) : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
