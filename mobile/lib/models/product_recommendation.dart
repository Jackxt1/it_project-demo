/// One recommended product from `POST /api/chatbot/recommend`, matching the
/// backend `ProductRecommendation` DTO exactly:
/// `{productId, name, brand?, grade?, heatRejectionPct?, uvRejectionPct?,
///   vltPct?, price, reason?}`.
class ProductRecommendation {
  ProductRecommendation({
    required this.productId,
    required this.name,
    this.brand,
    this.grade,
    this.heatRejectionPct,
    this.uvRejectionPct,
    this.vltPct,
    required this.price,
    this.reason,
  });

  final int productId;
  final String name;
  final String? brand;
  final String? grade;
  final int? heatRejectionPct;
  final int? uvRejectionPct;
  final int? vltPct;
  final double price;
  final String? reason;

  factory ProductRecommendation.fromJson(Map<String, dynamic> json) =>
      ProductRecommendation(
        productId: (json['productId'] as num).toInt(),
        name: json['name'] as String,
        brand: json['brand'] as String?,
        grade: json['grade'] as String?,
        heatRejectionPct: (json['heatRejectionPct'] as num?)?.toInt(),
        uvRejectionPct: (json['uvRejectionPct'] as num?)?.toInt(),
        vltPct: (json['vltPct'] as num?)?.toInt(),
        price: (json['price'] as num).toDouble(),
        reason: json['reason'] as String?,
      );
}

/// The full `POST /api/chatbot/recommend` response body:
/// `{recommendations: [ProductRecommendation], source}`.
class ChatbotRecommendResult {
  ChatbotRecommendResult({required this.recommendations, required this.source});

  final List<ProductRecommendation> recommendations;
  final String source;

  factory ChatbotRecommendResult.fromJson(Map<String, dynamic> json) =>
      ChatbotRecommendResult(
        recommendations: (json['recommendations'] as List<dynamic>? ?? [])
            .map((e) =>
                ProductRecommendation.fromJson(e as Map<String, dynamic>))
            .toList(),
        source: json['source'] as String? ?? '',
      );
}
