import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/vehicle_service.dart';
import '../../models/vehicle.dart';
import '../../theme/app_theme.dart';
import '../../widgets/vehicle_form.dart';

/// โปรไฟล์ → "รถของฉัน" (brief Task 8): รายการรถที่บันทึกไว้ + เพิ่ม/แก้/ลบ,
/// ใช้ [VehicleService] และฟอร์มร่วมกับ booking step 1 ([VehicleFormFields]).
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  List<Vehicle>? _vehicles;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final vehicles = await VehicleService.instance.fetchMine();
      if (!mounted) return;
      setState(() => _vehicles = vehicles);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดข้อมูลรถไม่สำเร็จ');
    }
  }

  Future<void> _openForm({Vehicle? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VehicleFormSheet(existing: existing),
    );
    if (saved == true) {
      _load();
    }
  }

  Future<void> _delete(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรถ'),
        content: Text('ต้องการลบ "${vehicle.brandModel}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await VehicleService.instance.delete(vehicle.id!);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('ลบไม่สำเร็จ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รถของฉัน')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final vehicles = _vehicles;
    if (vehicles == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && vehicles == null) {
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
    if (vehicles!.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 96),
            Center(
              child: Text(
                'ยังไม่มีรถที่บันทึกไว้',
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
        padding: const EdgeInsets.all(16),
        itemCount: vehicles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final vehicle = vehicles[index];
          final title = vehicle.year != null
              ? '${vehicle.brandModel} ${vehicle.year}'
              : vehicle.brandModel;
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.surfaceLight,
                child: Icon(Icons.directions_car, color: AppColors.primary),
              ),
              title: Text(title),
              subtitle: Text(vehicle.licensePlate),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openForm(existing: vehicle),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _delete(vehicle),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VehicleFormSheet extends StatefulWidget {
  const _VehicleFormSheet({this.existing});

  final Vehicle? existing;

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  late final _formController = VehicleFormController(initial: widget.existing);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formController.isValid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existingId = widget.existing?.id;
      if (existingId != null) {
        await VehicleService.instance.update(
          _formController.toVehicle(id: existingId),
        );
      } else {
        await VehicleService.instance.create(_formController.toVehicle());
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'บันทึกไม่สำเร็จ';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'แก้ไขข้อมูลรถ' : 'เพิ่มรถใหม่',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 16),
            VehicleFormFields(controller: _formController, errorText: _error),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }
}
