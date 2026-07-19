/// One row of a booking's status history, matching
/// `{id, status, note, changedByName, changedAt}`.
class BookingStatusHistoryEntry {
  BookingStatusHistoryEntry({
    required this.id,
    required this.status,
    this.note,
    this.changedByName,
    required this.changedAt,
  });

  final int id;
  final String status;
  final String? note;
  final String? changedByName;
  final DateTime changedAt;

  factory BookingStatusHistoryEntry.fromJson(Map<String, dynamic> json) =>
      BookingStatusHistoryEntry(
        id: (json['id'] as num).toInt(),
        status: json['status'] as String,
        note: json['note'] as String?,
        changedByName: json['changedByName'] as String?,
        changedAt: DateTime.parse(json['changedAt'] as String),
      );
}

const Map<String, String> _bookingStatusLabels = {
  'PENDING': 'รอดำเนินการ',
  'CONFIRMED': 'ยืนยันแล้ว',
  'IN_PROGRESS': 'กำลังดำเนินการ',
  'COMPLETED': 'เสร็จสิ้น',
  'CANCELLED': 'ยกเลิก',
};

/// Thai label for a raw booking status code (`PENDING`, `CONFIRMED`, ...).
/// Shared by [Booking.statusLabel] and by callers rendering
/// [BookingStatusHistoryEntry.status], which carries the same status codes.
String bookingStatusLabel(String status) =>
    _bookingStatusLabels[status] ?? status;

/// Matches the backend `BookingResponse` contract exactly.
class Booking {
  Booking({
    required this.id,
    required this.orderCode,
    required this.userId,
    required this.userFullName,
    required this.serviceId,
    required this.serviceName,
    this.productId,
    this.productName,
    this.technicianId,
    this.technicianName,
    this.vehicleId,
    this.vehicleBrandModel,
    this.vehicleLicensePlate,
    this.installArea,
    this.paymentType,
    required this.paidAmount,
    required this.bookingDate,
    required this.timeSlot,
    required this.status,
    this.budget,
    this.imageUrl,
    this.quotePrice,
    this.notes,
    required this.statusHistory,
  });

  final int id;
  final String orderCode;
  final int userId;
  final String userFullName;
  final int serviceId;
  final String serviceName;
  final int? productId;
  final String? productName;
  final int? technicianId;
  final String? technicianName;
  final int? vehicleId;
  final String? vehicleBrandModel;
  final String? vehicleLicensePlate;
  final String? installArea;
  final String? paymentType;
  final double paidAmount;
  final DateTime bookingDate;
  final String timeSlot;
  final String status;
  final double? budget;
  final String? imageUrl;
  final double? quotePrice;
  final String? notes;
  final List<BookingStatusHistoryEntry> statusHistory;

  String get statusLabel => bookingStatusLabel(status);

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
        id: (json['id'] as num).toInt(),
        orderCode: json['orderCode'] as String,
        userId: (json['userId'] as num).toInt(),
        userFullName: json['userFullName'] as String,
        serviceId: (json['serviceId'] as num).toInt(),
        serviceName: json['serviceName'] as String,
        productId: (json['productId'] as num?)?.toInt(),
        productName: json['productName'] as String?,
        technicianId: (json['technicianId'] as num?)?.toInt(),
        technicianName: json['technicianName'] as String?,
        vehicleId: (json['vehicleId'] as num?)?.toInt(),
        vehicleBrandModel: json['vehicleBrandModel'] as String?,
        vehicleLicensePlate: json['vehicleLicensePlate'] as String?,
        installArea: json['installArea'] as String?,
        paymentType: json['paymentType'] as String?,
        paidAmount: (json['paidAmount'] as num).toDouble(),
        bookingDate: DateTime.parse(json['bookingDate'] as String),
        timeSlot: json['timeSlot'] as String,
        status: json['status'] as String,
        budget: (json['budget'] as num?)?.toDouble(),
        imageUrl: json['imageUrl'] as String?,
        quotePrice: (json['quotePrice'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        statusHistory: (json['statusHistory'] as List<dynamic>? ?? [])
            .map((e) =>
                BookingStatusHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
