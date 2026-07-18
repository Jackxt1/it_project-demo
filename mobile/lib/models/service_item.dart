/// Matches `GET /api/services` →
/// `[{id, name, description, basePrice, maxPerSlot, createdAt, updatedAt}]`.
class ServiceItem {
  ServiceItem({
    required this.id,
    required this.name,
    this.description,
    required this.basePrice,
    required this.maxPerSlot,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String name;
  final String? description;
  final double basePrice;
  final int maxPerSlot;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ServiceItem.fromJson(Map<String, dynamic> json) => ServiceItem(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        description: json['description'] as String?,
        basePrice: (json['basePrice'] as num).toDouble(),
        maxPerSlot: (json['maxPerSlot'] as num).toInt(),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );
}
