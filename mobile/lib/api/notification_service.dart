import '../models/notification_item.dart';
import 'api_client.dart';

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
