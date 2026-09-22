import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../theme/app_theme.dart';
import 'bounce_on_change.dart';

class VehicleTypeOption {
  const VehicleTypeOption(this.label, this.value);
  final String label;
  final String value;
}

const List<VehicleTypeOption> vehicleTypeOptions = [
  VehicleTypeOption('เก๋ง', 'SEDAN'),
  VehicleTypeOption('กระบะ', 'PICKUP'),
  VehicleTypeOption('SUV', 'SUV'),
  VehicleTypeOption('อื่นๆ', 'OTHER'),
];

/// Owns the mutable state (text controllers + selected type chip) behind
/// [VehicleFormFields], independent of any particular screen. Callers create
/// one per form instance, read [toVehicle] once the user submits, and must
/// call [dispose] when done (mirrors [TextEditingController]'s lifecycle).
class VehicleFormController {
  VehicleFormController({Vehicle? initial})
      : vehicleType = initial?.vehicleType,
        brandModelController =
            TextEditingController(text: initial?.brandModel ?? ''),
        yearController =
            TextEditingController(text: initial?.year?.toString() ?? ''),
        licensePlateController =
            TextEditingController(text: initial?.licensePlate ?? '');

  /// Null until the user actively taps a ประเภทรถ button — a fresh form
  /// must not read as if a type were already chosen.
  String? vehicleType;
  final TextEditingController brandModelController;
  final TextEditingController yearController;
  final TextEditingController licensePlateController;

  bool get isValid =>
      vehicleType != null &&
      brandModelController.text.trim().isNotEmpty &&
      licensePlateController.text.trim().isNotEmpty;

  /// Builds a [Vehicle] from the current form values. Pass [id] to build an
  /// update request for an existing vehicle. Only call once [isValid].
  Vehicle toVehicle({int? id}) => Vehicle(
        id: id,
        vehicleType: vehicleType!,
        brandModel: brandModelController.text.trim(),
        year: int.tryParse(yearController.text.trim()),
        licensePlate: licensePlateController.text.trim(),
      );

  /// Clears the form back to its untouched state — used when the user picks
  /// a saved vehicle instead, so "เพิ่มคันใหม่" doesn't keep showing values
  /// from a form they abandoned.
  void reset() {
    vehicleType = null;
    brandModelController.clear();
    yearController.clear();
    licensePlateController.clear();
  }

  void dispose() {
    brandModelController.dispose();
    yearController.dispose();
    licensePlateController.dispose();
  }
}

/// Shared "ข้อมูลรถ" form (type chips เก๋ง/กระบะ/SUV/อื่นๆ, ยี่ห้อและรุ่น, ปีรถ,
/// ทะเบียนรถ) — the same fields used by booking step 1 and by the profile's
/// "รถของฉัน" add/edit form, factored out so both stay in sync.
class VehicleFormFields extends StatefulWidget {
  const VehicleFormFields({
    super.key,
    required this.controller,
    this.onChanged,
    this.errorText,
  });

  final VehicleFormController controller;
  final VoidCallback? onChanged;
  final String? errorText;

  @override
  State<VehicleFormFields> createState() => _VehicleFormFieldsState();
}

class _VehicleFormFieldsState extends State<VehicleFormFields> {
  void _notifyChanged() {
    setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ประเภทรถ'),
        const SizedBox(height: 8),
        _VehicleTypeGrid(
          selectedValue: controller.vehicleType,
          onSelected: (value) {
            controller.vehicleType = value;
            _notifyChanged();
          },
        ),
        const SizedBox(height: 16),
        const Text('ยี่ห้อและรุ่น'),
        const SizedBox(height: 8),
        TextField(
          controller: controller.brandModelController,
          decoration: const InputDecoration(
            hintText: 'เช่น Honda Civic',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => _notifyChanged(),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ปีรถ'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller.yearController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    onChanged: (_) => _notifyChanged(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ทะเบียนรถ'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller.licensePlateController,
                    decoration: const InputDecoration(
                      hintText: 'ตด 8888',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _notifyChanged(),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(widget.errorText!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }
}

/// 2-column grid of filled ประเภทรถ buttons (gray when unselected, solid
/// brand red when selected) — laid out two-per-row rather than [Wrap]'s
/// auto-sized chips so every button fills half the row width evenly.
class _VehicleTypeGrid extends StatelessWidget {
  const _VehicleTypeGrid({required this.selectedValue, required this.onSelected});

  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < vehicleTypeOptions.length; i += 2) {
      final rowOptions = vehicleTypeOptions.skip(i).take(2).toList();
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(
        Row(
          children: [
            for (var j = 0; j < rowOptions.length; j++) ...[
              if (j > 0) const SizedBox(width: 8),
              Expanded(
                child: _VehicleTypeButton(
                  label: rowOptions[j].label,
                  selected: selectedValue == rowOptions[j].value,
                  onTap: () => onSelected(rowOptions[j].value),
                ),
              ),
            ],
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

class _VehicleTypeButton extends StatelessWidget {
  const _VehicleTypeButton({
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
      borderRadius: BorderRadius.circular(14),
      child: BounceOnChange(
        trigger: selected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}
