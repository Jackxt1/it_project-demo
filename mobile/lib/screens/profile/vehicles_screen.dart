import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/vehicle_service.dart';
import '../../models/vehicle.dart';
import '../../theme/app_theme.dart';
import '../../widgets/vehicle_form.dart';

const _pageBackground = Color(0xFFF7F4F4);
const _hairline = Color(0xFFEDE4E4);

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
      backgroundColor: _pageBackground,
      appBar: AppBar(
        title: const Text('รถของฉัน', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _hairline),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มรถ', style: TextStyle(fontWeight: FontWeight.w700)),
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
            const SizedBox(height: 90),
            _EmptyState(
              icon: Icons.cloud_off_outlined,
              title: _error!,
              hint: 'ดึงลงเพื่อลองใหม่',
              tint: const Color(0xFFD92020),
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
            SizedBox(height: 90),
            _EmptyState(
              icon: Icons.directions_car_outlined,
              title: 'ยังไม่มีรถที่บันทึกไว้',
              hint: 'เพิ่มรถไว้ก่อน จองครั้งต่อไปจะได้ไม่ต้องกรอกใหม่',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: vehicles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _VehicleCard(
          vehicle: vehicles[index],
          onEdit: () => _openForm(existing: vehicles[index]),
          onDelete: () => _delete(vehicles[index]),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.hint,
    this.tint = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String hint;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 34, color: tint),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2B2B2B),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = vehicle.year != null
        ? '${vehicle.brandModel} ${vehicle.year}'
        : vehicle.brandModel;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.directions_car, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
                const SizedBox(height: 5),
                // ทะเบียนทำเป็นป้ายเลียนแบบแผ่นป้ายจริง เพื่อให้กวาดตาหารถ
                // ที่ต้องการเจอเร็วกว่าอ่านเป็นข้อความบรรทัดรอง
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _pageBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _hairline),
                  ),
                  child: Text(
                    vehicle.licensePlate,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _CardIconButton(
            icon: Icons.edit_outlined,
            tooltip: 'แก้ไข',
            color: const Color(0xFFB7791F),
            background: const Color(0xFFFFF4DB),
            onPressed: onEdit,
          ),
          const SizedBox(width: 8),
          _CardIconButton(
            icon: Icons.delete_outline,
            tooltip: 'ลบ',
            color: const Color(0xFFD92020),
            background: const Color(0xFFFDE9E9),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.background,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
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
