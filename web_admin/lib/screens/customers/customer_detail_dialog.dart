import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/customer.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';

class CustomerDetailDialog extends StatelessWidget {
  final CustomerDetail customer;
  const CustomerDetailDialog({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');
    return AlertDialog(
      title: Text(customer.fullName),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customer.email, style: const TextStyle(color: AppColors.muted)),
              if (customer.phone != null)
                Text(customer.phone!, style: const TextStyle(color: AppColors.muted)),
              Text(
                'สมัครเมื่อ ${dateFormat.format(customer.createdAt)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Text('ประวัติการจอง (${customer.bookings.length})',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              if (customer.bookings.isEmpty)
                const Text('ยังไม่มีประวัติการจอง', style: TextStyle(color: AppColors.muted))
              else
                ...customer.bookings.map((b) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.serviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  '${dateFormat.format(b.bookingDate)} • ${b.timeSlot}',
                                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                ),
                                if (b.technicianName != null)
                                  Text('ช่าง: ${b.technicianName}',
                                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                          StatusChip.booking(b.status),
                        ],
                      ),
                    )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ปิด')),
      ],
    );
  }
}
