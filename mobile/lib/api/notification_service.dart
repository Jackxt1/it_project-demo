import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../models/notification_item.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Fetches and updates the signed-in customer's notifications via the
/// `/api/notifications` endpoints.
///
/// Like [VehicleService]/[BookingService], this always looks up
/// [ApiClient.instance] dynamically (rather than capturing a reference in
/// the constructor), so tests can swap in a mock-backed [ApiClient] via
/// `ApiClient.instance = ApiClient(httpClient: mockClient)` before using
/// [NotificationService.instance].
class NotificationService {
  NotificationService();

  /// Global singleton used throughout the app. Tests may replace this with
  /// a fresh instance once [ApiClient.instance] has been mocked.
  static NotificationService instance = NotificationService();

  /// `GET /api/notifications/me` → the signed-in user's notifications.
  Future<List<NotificationItem>> fetchMine() async {
    final data =
        await ApiClient.instance.get('/api/notifications/me') as List<dynamic>;
    return data
        .map((json) => NotificationItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// `PUT /api/notifications/{id}/read`.
  Future<void> markRead(int id) async {
    await ApiClient.instance.put('/api/notifications/$id/read');
  }

  /// `PUT /api/notifications/read-all`.
  Future<void> markAllRead() async {
    await ApiClient.instance.put('/api/notifications/read-all');
  }
}

/// Abstraction over the live-notification STOMP connection, so [MainShell]
/// (see `screens/main_shell.dart`) can depend on an injectable interface
/// instead of a concrete [StompClient] — widget tests inject a no-op fake
/// here instead of ever opening a real socket.
abstract class NotificationSocketConnector {
  /// Connects (asynchronously) and subscribes to new notifications for
  /// [userId], invoking [onNotification] for each one as it arrives.
  void connect({
    required int userId,
    required void Function(NotificationItem notification) onNotification,
    void Function()? onError,
  });

  /// Tears down the connection. Safe to call even if [connect] was never
  /// called or already failed.
  void dispose();
}

/// Real [NotificationSocketConnector] backed by `package:stomp_dart_client`,
/// subscribing to `/topic/notifications/{userId}` — the destination the
/// backend's `NotificationService.notifyUser` broadcasts to whenever an
/// admin or technician action creates a notification for the customer.
///
/// Connects to `{apiBaseUrl}/ws/websocket` (SockJS's raw-websocket escape
/// hatch) for the same reason [StompChatSocketConnector] does — see the
/// note there in `chat_service.dart`.
class StompNotificationSocketConnector implements NotificationSocketConnector {
  StompClient? _client;

  @override
  void connect({
    required int userId,
    required void Function(NotificationItem notification) onNotification,
    void Function()? onError,
  }) {
    final wsUrl =
        '${apiBaseUrl.replaceFirst(RegExp('^http'), 'ws')}/ws/websocket';
    final client = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (frame) {
          _client?.subscribe(
            destination: '/topic/notifications/$userId',
            callback: (messageFrame) {
              final body = messageFrame.body;
              if (body == null) return;
              try {
                final json = jsonDecode(body) as Map<String, dynamic>;
                onNotification(NotificationItem.fromJson(json));
              } catch (_) {
                // Malformed frame — ignore rather than crash the socket.
              }
            },
          );
        },
        onWebSocketError: (_) => onError?.call(),
        onStompError: (_) => onError?.call(),
      ),
    );
    _client = client;
    client.activate();
  }

  @override
  void dispose() {
    _client?.deactivate();
    _client = null;
  }
}
