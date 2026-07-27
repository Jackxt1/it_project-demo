import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_service.dart';
import '../../theme/app_theme.dart';
import '../main_shell.dart';

final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
const String _comingSoonMessage = 'ฟีเจอร์นี้จะเปิดใช้เร็วๆ นี้';

// จัดสไตล์ Input ให้สวย สะอาด เต็มความกว้าง
InputDecoration _fieldDecoration(String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
    filled: true,
    fillColor: const Color(0xFFF5F5F5), // สีเทาอ่อนเรียบหรูตามแอปมาตรฐาน
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
    ),
    suffixIcon: suffixIcon,
  );
}

// Label ด้านบนช่องกรอก ขยายเต็มพื้นที่ไม่หดแคบ
Widget _fieldLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.black87,
      ),
    ),
  );
}

// --- Widget แสดง Logo ปรับเปลี่ยนมาควบคุมด้วย width แทน เพื่อไม่ให้ดัน Layout ---
class _BkkLogo extends StatelessWidget {
  const _BkkLogo({required this.isLight, this.width = 220});

  final bool isLight;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      isLight
          ? 'assets/image/white_logo.png' // โลโก้สีขาวสำหรับหน้า Login
          : 'assets/image/red_logo.png',  // โลโก้สีแดงสำหรับหน้า Register
      width: width,
      fit: BoxFit.contain,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  void _showComingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(_comingSoonMessage)));
  }

  void _goToMainShell() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _RegisterScreen(onSuccess: _goToMainShell),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBg, // พื้นหลังแอปสีมืด ด้านบน
      body: Column(
        children: [
          // ส่วนบน: โลโก้เว้นระยะปลอดภัยด้วย SafeArea เต็มหน้าจอ
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const Center(child: _BkkLogo(isLight: true, width: 220)),
            ),
          ),

          // ส่วนล่าง: กล่องขาวเนื้อหาหลัก ยืดขยายเต็มพื้นที่ที่เหลือ (Expanded)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // ส่วนสลับแท็บ เข้าสู่ระบบ / สมัครสมาชิก
                  _LoginRegisterTabs(onRegisterTap: _openRegister),

                  // ตัวฟอร์มกรอกข้อมูล สามารถเลื่อน scroll ได้เมื่อคีย์บอร์ดขึ้นมา
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: _LoginForm(
                        onSuccess: _goToMainShell,
                        onComingSoon: _showComingSoon,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginRegisterTabs extends StatelessWidget {
  const _LoginRegisterTabs({required this.onRegisterTap});

  final VoidCallback onRegisterTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Center(
                child: Text(
                  'เข้าสู่ระบบ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onRegisterTap,
                child: const Center(
                  child: Text(
                    'สมัครสมาชิก',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black45,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Indicator เส้นใต้แบบสมดุล
        Row(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const Expanded(child: SizedBox()),
          ],
        ),
      ],
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({required this.onSuccess, required this.onComingSoon});

  final VoidCallback onSuccess;
  final VoidCallback onComingSoon;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await AuthService.instance
          .login(_usernameController.text.trim(), _passwordController.text);
      if (!mounted) return;
      widget.onSuccess();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('เข้าสู่ระบบไม่สำเร็จ')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('ชื่อผู้ใช้'),
          TextFormField(
            controller: _usernameController,
            decoration: _fieldDecoration('กรุณากรอกชื่อผู้ใช้'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'กรุณากรอกชื่อผู้ใช้';
              return null;
            },
          ),
          const SizedBox(height: 8),
          _fieldLabel('รหัสผ่าน'),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: _fieldDecoration(
              'กรุณากรอกรหัสผ่าน',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: Colors.black45,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'กรุณากรอกรหัสผ่าน';
              return null;
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onComingSoon,
              child: const Text(
                'ลืมรหัสผ่าน?',
                style: TextStyle(
                  color: Color(0xFFB31818),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB31818),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: const [
              Expanded(child: Divider(color: Colors.black12)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('หรือ', style: TextStyle(color: Colors.black38, fontSize: 12)),
              ),
              Expanded(child: Divider(color: Colors.black12)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 50,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFBAA1A).withValues(alpha: 0.05),
                side: BorderSide(color: const Color(0xFF8F1313).withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: widget.onComingSoon,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/24px-Google_%22G%22_logo.svg.png',
                    height: 18,
                    errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'เข้าสู่ระบบด้วย Google',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterScreen extends StatefulWidget {
  const _RegisterScreen({required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<_RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<_RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await AuthService.instance.register(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      widget.onSuccess();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('สมัครสมาชิกไม่สำเร็จ')));
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
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: const Color(0xFFEEEEEE),
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.black87),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // แสดง red_logo.png กำหนดความกว้างที่ 220
                const Center(child: _BkkLogo(isLight: false, width: 220)),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'สมัครสมาชิก',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 8),
                _fieldLabel('อีเมล'),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _fieldDecoration('กรุณากรอกอีเมล'),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'กรุณากรอกอีเมล';
                    if (!_emailPattern.hasMatch(v)) return 'รูปแบบอีเมลไม่ถูกต้อง';
                    return null;
                  },
                ),
                _fieldLabel('ชื่อ-นามสกุล'),
                TextFormField(
                  controller: _fullNameController,
                  decoration: _fieldDecoration('กรุณากรอกชื่อ-นามสกุล'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'กรุณากรอกชื่อ-นามสกุล';
                    return null;
                  },
                ),
                _fieldLabel('เบอร์โทรศัพท์'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _fieldDecoration('กรุณากรอกเบอร์โทรศัพท์'),
                ),
                _fieldLabel('รหัสผ่าน'),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _fieldDecoration(
                    'กรุณากรอกรหัสผ่าน (อย่างน้อย 6 ตัว)',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: Colors.black45,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                    if (value.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัว';
                    return null;
                  },
                ),
                _fieldLabel('ยืนยันรหัสผ่าน'),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _fieldDecoration(
                    'กรุณากรอกรหัสผ่านอีกครั้ง',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        size: 20,
                        color: Colors.black45,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
                    if (value != _passwordController.text) return 'รหัสผ่านไม่ตรงกัน';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB31818),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('ลงทะเบียน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
