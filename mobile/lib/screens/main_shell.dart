import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../api/notification_service.dart';
import '../models/notification_item.dart';
import '../models/product.dart';
import '../models/service_item.dart';
import '../theme/app_theme.dart';
import 'booking/booking_flow.dart';
import 'bookings/bookings_screen.dart';
import 'home/home_screen.dart';
import 'notifications/notifications_screen.dart';
import 'profile/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.pages, this.notificationSocket});

  final List<Widget>? pages;

  /// Injectable live-notification connection. Defaults to a real STOMP-backed
  /// connector at runtime; widget tests pass a no-op fake so they never open
  /// a socket. When the signed-in user's id is unknown (no session) the shell
  /// simply never connects.
  final NotificationSocketConnector? notificationSocket;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  int _unreadNotificationCount = 0;
  final GlobalKey<BookingsScreenState> _bookingsKey =
      GlobalKey<BookingsScreenState>();
  final GlobalKey<NotificationsScreenState> _notificationsKey =
      GlobalKey<NotificationsScreenState>();

  NotificationSocketConnector? _notificationSocket;

  @override
  void initState() {
    super.initState();
    _loadUnreadNotificationCount();
    _connectNotificationSocket();
  }

  @override
  void dispose() {
    _notificationSocket?.dispose();
    super.dispose();
  }

  /// Subscribes to live notifications pushed over STOMP so an admin/technician
  /// status change bumps the badge (and shows a banner) immediately, without
  /// waiting for the user to reopen the notifications tab. No-op when there's
  /// no signed-in user id to scope the subscription to.
  void _connectNotificationSocket() {
    final userId = AuthService.instance.session?.userId;
    if (userId == null) return;
    final socket =
        widget.notificationSocket ?? StompNotificationSocketConnector();
    _notificationSocket = socket;
    socket.connect(userId: userId, onNotification: _onLiveNotification);
  }

  void _onLiveNotification(NotificationItem notification) {
    if (!mounted) return;
    setState(() => _unreadNotificationCount += 1);
    // The notifications tab may already be mounted (it lives inside an
    // IndexedStack and never rebuilds on its own), so without this the new
    // item stays invisible there until the next full app restart even
    // though the toast below just announced it.
    _notificationsKey.currentState?.reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        // Floating + bottom margin keeps the toast clear of the docked FAB
        // and the bottom navigation bar instead of overlapping them.
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 96),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(notification.body),
          ],
        ),
        action: SnackBarAction(
          label: 'ดู',
          textColor: Colors.white,
          onPressed: () => _switchToTab(2),
        ),
      ),
    );
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

  /// Tapping a "บริการยอดนิยม" product card jumps straight into that
  /// product's booking flow with both the service and the product itself
  /// preselected (skips step 2's picker), same as the chatbot's "จองตัวนี้".
  Future<void> _handleBookProduct(ServiceItem service, Product product) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) =>
            BookingFlowScreen(initialService: service, initialProduct: product),
      ),
    );
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
    } else if (index == 2) {
      _notificationsKey.currentState?.reload();
    }
  }

  List<Widget> _defaultPages() => [
    HomeScreen(
      onBookService: _handleBookService,
      onBookProduct: _handleBookProduct,
      onTrackStatus: _goToBookingsTab,
    ),
    BookingsScreen(key: _bookingsKey),
    NotificationsScreen(
      key: _notificationsKey,
      onUnreadCountChanged: _onUnreadCountChanged,
    ),
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
