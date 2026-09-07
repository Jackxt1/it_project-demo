import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../models/booking.dart';
import 'api_config.dart';

/// Abstraction over the live-queue STOMP connection, so
/// [TechnicianQueueController] can depend on an injectable interface instead
/// of a concrete [StompClient] — tests inject a no-op fake here instead of
/// ever opening a real socket.
abstract class TechnicianQueueSocketConnector {
  /// Connects (asynchronously) and subscribes to job assignments for
  /// [technicianUserId], invoking [onBookingAssigned] with the full booking
  /// every time the backend assigns (or reassigns) a job to this technician.
  ///
  /// [onError] is invoked (possibly more than once, e.g. on every failed
  /// reconnect attempt) whenever the underlying WebSocket/STOMP connection
  /// fails — callers use this as the signal to fall back to manual refresh.
  void connect({
    required int technicianUserId,
    required void Function(Booking booking) onBookingAssigned,
    void Function()? onError,
  });

  /// Tears down the connection. Safe to call even if [connect] was never
  /// called or already failed.
  void dispose();
}

/// Real [TechnicianQueueSocketConnector] backed by `package:stomp_dart_client`,
/// subscribing to `/topic/technician/{userId}/queue` — the destination
/// `BookingService.assignTechnician` (backend) broadcasts the full
/// `BookingResponse` to whenever an admin/owner assigns a job to this
/// technician. This is what makes a newly-assigned job show up on the home
/// screen immediately instead of only after the next manual refresh.
///
/// Note this topic only fires on assignment, not on every later status
/// change an admin makes directly (e.g. cancelling an already-assigned job)
/// — those don't currently push to the technician. The common case this
/// closes is exactly the one that prompted it: customer books -> admin
/// assigns a technician -> the assigned technician sees it without having
/// to reopen the app.
///
/// Connects to `{apiBaseUrl}/ws/websocket` (SockJS's raw-websocket escape
/// hatch) for the same reason the customer app's chat/notification
/// connectors do — see the note in `mobile/lib/api/chat_service.dart`.
class StompTechnicianQueueSocketConnector implements TechnicianQueueSocketConnector {
  StompClient? _client;

  @override
  void connect({
    required int technicianUserId,
    required void Function(Booking booking) onBookingAssigned,
    void Function()? onError,
  }) {
    final wsUrl = '${apiBaseUrl.replaceFirst(RegExp('^http'), 'ws')}/ws/websocket';
    final client = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (frame) {
          _client?.subscribe(
            destination: '/topic/technician/$technicianUserId/queue',
            callback: (messageFrame) {
              final body = messageFrame.body;
              if (body == null) return;
              try {
                final json = jsonDecode(body) as Map<String, dynamic>;
                onBookingAssigned(Booking.fromJson(json));
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
