import 'package:flutter/material.dart';

import '../../api/auth_service.dart';
import '../../theme/app_theme.dart';
import '../auth/phone_login_screen.dart';
import 'vehicles_screen.dart';

/// แท็บ "โปรไฟล์" (Task 8): การ์ดหัวสีแดงแสดง avatar/ชื่อ/อีเมลของผู้ใช้ที่
/// เข้าสู่ระบบอยู่ + เมนู "รถของฉัน" / "ประวัติการจอง" / "ออกจากระบบ".
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onViewBookingHistory});

  /// Called when the user taps "ประวัติการจอง" — [MainShell] uses this to
  /// switch to the bookings tab instead of pushing a new route.
  final VoidCallback? onViewBookingHistory;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('ต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthService.instance.session;
    final fullName = session?.fullName ?? '';
    final email = session?.email ?? '';
    final initial = fullName.trim().isNotEmpty
        ? fullName.trim().substring(0, 1).toUpperCase()
        : '?';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(initial: initial, fullName: fullName, email: email),
          const SizedBox(height: 24),
          _MenuItem(
            icon: Icons.directions_car_outlined,
            label: 'รถของฉัน',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const VehiclesScreen()),
            ),
          ),
          _MenuItem(
            icon: Icons.history,
            label: 'ประวัติการจอง',
            onTap: onViewBookingHistory,
          ),
          _MenuItem(
            icon: Icons.logout,
            label: 'ออกจากระบบ',
            destructive: true,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.initial,
    required this.fullName,
    required this.email,
  });

  final String initial;
  final String fullName;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDarker],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red : Colors.black87;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
      ),
    );
  }
}
