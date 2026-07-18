import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final StatusTone tone;

  const StatusChip({super.key, required this.label, required this.tone});

  factory StatusChip.booking(String status) => StatusChip(
        label: bookingStatusLabelTh[status] ?? status,
        tone: bookingStatusTone(status),
      );

  factory StatusChip.technicianActive(bool active) => StatusChip(
        label: active ? 'ใช้งาน' : 'ปิดใช้งาน',
        tone: active
            ? const StatusTone(AppColors.redTintMid, AppColors.red900)
            : const StatusTone(AppColors.neutralChipBg, AppColors.neutralChipText),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
