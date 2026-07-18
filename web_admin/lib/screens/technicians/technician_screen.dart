import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../models/booking.dart';
import '../../models/technician.dart';
import '../../services/booking_service.dart';
import '../../services/technician_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import 'technician_form_dialog.dart';

class TechnicianScreen extends StatefulWidget {
  final ApiClient api;
  const TechnicianScreen({super.key, required this.api});

  @override
  State<TechnicianScreen> createState() => _TechnicianScreenState();
}

class _TechnicianScreenState extends State<TechnicianScreen> {
  late final TechnicianService _technicianService = TechnicianService(widget.api);
  late final BookingService _bookingService = BookingService(widget.api);

  List<Technician> _technicians = [];
  List<BookingSummary> _bookings = [];
  bool _loading = true;
  String? _error;

  static const _assignableStatuses = {'PENDING', 'CONFIRMED', 'IN_PROGRESS'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([_technicianService.list(), _bookingService.list()]);
      setState(() {
        _technicians = results[0] as List<Technician>;
        _bookings = (results[1] as List<BookingSummary>)
            .where((b) => _assignableStatuses.contains(b.status))
            .toList();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm({Technician? existing}) async {
    final result = await showDialog<TechnicianFormResult>(
      context: context,
      builder: (_) => TechnicianFormDialog(existing: existing),
    );
    if (result == null) return;
    try {
      if (existing == null) {
        await _technicianService.create(result.fullName, result.phone);
      } else {
        await _technicianService.update(existing.id, result.fullName, result.phone);
      }
      await _load();
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _deactivate(Technician technician) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ปิดใช้งานช่าง'),
        content: Text('ยืนยันปิดใช้งาน "${technician.fullName}"? ช่างจะไม่ถูกลบ แต่จะเลือกมอบหมายงานใหม่ไม่ได้'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('ปิดใช้งาน')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _technicianService.deactivate(technician.id);
      await _load();
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _assign(BookingSummary booking, int? technicianId) async {
    if (technicianId == null) return;
    try {
      await _bookingService.assignTechnician(booking.id, technicianId);
      await _load();
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  Future<void> _startJob(BookingSummary booking) async {
    try {
      await _bookingService.updateStatus(booking.id, 'IN_PROGRESS');
      await _load();
    } on ApiException catch (e) {
      _showError(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.red700)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('จัดการช่าง', style: Theme.of(context).textTheme.headlineMedium),
              ElevatedButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('เพิ่มช่างใหม่'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _TechnicianTable(
            technicians: _technicians,
            onEdit: (t) => _openForm(existing: t),
            onDeactivate: _deactivate,
          ),
          const SizedBox(height: 36),
          Text('มอบหมายช่างให้งาน', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text(
            'เลือกช่างให้แต่ละงาน — ต้องมอบหมายช่างก่อนถึงจะเริ่มงานได้',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          _AssignmentTable(
            bookings: _bookings,
            technicians: _technicians.where((t) => t.active).toList(),
            onAssign: _assign,
            onStart: _startJob,
          ),
        ],
      ),
    );
  }
}

class _TechnicianTable extends StatelessWidget {
  final List<Technician> technicians;
  final ValueChanged<Technician> onEdit;
  final ValueChanged<Technician> onDeactivate;

  const _TechnicianTable({required this.technicians, required this.onEdit, required this.onDeactivate});

  @override
  Widget build(BuildContext context) {
    if (technicians.isEmpty) {
      return const _EmptyState(message: 'ยังไม่มีรายชื่อช่าง เพิ่มช่างคนแรกได้เลย');
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ชื่อ-นามสกุล')),
            DataColumn(label: Text('เบอร์โทร')),
            DataColumn(label: Text('สถานะ')),
            DataColumn(label: Text('จัดการ')),
          ],
          rows: technicians
              .map((t) => DataRow(cells: [
                    DataCell(Text(t.fullName)),
                    DataCell(Text(t.phone ?? '-')),
                    DataCell(StatusChip.technicianActive(t.active)),
                    DataCell(Row(
                      children: [
                        TextButton(onPressed: () => onEdit(t), child: const Text('แก้ไข')),
                        if (t.active)
                          TextButton(
                            onPressed: () => onDeactivate(t),
                            child: const Text('ปิดใช้งาน'),
                          ),
                      ],
                    )),
                  ]))
              .toList(),
        ),
      ),
    );
  }
}

class _AssignmentTable extends StatelessWidget {
  final List<BookingSummary> bookings;
  final List<Technician> technicians;
  final void Function(BookingSummary, int?) onAssign;
  final ValueChanged<BookingSummary> onStart;

  const _AssignmentTable({
    required this.bookings,
    required this.technicians,
    required this.onAssign,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const _EmptyState(message: 'ยังไม่มีงานที่รอมอบหมายในตอนนี้');
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ลูกค้า')),
            DataColumn(label: Text('บริการ')),
            DataColumn(label: Text('วันที่/เวลา')),
            DataColumn(label: Text('สถานะ')),
            DataColumn(label: Text('ช่างที่มอบหมาย')),
            DataColumn(label: Text('จัดการ')),
          ],
          rows: bookings.map((b) {
            return DataRow(cells: [
              DataCell(Text(b.userFullName)),
              DataCell(Text(b.serviceName)),
              DataCell(Text('${b.bookingDate.year}-${b.bookingDate.month.toString().padLeft(2, '0')}-${b.bookingDate.day.toString().padLeft(2, '0')} ${b.timeSlot}')),
              DataCell(StatusChip.booking(b.status)),
              DataCell(
                DropdownButton<int>(
                  value: b.technicianId,
                  hint: const Text('เลือกช่าง'),
                  underline: const SizedBox.shrink(),
                  items: technicians
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.fullName)))
                      .toList(),
                  onChanged: (id) => onAssign(b, id),
                ),
              ),
              DataCell(
                b.status == 'CONFIRMED'
                    ? OutlinedButton(onPressed: () => onStart(b), child: const Text('เริ่มงาน'))
                    : const SizedBox.shrink(),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(message, style: const TextStyle(color: AppColors.muted)),
    );
  }
}
