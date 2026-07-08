import 'package:flutter/material.dart';
import 'api_client.dart';
import 'bookings_page.dart';
import 'login_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _byStatus;
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
      final summary = await ApiClient.instance.getDashboardSummary();
      final byStatus = await ApiClient.instance.getBookingsByStatus();
      setState(() {
        _summary = summary;
        _byStatus = byStatus;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _logout() {
    ApiClient.instance.token = null;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'จัดการคิว',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BookingsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 40),
                      Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _StatCard(
                            label: 'ยอดจองวันนี้',
                            value: '${_summary?['bookingsToday'] ?? 0}',
                          ),
                          _StatCard(
                            label: 'ยอดจองเดือนนี้',
                            value: '${_summary?['bookingsThisMonth'] ?? 0}',
                          ),
                          _StatCard(
                            label: 'รายรับเดือนนี้',
                            value: '฿${_summary?['revenueThisMonth'] ?? 0}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('จำนวนงานตามสถานะ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: (_byStatus?['statusCounts'] as Map<String, dynamic>? ?? {})
                            .entries
                            .map((e) => _StatCard(label: e.key, value: '${e.value}'))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const BookingsPage()),
                        ),
                        icon: const Icon(Icons.list_alt),
                        label: const Text('ดูรายการจองทั้งหมด'),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
