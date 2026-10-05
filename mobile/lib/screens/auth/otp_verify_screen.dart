import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_service.dart';
import '../../api/otp_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_widgets.dart';
import '../../widgets/otp_code_field.dart';
import '../main_shell.dart';
import 'complete_profile_screen.dart';

/// หน้ายืนยันรหัส OTP ที่ส่งไปยัง [phone] (รูป E.164)
class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({
    super.key,
    required this.phone,
    required this.resendAfterSeconds,
  });

  final String phone;
  final int resendAfterSeconds;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  String _code = '';
  bool _submitting = false;
  late int _secondsLeft;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown(widget.resendAfterSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _secondsLeft = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        timer.cancel();
      }
    });
  }

  /// +66968563615 → 096-856-3615 ให้ผู้ใช้อ่านง่าย
  String get _displayPhone {
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    final national = digits.startsWith('66') ? '0${digits.substring(2)}' : digits;
    if (national.length != 10) {
      return widget.phone;
    }
    return '${national.substring(0, 3)}-${national.substring(3, 6)}-${national.substring(6)}';
  }

  String get _countdownLabel {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return 'ขอรหัสใหม่อีกใน $minutes:$seconds';
  }

  Future<void> _resend() async {
    try {
      final result = await OtpApi.instance.requestCode(widget.phone);
      _startCountdown(result.resendAfterSeconds);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ส่งรหัสใหม่แล้ว')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _submit() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกรหัสให้ครบ 6 หลัก')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final session = await AuthService.instance
          .loginWithOtp(phone: widget.phone, code: _code);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => session.profileComplete
              ? const MainShell()
              : CompleteProfileScreen(phone: widget.phone),
        ),
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: BkkLogo(isLight: false, width: 200)),
              const SizedBox(height: 24),
              const Text(
                'ยืนยันรหัส OTP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'ส่งรหัส 6 หลักไปที่',
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
              OtpCodeField(
                onChanged: (code) => _code = code,
                onCompleted: (code) => _code = code,
              ),
              const SizedBox(height: 18),
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        _countdownLabel,
                        style: const TextStyle(fontSize: 12, color: Colors.black45),
                      )
                    : TextButton(
                        onPressed: _resend,
                        child: const Text('ขอรหัสใหม่'),
                      ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('ยืนยัน'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
