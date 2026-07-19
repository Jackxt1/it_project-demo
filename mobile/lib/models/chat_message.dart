/// Matches the backend `ChatMessageResponse` contract exactly:
/// `{id, bookingId, senderType(CUSTOMER|ADMIN|BOT), senderId?, senderName?,
///   message, createdAt, readAt?}`.
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.bookingId,
    required this.senderType,
    this.senderId,
    this.senderName,
    required this.message,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final int bookingId;

  /// `CUSTOMER`, `ADMIN`, or `BOT`.
  final String senderType;
  final int? senderId;
  final String? senderName;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;

  /// Whether this message should render on the right (customer's own
  /// messages) vs. the left (`ADMIN`/`BOT`) per the Task 9 chat spec.
  bool get isFromCustomer => senderType == 'CUSTOMER';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['id'] as num).toInt(),
        bookingId: (json['bookingId'] as num).toInt(),
        senderType: json['senderType'] as String,
        senderId: (json['senderId'] as num?)?.toInt(),
        senderName: json['senderName'] as String?,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        readAt: json['readAt'] == null
            ? null
            : DateTime.parse(json['readAt'] as String),
      );
}
