import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../models/notification_item.dart';
import 'api_config.dart';

/// Abstraction over the live-notification STOMP connection, so
/// [TechnicianQueueController] can depend on an injectable interface instead
/// of a concrete [StompClient] — tests inject a no-op fake here instead of
/// ever opening a real socket. Mirrors [TechnicianQueueSocketConnector]
/// (`technician_queue_socket.dart`) and the customer app's
/// `StompNotificationSocketConnector` (`mobile/lib/api/notification_service.dart`).
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
/// subscribing to `/topic/notifications/{userId}` — the destination
/// `NotificationService.notifyUser` (backend) broadcasts to whenever a new
/// notification is created for this user, including the `JOB_ASSIGNED`
/// notification `BookingService.assignTechnician` now sends when an
/// admin/owner assigns a job to this technician.
class StompNotificationSocketConnector implements NotificationSocketConnector {
  StompClient? _client;

  @override
  void connect({
    required int userId,
    required void Function(NotificationItem notification) onNotification,
    void Function()? onError,
  }) {
    final wsUrl = '${apiBaseUrl.replaceFirst(RegExp('^http'), 'ws')}/ws/websocket';
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
