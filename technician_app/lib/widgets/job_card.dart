import 'package:flutter/material.dart';

import '../models/booking.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../utils/thai_date.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.onDark = false});

  final String status;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final Color? border;
    switch (status) {
      case 'IN_PROGRESS':
        bg = onDark ? Colors.white : AppColors.primary;
        fg = onDark ? AppColors.primary : Colors.white;
        border = null;
      case 'CONFIRMED':
        bg = Colors.transparent;
        fg = onDark ? Colors.white : AppColors.amber;
        border = onDark ? Colors.white : AppColors.amber;
      case 'COMPLETED':
        bg = AppColors.greenSurface;
        fg = AppColors.green;
        border = null;
      case 'CANCELLED':
        bg = AppColors.ink100;
        fg = AppColors.ink500;
        border = null;
      default:
        bg = AppColors.ink100;
        fg = AppColors.ink700;
        border = null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: border != null ? Border.all(color: border, width: 1.3) : null,
      ),
      child: Text(
        bookingStatusLabel(status),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// A single job row, matching the mockup's `.job-card`. Highlighted (solid
/// red) for `IN_PROGRESS`, same as the mockup's "driving" state — the job
/// the technician is actively working on right now.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.booking, required this.onTap, this.showDate = false});

  final Booking booking;
  final VoidCallback onTap;

  /// Shows the booking date above the time slot — used in the history and
  /// calendar-month lists, where cards from many different days sit
  /// together and the time alone would be ambiguous.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final highlight = booking.status == 'IN_PROGRESS';
    final amount = booking.displayAmount;
    return Material(
      color: highlight ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: highlight ? Colors.white.withValues(alpha: 0.25) : AppColors.ink100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, size: 18, color: highlight ? Colors.white : AppColors.ink700),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.userFullName,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: highlight ? Colors.white : AppColors.ink900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (booking.vehicleBrandModel != null) booking.vehicleBrandModel!,
                            booking.serviceName,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: 12,
                            color: highlight ? Colors.white.withValues(alpha: 0.85) : AppColors.ink500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (showDate)
                        Text(
                          thaiShortDate(booking.bookingDate),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: highlight ? Colors.white70 : AppColors.ink500,
                          ),
                        ),
                      Text(
                        booking.timeSlot,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: highlight ? Colors.white : AppColors.ink900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBadge(status: booking.status, onDark: highlight),
                        if (amount != null)
                          Text(
                            formatBaht(amount),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: highlight ? Colors.white : AppColors.ink700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.storefront_outlined, size: 12, color: highlight ? Colors.white70 : AppColors.ink500),
                  const SizedBox(width: 2),
                  Text(
                    'ที่ร้าน',
                    style: TextStyle(fontSize: 11.5, color: highlight ? Colors.white70 : AppColors.ink500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
