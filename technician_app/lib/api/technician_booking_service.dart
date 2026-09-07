import '../models/booking.dart';
import 'api_client.dart';

/// The only two statuses a technician is allowed to set — enforced again
/// here even though the backend also validates it, so a bad call fails
/// fast/obviously in the UI layer instead of surfacing a raw 400.
enum TechnicianStatusUpdate { inProgress, completed }

extension on TechnicianStatusUpdate {
  String get wireValue => switch (this) {
        TechnicianStatusUpdate.inProgress => 'IN_PROGRESS',
        TechnicianStatusUpdate.completed => 'COMPLETED',
      };
}

/// Talks to `/api/technician/bookings/**` — the technician-scoped queue and
/// status-update endpoints (`@PreAuthorize("hasRole('TECHNICIAN')")` on the
/// backend).
///
/// Like the customer app's `BookingService`, this always looks up
/// [ApiClient.instance] dynamically rather than capturing a reference in the
/// constructor, so tests can swap in a mock-backed [ApiClient] before using
/// [TechnicianBookingService.instance].
class TechnicianBookingService {
  TechnicianBookingService();

  static TechnicianBookingService instance = TechnicianBookingService();

  /// `GET /api/technician/bookings/me` → every booking ever assigned to the
  /// signed-in technician, all statuses, unpaginated, sorted by
  /// `bookingDate, timeSlot` ascending. The backend has no status/date
  /// filter, so screens (today's queue, history, calendar) all filter this
  /// same list client-side.
  Future<List<Booking>> fetchMyQueue() async {
    final data = await ApiClient.instance.get('/api/technician/bookings/me');
    return (data as List<dynamic>)
        .map((e) => Booking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `PUT /api/technician/bookings/{id}/status` body `{status}` →
  /// `BookingResponse`. `note` is optional context stored on the status
  /// history row shown to the customer/admin.
  Future<Booking> updateStatus(
    int bookingId,
    TechnicianStatusUpdate status, {
    String? note,
  }) async {
    final data = await ApiClient.instance.put(
      '/api/technician/bookings/$bookingId/status',
      {
        'status': status.wireValue,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return Booking.fromJson(data as Map<String, dynamic>);
  }
}
