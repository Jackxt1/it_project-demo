import '../models/product.dart';
import '../models/service_item.dart';
import 'api_client.dart';

/// Fetches the service/product catalog from the backend.
///
/// Like [ApiClient] and `AuthService`, this always looks up
/// [ApiClient.instance] dynamically (rather than capturing a reference in
/// the constructor), so tests can swap in a mock-backed [ApiClient] via
/// `ApiClient.instance = ApiClient(httpClient: mockClient)` before using
/// [CatalogService.instance].
class CatalogService {
  CatalogService();

  /// Global singleton used throughout the app. Tests may replace this with
  /// a fresh instance once [ApiClient.instance] has been mocked.
  static CatalogService instance = CatalogService();

  /// `GET /api/services` → `[{id, name, description, basePrice, maxPerSlot,
  /// createdAt, updatedAt}]`.
  Future<List<ServiceItem>> fetchServices() async {
    final data = await ApiClient.instance.get('/api/services') as List<dynamic>;
    return data
        .map((json) => ServiceItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// `GET /api/products?serviceId=` → list of products, optionally filtered
  /// by [serviceId].
  Future<List<Product>> fetchProducts({int? serviceId}) async {
    final path = serviceId != null
        ? '/api/products?serviceId=$serviceId'
        : '/api/products';
    final data = await ApiClient.instance.get(path) as List<dynamic>;
    return data
        .map((json) => Product.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
