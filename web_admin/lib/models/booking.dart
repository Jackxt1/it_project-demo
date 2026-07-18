class BookingSummary {
  final int id;
  final String userFullName;
  final String serviceName;
  final int? technicianId;
  final String? technicianName;
  final DateTime bookingDate;
  final String timeSlot;
  final String status;
  final double? quotePrice;

  BookingSummary({
    required this.id,
    required this.userFullName,
    required this.serviceName,
    this.technicianId,
    this.technicianName,
    required this.bookingDate,
    required this.timeSlot,
    required this.status,
    this.quotePrice,
  });

  factory BookingSummary.fromJson(Map<String, dynamic> json) => BookingSummary(
        id: json['id'] as int,
        userFullName: json['userFullName'] as String,
        serviceName: json['serviceName'] as String,
        technicianId: json['technicianId'] as int?,
        technicianName: json['technicianName'] as String?,
        bookingDate: DateTime.parse(json['bookingDate'] as String),
        timeSlot: json['timeSlot'] as String,
        status: json['status'] as String,
        quotePrice: (json['quotePrice'] as num?)?.toDouble(),
      );
}
