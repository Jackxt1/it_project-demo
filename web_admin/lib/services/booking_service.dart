import '../api/api_client.dart';
import '../models/booking.dart';

class BookingService {
  final ApiClient api;
  BookingService(this.api);

  Future<List<BookingSummary>> list() async {
    final json = await api.get('/api/bookings');
    return (json as List).map((e) => BookingSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<BookingSummary> assignTechnician(int bookingId, int technicianId) async {
    final json = await api.patch('/api/bookings/$bookingId/technician', {'technicianId': technicianId});
    return BookingSummary.fromJson(json as Map<String, dynamic>);
  }

  Future<BookingSummary> updateStatus(int bookingId, String status) async {
    final json = await api.put('/api/bookings/$bookingId/status', {'status': status});
    return BookingSummary.fromJson(json as Map<String, dynamic>);
  }
}
