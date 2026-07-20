import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/catalog_service.dart';
import '../../api/review_service.dart';
import '../../models/review.dart';
import '../../models/service_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/star_rating.dart';

/// Customer-facing "รีวิว" screen reached from the Home quick action. Lists
/// every service with its average rating and the individual customer reviews
/// (backend `GET /api/reviews/service/{id}`). Reviews are created from a
/// completed booking's detail screen, not here.
class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  bool _loading = true;
  String? _error;
  List<ServiceItem> _services = [];
  Map<int, ServiceReviews> _reviewsByService = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final services = await CatalogService.instance.fetchServices();
      final reviews = await Future.wait(
        services.map((s) => ReviewService.instance.fetchByService(s.id)),
      );
      if (!mounted) return;
      setState(() {
        _services = services;
        _reviewsByService = {for (final r in reviews) r.serviceId: r};
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดรีวิวไม่สำเร็จ';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รีวิวจากลูกค้า')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _services.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final service = _services[index];
          return _ServiceReviewsCard(
            serviceName: service.name,
            reviews: _reviewsByService[service.id],
          );
        },
      ),
    );
  }
}

class _ServiceReviewsCard extends StatelessWidget {
  const _ServiceReviewsCard({required this.serviceName, required this.reviews});

  final String serviceName;
  final ServiceReviews? reviews;

  @override
  Widget build(BuildContext context) {
    final data = reviews;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            serviceName,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (data == null || data.totalReviews == 0)
            const Text(
              'ยังไม่มีรีวิว',
              style: TextStyle(color: Colors.black54),
            )
          else ...[
            Row(
              children: [
                StarRatingDisplay(rating: data.averageRating, size: 20),
                const SizedBox(width: 8),
                Text(
                  data.averageRating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${data.totalReviews} รีวิว)',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...data.reviews.map((r) => _ReviewTile(review: r)),
          ],
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final ReviewItem review;

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMM yyyy').format(review.createdAt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceLight,
                child: Icon(Icons.person, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  review.userFullName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              StarRatingDisplay(rating: review.rating.toDouble(), size: 14),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(review.comment!),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 2),
            child: Text(
              dateLabel,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }
}
