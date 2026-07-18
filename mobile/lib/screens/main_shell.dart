import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.pages});

  final List<Widget>? pages;

  static const List<String> _tabLabels = [
    'หน้าแรก',
    'การจอง',
    'แจ้งเตือน',
    'โปรไฟล์',
  ];

  static List<Widget> get defaultPages => _tabLabels
      .map((label) => Center(child: Text(label)))
      .toList(growable: false);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages ?? MainShell.defaultPages;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        onPressed: () {
          // TODO(Task 4): navigate to booking flow
        },
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
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'หน้าแรก',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'การจอง',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'แจ้งเตือน',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
