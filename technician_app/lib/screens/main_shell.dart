import 'dart:async';

import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../state/technician_queue_controller.dart';
import '../theme/app_theme.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  StreamSubscription<void>? _newJobSub;

  static const _tabs = [
    HomeScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final userId = AuthService.instance.session?.userId;
    if (userId != null) {
      TechnicianQueueController.instance.connectLive(userId);
    }
    _newJobSub = TechnicianQueueController.instance.onNewJobAssigned.listen((booking) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('มีงานใหม่มอบหมายให้คุณ: ${booking.userFullName} • ${booking.timeSlot}'),
          backgroundColor: AppColors.primaryDark,
        ));
    });
  }

  @override
  void dispose() {
    _newJobSub?.cancel();
    TechnicianQueueController.instance.disconnectLive();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.ink500,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? AppColors.primary : AppColors.ink500,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 2,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.calendar_today_outlined), label: 'ตารางงาน'),
            NavigationDestination(icon: Icon(Icons.history), label: 'ประวัติ'),
            NavigationDestination(icon: Icon(Icons.person_outline), label: 'โปรไฟล์'),
          ],
        ),
      ),
    );
  }
}
