import 'package:flutter/material.dart';

import '../api/notification_service.dart';
import '../models/service_item.dart';
import '../theme/app_theme.dart';
import 'booking/booking_flow.dart';
import 'bookings/bookings_screen.dart';
import 'home/home_screen.dart';
import 'notifications/notifications_screen.dart';
import 'profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.pages});

  final List<Widget>? pages;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _unreadNotificationCount = 0;
  final GlobalKey<BookingsScreenState> _bookingsKey =
      GlobalKey<BookingsScreenState>();

  @override
  void initState() {
    super.initState();
    _loadUnreadNotificationCount();
  }

  /// Best-effort initial fetch just to seed the bottom-nav badge; the count
  /// then stays in sync via [_onUnreadCountChanged], which
  /// [NotificationsScreen] calls after every load/mark-read/mark-all-read.
  Future<void> _loadUnreadNotificationCount() async {
    try {
      final items = await NotificationService.instance.fetchMine();
      if (!mounted) return;
      setState(
        () => _unreadNotificationCount = items.where((n) => !n.isRead).length,
      );
    } catch (_) {
      // A failed badge fetch isn't worth surfacing an error for.
    }
  }

  void _onUnreadCountChanged(int count) {
    if (!mounted) return;
    setState(() => _unreadNotificationCount = count);
  }

  Future<void> _handleBookService(ServiceItem? service) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BookingFlowScreen(initialService: service),
      ),
    );
    // Step 5's "ไปยังหน้าติดตามสถานะ" button pops the flow with 'bookings'
    // so we can switch straight to the bookings tab.
    if (result == 'bookings' && mounted) {
      _switchToTab(1);
    }
  }

  void _goToBookingsTab() => _switchToTab(1);

  /// Switches the visible tab and, when landing on the bookings tab,
  /// refreshes its list. [BookingsScreen] lives inside an [IndexedStack] so
  /// switching tabs alone doesn't re-run [initState]'s one-time fetch — a
  /// booking created or updated elsewhere (e.g. the booking flow, or a
  /// status change viewed in the detail screen) would otherwise stay stale
  /// until a manual pull-to-refresh. Only called from explicit tab-switch
  /// entry points (bottom-nav tap, booking-flow completion, "track status"
  /// shortcuts) — never from build() — so this doesn't reload on every
  /// rebuild.
  void _switchToTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 1) {
      _bookingsKey.currentState?.reload();
    }
  }

  List<Widget> _defaultPages() => [
    HomeScreen(
      onBookService: _handleBookService,
      onTrackStatus: _goToBookingsTab,
    ),
    BookingsScreen(key: _bookingsKey),
    NotificationsScreen(onUnreadCountChanged: _onUnreadCountChanged),
    ProfileScreen(onViewBookingHistory: _goToBookingsTab),
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
        onTap: _switchToTab,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.black54,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'หน้าแรก',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'การจอง',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text('$_unreadNotificationCount'),
              isLabelVisible: _unreadNotificationCount > 0,
              child: const Icon(Icons.notifications),
            ),
            label: 'แจ้งเตือน',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'โปรไฟล์',
          ),
        ],
      ),
    );
  }
}
