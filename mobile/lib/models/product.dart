/// Matches `GET /api/products?serviceId=` →
/// `[{id, serviceId, serviceName, name, brand, grade, heatRejectionPct,
///    uvRejectionPct, vltPct, price, description, imageUrl, active, ...}]`.
class Product {
  Product({
    required this.id,
    required this.serviceId,
    this.serviceName,
    required this.name,
    this.brand,
    this.grade,
    this.heatRejectionPct,
    this.uvRejectionPct,
    this.vltPct,
    required this.price,
    this.description,
    this.imageUrl,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int serviceId;
  final String? serviceName;
  final String name;
  final String? brand;
  final String? grade;
  final int? heatRejectionPct;
  final int? uvRejectionPct;
  final int? vltPct;
  final double price;
  final String? description;
  final String? imageUrl;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: (json['id'] as num).toInt(),
        serviceId: (json['serviceId'] as num).toInt(),
        serviceName: json['serviceName'] as String?,
        name: json['name'] as String,
        brand: json['brand'] as String?,
        grade: json['grade'] as String?,
        heatRejectionPct: (json['heatRejectionPct'] as num?)?.toInt(),
        uvRejectionPct: (json['uvRejectionPct'] as num?)?.toInt(),
        vltPct: (json['vltPct'] as num?)?.toInt(),
        price: (json['price'] as num).toDouble(),
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        active: json['active'] as bool? ?? true,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );
}
