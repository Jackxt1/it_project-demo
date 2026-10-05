import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../main_shell.dart';

/// กรอกชื่อ-นามสกุลครั้งแรกหลังยืนยันเบอร์ เก็บรวมเป็น fullName ช่องเดียว
/// ตามที่ฐานข้อมูลเก็บ
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, required this.phone});

  final String phone;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  String get _displayPhone {
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    final national = digits.startsWith('66') ? '0${digits.substring(2)}' : digits;
    if (national.length != 10) {
      return widget.phone;
    }
    return '${national.substring(0, 3)}-${national.substring(3, 6)}-${national.substring(6)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final fullName =
          '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
      await AuthService.instance.completeProfile(fullName);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BkkLogo(isLight: false, width: 200)),
                const SizedBox(height: 24),
                const Text(
                  'ข้อมูลของคุณ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'ยืนยันเบอร์โทรศัพท์แล้ว',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  '+66 $_displayPhone',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                authFieldLabel('ชื่อ'),
                TextFormField(
                  controller: _firstNameController,
                  decoration: authFieldDecoration('กรุณากรอกชื่อ'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'กรุณากรอกชื่อ' : null,
                ),
                authFieldLabel('นามสกุล'),
                TextFormField(
                  controller: _lastNameController,
                  decoration: authFieldDecoration('กรุณากรอกนามสกุล'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'กรุณากรอกนามสกุล' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('เริ่มต้นใช้งาน'),
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
