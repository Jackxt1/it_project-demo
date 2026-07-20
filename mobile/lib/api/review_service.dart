import '../models/review.dart';
import 'api_client.dart';

/// Reads service reviews and submits new ones via the `/api/reviews`
/// endpoints.
///
/// Like the other `*Service` singletons, this always looks up
/// [ApiClient.instance] dynamically so tests can swap in a mock-backed
/// [ApiClient] before using [ReviewService.instance].
class ReviewService {
  ReviewService();

  static ReviewService instance = ReviewService();

  /// `GET /api/reviews/service/{serviceId}` → aggregate rating + review list.
  Future<ServiceReviews> fetchByService(int serviceId) async {
    final data = await ApiClient.instance.get('/api/reviews/service/$serviceId');
    return ServiceReviews.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /api/reviews` body `{bookingId, rating, comment?}`. Only allowed
  /// once per COMPLETED booking the caller owns (enforced by the backend).
  Future<void> create({
    required int bookingId,
    required int rating,
    String? comment,
  }) async {
    await ApiClient.instance.post('/api/reviews', {
      'bookingId': bookingId,
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
  }
}
