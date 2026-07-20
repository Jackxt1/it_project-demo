/// One review, matching the backend `ReviewResponse`
/// `{id, bookingId, userId, userFullName, rating, comment, createdAt}`.
class ReviewItem {
  ReviewItem({
    required this.id,
    required this.userFullName,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  final int id;
  final String userFullName;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  factory ReviewItem.fromJson(Map<String, dynamic> json) => ReviewItem(
        id: (json['id'] as num).toInt(),
        userFullName: json['userFullName'] as String? ?? 'ลูกค้า',
        rating: (json['rating'] as num).toInt(),
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Aggregate reviews for one service, matching the backend
/// `ServiceReviewsResponse` `{serviceId, averageRating, totalReviews, reviews}`.
class ServiceReviews {
  ServiceReviews({
    required this.serviceId,
    required this.averageRating,
    required this.totalReviews,
    required this.reviews,
  });

  final int serviceId;
  final double averageRating;
  final int totalReviews;
  final List<ReviewItem> reviews;

  factory ServiceReviews.fromJson(Map<String, dynamic> json) => ServiceReviews(
        serviceId: (json['serviceId'] as num).toInt(),
        averageRating: (json['averageRating'] as num).toDouble(),
        totalReviews: (json['totalReviews'] as num).toInt(),
        reviews: (json['reviews'] as List<dynamic>? ?? [])
            .map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
