import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/stripe_pattern.dart';
import 'customers/customer_screen.dart';
import 'login_screen.dart';
import 'technicians/technician_screen.dart';

class AdminShell extends StatefulWidget {
  final AuthService authService;
  const AdminShell({super.key, required this.authService});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late final ApiClient _api = ApiClient(widget.authService);
  int _selected = 0;
  String? _fullName;

  static const _sections = [
    (icon: Icons.build_outlined, label: 'ช่าง'),
    (icon: Icons.people_outline, label: 'ลูกค้า'),
  ];

  @override
  void initState() {
    super.initState();
    widget.authService.getFullName().then((v) => setState(() => _fullName = v));
  }

  Future<void> _logout() async {
    await widget.authService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(authService: widget.authService)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Row(
        children: [
          _Sidebar(
            selected: _selected,
            sections: _sections,
            fullName: _fullName,
            onSelect: (i) => setState(() => _selected = i),
            onLogout: _logout,
          ),
          Expanded(
            child: IndexedStack(
              index: _selected,
              children: [
                TechnicianScreen(api: _api),
                CustomerScreen(api: _api),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int selected;
  final List<({IconData icon, String label})> sections;
  final String? fullName;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.selected,
    required this.sections,
    required this.fullName,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.red900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 108,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: const StripePatternPainter()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BKK CARGLASS',
                        style: GoogleFonts.oswald(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'ADMIN CONSOLE',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < sections.length; i++) _NavItem(
                icon: sections[i].icon,
                label: sections[i].label,
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
          const Spacer(),
          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fullName ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                  tooltip: 'ออกจากระบบ',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 19, color: selected ? AppColors.red700 : Colors.white),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.oswald(
                    color: selected ? AppColors.red700 : Colors.white,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                    fontSize: 14,
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
