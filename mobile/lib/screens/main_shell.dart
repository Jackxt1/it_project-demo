import 'package:flutter/material.dart';

import '../models/service_item.dart';
import '../theme/app_theme.dart';
import 'booking/booking_flow.dart';
import 'home/home_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.pages});

  final List<Widget>? pages;

  static const List<String> _placeholderTabLabels = [
    'การจอง',
    'แจ้งเตือน',
    'โปรไฟล์',
  ];

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  Future<void> _handleBookService(ServiceItem? service) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BookingFlowScreen(initialService: service),
      ),
    );
    // Step 5's "ไปยังหน้าติดตามสถานะ" button pops the flow with 'bookings'
    // so we can switch straight to the bookings tab.
    if (result == 'bookings' && mounted) {
      setState(() => _currentIndex = 1);
    }
  }

  List<Widget> _defaultPages() => [
    HomeScreen(
      onBookService: _handleBookService,
      onTrackStatus: () => setState(() => _currentIndex = 1),
    ),
    ...MainShell._placeholderTabLabels.map(
      (label) => Center(child: Text(label)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages ?? _defaultPages();

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () => _handleBookService(null),
        child: const Icon(Icons.directions_car, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.black54,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'หน้าแรก'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'การจอง'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'แจ้งเตือน',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'โปรไฟล์'),
        ],
      ),
    );
  }
}
