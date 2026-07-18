import 'package:flutter/material.dart';

import '../../models/technician.dart';

class TechnicianFormResult {
  final String fullName;
  final String? phone;
  TechnicianFormResult(this.fullName, this.phone);
}

class TechnicianFormDialog extends StatefulWidget {
  final Technician? existing;
  const TechnicianFormDialog({super.key, this.existing});

  @override
  State<TechnicianFormDialog> createState() => _TechnicianFormDialogState();
}

class _TechnicianFormDialogState extends State<TechnicianFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _fullNameController = TextEditingController(text: widget.existing?.fullName ?? '');
  late final _phoneController = TextEditingController(text: widget.existing?.phone ?? '');

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'แก้ไขข้อมูลช่าง' : 'เพิ่มช่างใหม่'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อช่าง' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'เบอร์โทร (ไม่บังคับ)'),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก')),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final phone = _phoneController.text.trim();
            Navigator.of(context).pop(
              TechnicianFormResult(_fullNameController.text.trim(), phone.isEmpty ? null : phone),
            );
          },
          child: const Text('บันทึก'),
        ),
      ],
    );
  }
}
