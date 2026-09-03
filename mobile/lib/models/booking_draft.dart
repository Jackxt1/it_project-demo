import 'product.dart';
import 'service_item.dart';
import 'vehicle.dart';

/// Mutable holder for everything collected across the 5-step booking flow.
/// Passed down to every step widget so each one can read/write its slice
/// without the flow screen needing per-field callbacks.
class BookingDraft {
  BookingDraft({this.service});

  ServiceItem? service;
  Vehicle? vehicle;
  Product? product;
  String? installArea;
  String? imageUrl;
  double? budget;
  DateTime? date;
  String? timeSlot;
  String paymentType = 'DEPOSIT';

  /// Amount chosen on step 4 (deposit or full). Left null for the repair
  /// flow (which skips step 4 entirely), so [BookingService.createBooking]
  /// knows to omit `paymentType`/`paidAmount` from the request body.
  double? paidAmount;

  /// 'CASH' (จ่ายที่ร้าน) or 'QR' (พร้อมเพย์) — chosen on step 4. Purely a
  /// client-side routing hint for [Step5Success] (show the QR/slip-upload
  /// card or not); the backend doesn't need it since `paymentType`/
  /// `paidAmount` already fully describe what's owed regardless of channel.
  String paymentChannel = 'CASH';
}

/// The three booking "modes" derived from the selected service's name —
/// mirrors the private detection already duplicated inside step2/step3, but
/// exposed here so step3 (repair short-circuit), step4/step5 (film/wash
/// payment + summary) and the booking flow's own routing all agree on it.
enum BookingMode { film, wash, repair }

BookingMode bookingModeFor(ServiceItem? service) {
  final name = service?.name ?? '';
  if (name.contains('ฟิล์ม')) return BookingMode.film;
  if (name.contains('ล้าง')) return BookingMode.wash;
  return BookingMode.repair;
}

/// Product/package price plus the service's install fee (its `basePrice`,
/// when set), used by step4's cost breakdown and step5's paid/remaining
/// summary so both agree on the same total.
double bookingTotalAmount(BookingDraft draft) {
  final productPrice = draft.product?.price ?? 0;
  final basePrice = draft.service?.basePrice ?? 0;
  return productPrice + (basePrice > 0 ? basePrice : 0);
}
