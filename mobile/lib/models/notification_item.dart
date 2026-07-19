/// Matches `GET /api/notifications/me` →
/// `[{id, title, body, type, bookingId?, createdAt, readAt?}]`.
class NotificationItem {
  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.bookingId,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final String title;
  final String body;
  final String type;
  final int? bookingId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String,
        body: json['body'] as String,
        type: json['type'] as String,
        bookingId: (json['bookingId'] as num?)?.toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        readAt: json['readAt'] == null
            ? null
            : DateTime.parse(json['readAt'] as String),
      );
}
