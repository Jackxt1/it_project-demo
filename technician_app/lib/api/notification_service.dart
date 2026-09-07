import '../models/notification_item.dart';
import 'api_client.dart';

/// Fetches and updates the signed-in technician's notifications via the
/// `/api/notifications` endpoints. These are role-agnostic on the backend
/// (filtered purely by the authenticated user id), so this is the exact
/// same contract the customer app's `NotificationService` uses.
///
/// This app polls on demand (pull-to-refresh / screen open) rather than
/// holding a live STOMP subscription open — the mockup's badge/list UI
/// doesn't need push-latency updates, and it keeps the technician app's
/// dependency footprint smaller.
class NotificationService {
  NotificationService();

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
