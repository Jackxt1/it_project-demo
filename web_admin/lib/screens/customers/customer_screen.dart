import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../models/customer.dart';
import '../../services/customer_service.dart';
import '../../theme/app_theme.dart';
import 'customer_detail_dialog.dart';

class CustomerScreen extends StatefulWidget {
  final ApiClient api;
  const CustomerScreen({super.key, required this.api});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  late final CustomerService _customerService = CustomerService(widget.api);
  final _searchController = TextEditingController();

  CustomerPage? _page;
  int _pageIndex = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _customerService.list(
        search: _searchController.text,
        page: page ?? _pageIndex,
      );
      setState(() {
        _page = result;
        _pageIndex = result.number;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetail(Customer customer) async {
    try {
      final detail = await _customerService.detail(customer.id);
      if (!mounted) return;
      showDialog(context: context, builder: (_) => CustomerDetailDialog(customer: detail));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('จัดการลูกค้า', style: Theme.of(context).textTheme.headlineMedium),
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'ค้นหาชื่อ / อีเมล / เบอร์โทร',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                  onSubmitted: (_) => _load(page: 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.red700)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () => _load(), child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    final page = _page!;
    if (page.content.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? 'ยังไม่มีลูกค้าในระบบ' : 'ไม่พบลูกค้าที่ค้นหา',
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }

    final dateFormat = DateFormat('d MMM yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('ชื่อ-นามสกุล')),
                    DataColumn(label: Text('อีเมล')),
                    DataColumn(label: Text('เบอร์โทร')),
                    DataColumn(label: Text('สมัครเมื่อ')),
                    DataColumn(label: Text('')),
                  ],
                  rows: page.content
                      .map((c) => DataRow(cells: [
                            DataCell(Text(c.fullName)),
                            DataCell(Text(c.email)),
                            DataCell(Text(c.phone ?? '-')),
                            DataCell(Text(dateFormat.format(c.createdAt))),
                            DataCell(
                              TextButton(onPressed: () => _openDetail(c), child: const Text('ดูรายละเอียด')),
                            ),
                          ]))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ทั้งหมด ${page.totalElements} คน • หน้า ${page.number + 1} จาก ${page.totalPages == 0 ? 1 : page.totalPages}',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            Row(
              children: [
                OutlinedButton(
                  onPressed: page.number > 0 ? () => _load(page: page.number - 1) : null,
                  child: const Text('ก่อนหน้า'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: page.number + 1 < page.totalPages ? () => _load(page: page.number + 1) : null,
                  child: const Text('ถัดไป'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
