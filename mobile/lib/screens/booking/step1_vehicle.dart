import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/vehicle_service.dart';
import '../../models/booking_draft.dart';
import '../../models/vehicle.dart';
import '../../theme/app_theme.dart';
import '../../widgets/vehicle_form.dart';

/// Step 1/5 ของ booking flow (Figma pages 8-9): เลือกรถที่บันทึกไว้ หรือ
/// กรอกฟอร์มเพิ่มรถใหม่แล้วบันทึก.
///
/// - มีรถที่บันทึกไว้: หัวข้อ "01 รถที่บันทึกไว้" + การ์ดรายการรถ (เลือกได้
///   ทีละคัน) + "02 เพิ่มคันใหม่" (ฟอร์มเดียวกับด้านล่าง)
/// - ไม่มีรถ: การ์ดเทา "ยังไม่มีรถที่บันทึกไว้" + ฟอร์ม "01 ข้อมูลรถของคุณ"
///
/// ปุ่มล่างสุดเปลี่ยนป้ายตามโหมด: เลือกรถเดิม → [nextLabel] (ป้อนจากบริการ
/// ที่เลือกไว้), กำลังกรอกฟอร์มรถใหม่ → "บันทึกและไปต่อ".
class Step1Vehicle extends StatefulWidget {
  const Step1Vehicle({
    super.key,
    required this.draft,
    required this.nextLabel,
    required this.onNext,
  });

  final BookingDraft draft;
  final String nextLabel;
  final VoidCallback onNext;

  @override
  State<Step1Vehicle> createState() => _Step1VehicleState();
}

class _Step1VehicleState extends State<Step1Vehicle> {
  List<Vehicle> _vehicles = [];
  bool _loading = true;
  String? _loadError;

  Vehicle? _selected;
  final _formController = VehicleFormController();

  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _selected = widget.draft.vehicle;
    _load();
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final vehicles = await VehicleService.instance.fetchMine();
      if (!mounted) return;
      setState(() {
        _vehicles = vehicles;
        _loading = false;
        if (_selected == null && vehicles.isNotEmpty) {
          _selected = vehicles.first;
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'โหลดข้อมูลรถไม่สำเร็จ';
        _loading = false;
      });
    }
  }

  bool get _formValid => _formController.isValid;

  void _selectVehicle(Vehicle vehicle) {
    setState(() => _selected = vehicle);
  }

  /// Typing into the "add new vehicle" form while an existing vehicle is
  /// selected switches the flow into "adding a new vehicle" mode, which is
  /// what drives the bottom button's label/action.
  void _onFormFieldChanged() {
    setState(() {
      if (_vehicles.isNotEmpty && _selected != null) {
        _selected = null;
      }
    });
  }

  void _confirmSelected() {
    widget.draft.vehicle = _selected;
    widget.onNext();
  }

  Future<void> _saveNewVehicle() async {
    if (!_formValid || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final created = await VehicleService.instance.create(
        _formController.toVehicle(),
      );
      if (!mounted) return;
      widget.draft.vehicle = created;
      setState(() => _saving = false);
      widget.onNext();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saveError = e.message;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveError = 'บันทึกไม่สำเร็จ';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Text(_loadError!));
    }

    final hasVehicles = _vehicles.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: hasVehicles ? _buildVehicleList() : _buildEmptyAndForm(),
          ),
        ),
        _buildBottomButton(),
      ],
    );
  }

  Widget _buildVehicleList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '01 รถที่บันทึกไว้',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        ..._vehicles.map(
          (v) => _VehicleCard(
            vehicle: v,
            selected: _selected?.id == v.id,
            onTap: () => _selectVehicle(v),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '02 เพิ่มคันใหม่',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _buildForm(),
      ],
    );
  }

  Widget _buildEmptyAndForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'ยังไม่มีรถที่บันทึกไว้',
            style: TextStyle(color: Colors.black54),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '01 ข้อมูลรถของคุณ',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _buildForm(),
      ],
    );
  }

  Widget _buildForm() {
    return VehicleFormFields(
      controller: _formController,
      onChanged: _onFormFieldChanged,
      errorText: _saveError,
    );
  }

  Widget _buildBottomButton() {
    final usingExisting = _vehicles.isNotEmpty && _selected != null;
    final label = usingExisting ? widget.nextLabel : 'บันทึกและไปต่อ';
    final enabled = !_saving && (usingExisting || _formValid);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: enabled
              ? (usingExisting ? _confirmSelected : _saveNewVehicle)
              : null,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(label),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = vehicle.year != null
        ? '${vehicle.brandModel} ${vehicle.year}'
        : vehicle.brandModel;

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
        leading: const CircleAvatar(
          backgroundColor: AppColors.surfaceLight,
          child: Icon(Icons.directions_car, color: AppColors.primary),
        ),
        title: Text(title),
        subtitle: Text(vehicle.licensePlate),
        // A plain icon (rather than [Radio]) avoids needing a [RadioGroup]
        // ancestor just to show single-select state across cards that are
        // built independently.
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? AppColors.primary : Colors.grey,
        ),
      ),
    );
  }
}
