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
import 'reviews/reviews_screen.dart';

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
          onPressed: _openNotifications,
        ),
      ),
    );
  }

  /// Pushes the แจ้งเตือน screen — it's reached from the bell icon on the
  /// home screen (and this SnackBar's "ดู" action) rather than living as a
  /// bottom-nav tab.
  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NotificationsScreen(onUnreadCountChanged: _onUnreadCountChanged),
      ),
    );
  }

  /// Best-effort initial fetch just to seed the bell badge; the count then
  /// stays in sync via [_onUnreadCountChanged], which [NotificationsScreen]
  /// calls after every load/mark-read/mark-all-read.
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
    }
  }

  List<Widget> _defaultPages() => [
    HomeScreen(
      onBookService: _handleBookService,
      onBookProduct: _handleBookProduct,
      onTrackStatus: _goToBookingsTab,
      onOpenNotifications: _openNotifications,
      unreadNotificationCount: _unreadNotificationCount,
    ),
    BookingsScreen(key: _bookingsKey),
    const ReviewsScreen(),
    ProfileScreen(onViewBookingHistory: _goToBookingsTab),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = widget.pages ?? _defaultPages();

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _PillNavBar(currentIndex: _currentIndex, onTap: _switchToTab),
    );
  }
}

class _PillNavItem {
  const _PillNavItem({
    required this.filledIcon,
    required this.outlinedIcon,
    required this.label,
  });
  final IconData filledIcon;
  final IconData outlinedIcon;
  final String label;
}

const List<_PillNavItem> _navItems = [
  _PillNavItem(filledIcon: Icons.home, outlinedIcon: Icons.home_outlined, label: 'หน้าแรก'),
  _PillNavItem(
    filledIcon: Icons.calendar_month,
    outlinedIcon: Icons.calendar_month_outlined,
    label: 'การจอง',
  ),
  _PillNavItem(filledIcon: Icons.star, outlinedIcon: Icons.star_border, label: 'รีวิว'),
  _PillNavItem(filledIcon: Icons.person, outlinedIcon: Icons.person_outline, label: 'โปรไฟล์'),
];

/// Floating white bar where the selected tab's icon bulges up out of the
/// bar in a red circle, with its label sitting underneath — matching the
/// reference design the user shared (adapted from its dark bar to white,
/// per the user's confirmed choice).
class _PillNavBar extends StatelessWidget {
  const _PillNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double _barHeight = 72;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: _barHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final item = _navItems[i];
              final selected = i == currentIndex;
              final displayIcon = selected ? item.filledIcon : item.outlinedIcon;
              final iconColor = selected ? Colors.white : Colors.grey.shade500;
              final iconWidget = Icon(displayIcon, size: 20, color: iconColor);
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: iconWidget),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: selected ? AppColors.primary : Colors.grey.shade500,
                            fontSize: 10,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
