import 'package:flutter/material.dart';

import '../../api/auth_service.dart';
import '../../state/technician_queue_controller.dart';
import '../../theme/app_theme.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ออกจากระบบ'),
            content: const Text('ยืนยันออกจากระบบบัญชีช่างนี้ใช่หรือไม่?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('ยกเลิก')),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('ออกจากระบบ', style: TextStyle(color: AppColors.primaryDark)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    await AuthService.instance.logout();
    TechnicianQueueController.instance.reset();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService.instance.session;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 28, 18, 26),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 10),
                Text(
                  session?.fullName ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                const Text('ช่างติดฟิล์ม/รถยนต์', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                const _SectionLabel('ข้อมูลบัญชี'),
                _ProfileRow(icon: Icons.email_outlined, label: session?.email ?? '-'),
                const SizedBox(height: 20),
                const _SectionLabel('บัญชี'),
                _ProfileRow(
                  icon: Icons.logout,
                  label: 'ออกจากระบบ',
                  danger: true,
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink900)),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.icon, required this.label, this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.primaryDark : AppColors.ink900;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
              if (onTap != null) const Icon(Icons.chevron_right, size: 18, color: AppColors.ink300),
            ],
          ),
        ),
      ),
    );
  }
}
