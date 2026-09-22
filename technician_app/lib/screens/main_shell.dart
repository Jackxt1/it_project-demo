import 'dart:async';

import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../state/technician_queue_controller.dart';
import '../theme/app_theme.dart';
import 'history/history_screen.dart';
import 'home/home_screen.dart';
import 'notifications/notifications_screen.dart';
import 'profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  StreamSubscription<void>? _newNotificationSub;

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
      TechnicianQueueController.instance.connectNotificationsLive(userId);
    }
    TechnicianQueueController.instance.loadUnreadNotificationCount();
    // Assigning a job now pushes on *both* onNewJobAssigned (job-queue
    // topic — HomeScreen listens to this itself for the card glow) and
    // onNewNotification (notifications topic, below) for the same real
    // event. Showing a toast from each stacked/flickered one over the
    // other, so this is the only SnackBar here now — one toast per event.
    _newNotificationSub = TechnicianQueueController.instance.onNewNotification.listen((notification) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 6),
          backgroundColor: AppColors.primary,
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(notification.body),
                  ],
                ),
              ),
              InkWell(
                onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                child: const Padding(
                  padding: EdgeInsets.only(left: 8, top: 2),
                  child: Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'ดู',
            textColor: Colors.white,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ));
    });
  }

  @override
  void dispose() {
    _newNotificationSub?.cancel();
    TechnicianQueueController.instance.disconnectLive();
    TechnicianQueueController.instance.disconnectNotificationsLive();
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
