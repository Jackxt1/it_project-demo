import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../theme/app_theme.dart';

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
      : vehicleType = initial?.vehicleType ?? 'SEDAN',
        brandModelController =
            TextEditingController(text: initial?.brandModel ?? ''),
        yearController =
            TextEditingController(text: initial?.year?.toString() ?? ''),
        licensePlateController =
            TextEditingController(text: initial?.licensePlate ?? '');

  String vehicleType;
  final TextEditingController brandModelController;
  final TextEditingController yearController;
  final TextEditingController licensePlateController;

  bool get isValid =>
      brandModelController.text.trim().isNotEmpty &&
      licensePlateController.text.trim().isNotEmpty;

  /// Builds a [Vehicle] from the current form values. Pass [id] to build an
  /// update request for an existing vehicle.
  Vehicle toVehicle({int? id}) => Vehicle(
        id: id,
        vehicleType: vehicleType,
        brandModel: brandModelController.text.trim(),
        year: int.tryParse(yearController.text.trim()),
        licensePlate: licensePlateController.text.trim(),
      );

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
        Wrap(
          spacing: 8,
          children: vehicleTypeOptions.map((opt) {
            final selected = controller.vehicleType == opt.value;
            return ChoiceChip(
              label: Text(opt.label),
              selected: selected,
              selectedColor: AppColors.surfaceLight,
              onSelected: (_) {
                controller.vehicleType = opt.value;
                _notifyChanged();
              },
            );
          }).toList(),
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
        const Text('ปีรถ'),
        const SizedBox(height: 8),
        TextField(
          controller: controller.yearController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (_) => _notifyChanged(),
        ),
        const SizedBox(height: 16),
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
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(widget.errorText!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }
}
