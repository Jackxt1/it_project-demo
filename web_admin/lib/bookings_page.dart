import 'package:flutter/material.dart';
import 'api_client.dart';

const List<String> bookingStatuses = [
  'PENDING',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED',
];

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  List<dynamic> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bookings = await ApiClient.instance.getAllBookings();
      bookings.sort((a, b) => (b['id'] as int).compareTo(a['id'] as int));
      setState(() => _bookings = bookings);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openStatusDialog(Map<String, dynamic> booking) async {
    String status = booking['status'] as String;
    final noteController = TextEditingController();
    final quoteController = TextEditingController(
      text: booking['quotePrice']?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('อัปเดตสถานะ — คิว #${booking['id']}'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ลูกค้า: ${booking['userFullName'] ?? '-'}'),
                Text('บริการ: ${booking['serviceName'] ?? '-'}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'สถานะ'),
                  items: bookingStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => status = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quoteController,
                  decoration: const InputDecoration(labelText: 'ราคาประเมิน (ถ้ามี)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'หมายเหตุ (ถ้ามี)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    try {
      await ApiClient.instance.updateBookingStatus(
        booking['id'] as int,
        status: status,
        note: noteController.text.trim(),
        quotePrice: quoteController.text.trim(),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปเดตสถานะสำเร็จ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.red),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'CONFIRMED':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.purple;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการคิว'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _bookings.isEmpty
                  ? const Center(child: Text('ยังไม่มีรายการจอง'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('ID')),
                          DataColumn(label: Text('ลูกค้า')),
                          DataColumn(label: Text('บริการ')),
                          DataColumn(label: Text('วันที่นัด')),
                          DataColumn(label: Text('เวลา')),
                          DataColumn(label: Text('งบประมาณ')),
                          DataColumn(label: Text('สถานะ')),
                          DataColumn(label: Text('')),
                        ],
                        rows: _bookings.map((b) {
                          final booking = b as Map<String, dynamic>;
                          return DataRow(cells: [
                            DataCell(Text('${booking['id']}')),
                            DataCell(Text(booking['userFullName'] ?? '-')),
                            DataCell(Text(booking['serviceName'] ?? '-')),
                            DataCell(Text(booking['bookingDate'] ?? '-')),
                            DataCell(Text(booking['timeSlot'] ?? '-')),
                            DataCell(Text(booking['budget'] != null ? '฿${booking['budget']}' : '-')),
                            DataCell(Chip(
                              label: Text(
                                booking['status'] ?? '-',
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                              backgroundColor: _statusColor(booking['status'] ?? ''),
                            )),
                            DataCell(TextButton(
                              onPressed: () => _openStatusDialog(booking),
                              child: const Text('อัปเดต'),
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
    );
  }
}
