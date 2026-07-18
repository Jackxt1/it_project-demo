import 'booking.dart';

class Customer {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as int,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class CustomerDetail extends Customer {
  final List<BookingSummary> bookings;

  CustomerDetail({
    required super.id,
    required super.fullName,
    required super.email,
    super.phone,
    required super.createdAt,
    required this.bookings,
  });

  factory CustomerDetail.fromJson(Map<String, dynamic> json) => CustomerDetail(
        id: json['id'] as int,
        fullName: json['fullName'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        bookings: (json['bookings'] as List)
            .map((e) => BookingSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CustomerPage {
  final List<Customer> content;
  final int totalPages;
  final int totalElements;
  final int number; // current page, 0-based

  CustomerPage({
    required this.content,
    required this.totalPages,
    required this.totalElements,
    required this.number,
  });

  factory CustomerPage.fromJson(Map<String, dynamic> json) => CustomerPage(
        content: (json['content'] as List)
            .map((e) => Customer.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalPages: json['totalPages'] as int,
        totalElements: json['totalElements'] as int,
        number: json['number'] as int,
      );
}
