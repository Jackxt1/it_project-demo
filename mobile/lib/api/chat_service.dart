import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../models/chat_message.dart';
import '../models/product_recommendation.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Fetches/sends booking chat messages and requests chatbot product
/// recommendations.
///
/// Like [ApiClient] and the other `*Service` singletons, this always looks
/// up [ApiClient.instance] dynamically (rather than capturing a reference in
/// the constructor), so tests can swap in a mock-backed [ApiClient] via
/// `ApiClient.instance = ApiClient(httpClient: mockClient)` before using
/// [ChatService.instance].
class ChatService {
  ChatService();

  /// Global singleton used throughout the app. Tests may replace this with
  /// a fresh instance once [ApiClient.instance] has been mocked.
  static ChatService instance = ChatService();

  /// `GET /api/chat/bookings/{bookingId}/messages` → list of
  /// `ChatMessageResponse`, oldest first (as returned by the backend).
  Future<List<ChatMessage>> fetchHistory(int bookingId) async {
    final data = await ApiClient.instance.get(
      '/api/chat/bookings/$bookingId/messages',
    ) as List<dynamic>;
    return data
        .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// `POST /api/chat/bookings/{bookingId}/messages` body `{message}` →
  /// `ChatMessageResponse`.
  Future<ChatMessage> sendMessage(int bookingId, String message) async {
    final data = await ApiClient.instance.post(
      '/api/chat/bookings/$bookingId/messages',
      {'message': message},
    );
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  /// `PUT /api/chat/bookings/{bookingId}/read`.
  Future<void> markRead(int bookingId) async {
    await ApiClient.instance.put('/api/chat/bookings/$bookingId/read');
  }

  /// `POST /api/chatbot/recommend` body `{serviceId, budget, message?}` →
  /// `{recommendations: [...], source}`.
  Future<ChatbotRecommendResult> recommend({
    required int serviceId,
    required double budget,
    String? message,
  }) async {
    final body = <String, dynamic>{
      'serviceId': serviceId,
      'budget': budget,
      'message': ?message,
    };
    final data = await ApiClient.instance.post('/api/chatbot/recommend', body);
    return ChatbotRecommendResult.fromJson(data as Map<String, dynamic>);
  }
}

/// Abstraction over the live-chat STOMP connection, so [BookingChatScreen]
/// (see `screens/chat/booking_chat_screen.dart`) can depend on an injectable
/// interface instead of a concrete [StompClient] — widget tests inject a
/// no-op fake here instead of ever opening a real socket.
abstract class ChatSocketConnector {
  /// Connects (asynchronously) and subscribes to new messages for
  /// [bookingId], invoking [onMessage] for each one as it arrives.
  ///
  /// [onError] is invoked (possibly more than once, e.g. on every failed
  /// reconnect attempt) whenever the underlying WebSocket/STOMP connection
  /// fails — callers use this as the signal to fall back to polling.
  void connect({
    required int bookingId,
    required void Function(ChatMessage message) onMessage,
    void Function()? onError,
  });

  /// Tears down the connection. Safe to call even if [connect] was never
  /// called or already failed.
  void dispose();
}

/// Real [ChatSocketConnector] backed by `package:stomp_dart_client`,
/// subscribing to the `/topic/chat/{bookingId}` destination that
/// `ChatService.send` (backend) broadcasts to (see
/// `backend/.../service/ChatService.java`).
///
/// The backend's STOMP endpoint (`WebSocketConfig`) is registered at `/ws`
/// with SockJS enabled (`.withSockJS()`). `stomp_dart_client` speaks raw
/// STOMP-over-WebSocket rather than the SockJS framing protocol, so instead
/// of pointing it at `{apiBaseUrl}/ws` (which would require a SockJS
/// handshake this package doesn't implement), this connects directly to
/// SockJS's raw-websocket transport endpoint `{apiBaseUrl}/ws/websocket`
/// (a standard SockJS server escape hatch that speaks the underlying
/// protocol — STOMP frames here — without any SockJS envelope). This is a
/// deliberate deviation from the brief's literal `{apiBaseUrl}/ws` URL,
/// documented in the Task 9 report.
class StompChatSocketConnector implements ChatSocketConnector {
  StompClient? _client;

  @override
  void connect({
    required int bookingId,
    required void Function(ChatMessage message) onMessage,
    void Function()? onError,
  }) {
    final wsUrl = '${apiBaseUrl.replaceFirst(RegExp('^http'), 'ws')}/ws/websocket';
    final client = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (frame) {
          _client?.subscribe(
            destination: '/topic/chat/$bookingId',
            callback: (messageFrame) {
              final body = messageFrame.body;
              if (body == null) return;
              try {
                final json = jsonDecode(body) as Map<String, dynamic>;
                onMessage(ChatMessage.fromJson(json));
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
