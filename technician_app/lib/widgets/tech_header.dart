import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Red header banner shared by every screen, matching the mockup's
/// `.header` block. Three shapes, matching the three ways screens use it:
/// - [TechHeader.brand]: home tab — avatar/company name, date, screen
///   title, and the calendar/notification icon buttons.
/// - [TechHeader.simple]: the other bottom-nav tab roots (history, profile)
///   — just a centered title, no back arrow since these are tab roots.
/// - [TechHeader.withBack]: pushed screens (job detail, calendar,
///   notifications) — back arrow + title.
class TechHeader extends StatelessWidget implements PreferredSizeWidget {
  const TechHeader._({
    required this.title,
    this.date,
    this.showBack = false,
    this.onBack,
    this.brandRow,
    this.extraHeight = 0,
  });

  factory TechHeader.brand({
    required String title,
    required String date,
    required Widget brandRow,
  }) =>
      TechHeader._(title: title, date: date, brandRow: brandRow, extraHeight: 26);

  factory TechHeader.simple({required String title}) =>
      TechHeader._(title: title, extraHeight: 4);

  factory TechHeader.withBack({required String title, required VoidCallback onBack}) =>
      TechHeader._(title: title, showBack: true, onBack: onBack);

  final String title;
  final String? date;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? brandRow;
  final double extraHeight;

  @override
  Size get preferredSize => Size.fromHeight(
        showBack ? 64 : (brandRow != null ? 128 : 76),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top + 14, 18, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBack)
            Row(
              children: [
                _CircleIconButton(icon: Icons.arrow_back, onTap: onBack!),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 16.5, fontWeight: FontWeight.w800),
                ),
              ],
            )
          else ...[
            ?brandRow,
            if (date != null) ...[
              const SizedBox(height: 14),
              Text(date!, style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              const SizedBox(height: 2),
            ],
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap, this.showDot = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              if (showDot)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54A),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryDark, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The avatar + company name + calendar/bell icon row used inside
/// [TechHeader.brand] on the home screen.
class TechBrandRow extends StatelessWidget {
  const TechBrandRow({
    super.key,
    required this.technicianName,
    required this.onCalendarTap,
    required this.onNotificationsTap,
    this.hasUnreadNotifications = false,
  });

  final String technicianName;
  final VoidCallback onCalendarTap;
  final VoidCallback onNotificationsTap;
  final bool hasUnreadNotifications;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
          child: const Icon(Icons.person, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BKK CAR GLASS & FILM',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.3),
              ),
              const SizedBox(height: 2),
              Text(
                technicianName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            ],
          ),
        ),
        _CircleIconButton(icon: Icons.calendar_month_outlined, onTap: onCalendarTap),
        const SizedBox(width: 10),
        _CircleIconButton(
          icon: Icons.notifications_outlined,
          onTap: onNotificationsTap,
          showDot: hasUnreadNotifications,
        ),
      ],
    );
  }
}
