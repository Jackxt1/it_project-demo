import '../models/booking.dart';
import '../models/booking_draft.dart';
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

  /// `POST /api/bookings` body
  /// `{serviceId, productId?, vehicleId?, installArea?, bookingDate,
  ///   timeSlot, budget?, imageUrl?, paymentType?, paidAmount?}` →
  /// `BookingResponse`.
  ///
  /// `paymentType`/`paidAmount` are only sent when [BookingDraft.paidAmount]
  /// has been set (i.e. after step 4's payment choice) — the repair flow
  /// skips step 4 and calls this with `paidAmount` still null, so those two
  /// fields are simply omitted from the request per the backend contract.
  Future<Booking> createBooking(BookingDraft draft) async {
    final paidAmount = draft.paidAmount;
    final body = <String, dynamic>{
      'serviceId': draft.service!.id,
      if (draft.product != null) 'productId': draft.product!.id,
      if (draft.vehicle != null) 'vehicleId': draft.vehicle!.id,
      if (draft.installArea != null) 'installArea': draft.installArea,
      'bookingDate': _formatDate(draft.date!),
      'timeSlot': draft.timeSlot,
      if (draft.budget != null) 'budget': draft.budget,
      if (draft.imageUrl != null) 'imageUrl': draft.imageUrl,
      if (paidAmount != null) 'paymentType': draft.paymentType,
      'paidAmount': ?paidAmount,
    };
    final data = await ApiClient.instance.post('/api/bookings', body);
    return Booking.fromJson(data as Map<String, dynamic>);
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
