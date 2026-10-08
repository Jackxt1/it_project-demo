import 'package:flutter/material.dart';

import '../../api/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../util/phone_display.dart';
import '../auth/phone_login_screen.dart';
import 'vehicles_screen.dart';

const _pageBackground = Color(0xFFF7F4F4);
const _hairline = Color(0xFFEDE4E4);

/// แท็บ "โปรไฟล์" (Task 8): การ์ดหัวสีแดงแสดง avatar/ชื่อ/เบอร์โทร/อีเมลของ
/// ผู้ใช้ที่เข้าสู่ระบบอยู่ + เมนู "รถของฉัน" / "ประวัติการจอง" / "ออกจากระบบ".
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onViewBookingHistory});

  /// Called when the user taps "ประวัติการจอง" — [MainShell] uses this to
  /// switch to the bookings tab instead of pushing a new route.
  final VoidCallback? onViewBookingHistory;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('ออกจากระบบ'),
        content: const Text('ต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'ยืนยัน',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
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
    final phone = session?.phone ?? '';
    final initial = fullName.trim().isNotEmpty
        ? fullName.trim().substring(0, 1).toUpperCase()
        : '?';

    return Container(
      color: _pageBackground,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _HeaderCard(
              initial: initial,
              fullName: fullName,
              email: email,
              phone: phone,
            ),
            const SizedBox(height: 22),
            const _SectionLabel('บัญชีของฉัน'),
            const SizedBox(height: 8),
            _MenuCard(
              children: [
                _MenuItem(
                  icon: Icons.directions_car_outlined,
                  label: 'รถของฉัน',
                  subtitle: 'ข้อมูลรถที่ใช้จองบริการ',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const VehiclesScreen()),
                  ),
                ),
                _MenuItem(
                  icon: Icons.history,
                  label: 'ประวัติการจอง',
                  subtitle: 'งานที่เคยใช้บริการทั้งหมด',
                  onTap: onViewBookingHistory,
                ),
              ],
            ),
            const SizedBox(height: 22),
            _MenuCard(
              children: [
                _MenuItem(
                  icon: Icons.logout,
                  label: 'ออกจากระบบ',
                  destructive: true,
                  onTap: () => _confirmLogout(context),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: Column(
                children: [
                  Text(
                    'BKK CAR GLASS & SERVICE',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ติดฟิล์ม · ซ่อมกระจก · ล้างรถ',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.initial,
    required this.fullName,
    required this.email,
    required this.phone,
  });

  final String initial;
  final String fullName;
  final String email;
  final String phone;

  @override
  Widget build(BuildContext context) {
    // บัญชีที่สมัครด้วยเบอร์อย่างเดียวจะไม่มีอีเมล ส่วนบัญชีเก่าที่สมัครด้วย
    // อีเมลอาจไม่มีเบอร์ — แสดงเฉพาะอันที่มีจริง ไม่งั้นเหลือบรรทัดว่างเปล่า
    final contacts = <Widget>[
      if (phone.isNotEmpty)
        _ContactRow(icon: Icons.phone_outlined, text: formatThaiPhone(phone)),
      if (email.isNotEmpty)
        _ContactRow(icon: Icons.mail_outline, text: email),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDarker],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  child: CircleAvatar(
                    radius: 31,
                    backgroundColor: Colors.white,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.trim().isEmpty ? 'ผู้ใช้งาน' : fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_outlined,
                                size: 12, color: Colors.white),
                            SizedBox(width: 5),
                            Text(
                              'สมาชิก',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (contacts.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: contacts,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.8)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// กล่องขาวที่รวมหลายเมนูไว้ด้วยกัน คั่นด้วยเส้นบางๆ แทนการ์ดแยกใบ
/// เพราะเมนูแยกใบทำให้ทุกอย่างดูน้ำหนักเท่ากันไปหมด
class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, indent: 64, color: _hairline),
            children[i],
          ],
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
    this.subtitle,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFD92020) : const Color(0xFF2B2B2B);
    final iconColor = destructive ? const Color(0xFFD92020) : AppColors.primaryDark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: destructive
                    ? const Color(0xFFD92020).withValues(alpha: 0.10)
                    : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
