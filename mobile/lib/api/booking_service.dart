import '../models/slot.dart';
import 'api_client.dart';

/// Fetches slot availability and (later) creates bookings against the
/// `/api/bookings` family of endpoints.
///
/// Like [CatalogService] and `VehicleService`, this always looks up
/// [ApiClient.instance] dynamically (rather than capturing a reference in
/// the constructor), so tests can swap in a mock-backed [ApiClient] via
/// `ApiClient.instance = ApiClient(httpClient: mockClient)` before using
/// [BookingService.instance].
class BookingService {
  BookingService();

  /// Global singleton used throughout the app. Tests may replace this with
  /// a fresh instance once [ApiClient.instance] has been mocked.
  static BookingService instance = BookingService();

  /// `GET /api/services/{id}/slots?date=YYYY-MM-DD` → `{slots: [...]}`.
  Future<List<Slot>> fetchSlots(int serviceId, DateTime date) async {
    final data = await ApiClient.instance.get(
      '/api/services/$serviceId/slots?date=${_formatDate(date)}',
    );
    return SlotList.fromJson(data as Map<String, dynamic>).slots;
  }

  /// `date` as `YYYY-MM-DD`, independent of locale (the backend expects a
  /// plain ISO calendar date, not a locale-formatted string).
  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
