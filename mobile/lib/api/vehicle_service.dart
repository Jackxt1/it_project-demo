import '../models/vehicle.dart';
import 'api_client.dart';

/// Manages the signed-in customer's saved vehicles via the `/api/vehicles`
/// endpoints.
///
/// Like [CatalogService], this always looks up [ApiClient.instance]
/// dynamically (rather than capturing a reference in the constructor), so
/// tests can swap in a mock-backed [ApiClient] via
/// `ApiClient.instance = ApiClient(httpClient: mockClient)` before using
/// [VehicleService.instance].
class VehicleService {
  VehicleService();

  /// Global singleton used throughout the app. Tests may replace this with
  /// a fresh instance once [ApiClient.instance] has been mocked.
  static VehicleService instance = VehicleService();

  /// `GET /api/vehicles/me` → the signed-in user's saved vehicles.
  Future<List<Vehicle>> fetchMine() async {
    final data =
        await ApiClient.instance.get('/api/vehicles/me') as List<dynamic>;
    return data
        .map((json) => Vehicle.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// `POST /api/vehicles` → creates a new vehicle and returns it (with the
  /// server-assigned `id`).
  Future<Vehicle> create(Vehicle vehicle) async {
    final data = await ApiClient.instance.post(
      '/api/vehicles',
      vehicle.toJson(),
    );
    return Vehicle.fromJson(data as Map<String, dynamic>);
  }

  /// `PUT /api/vehicles/{id}` → updates an existing vehicle. [vehicle.id]
  /// must already be set.
  Future<Vehicle> update(Vehicle vehicle) async {
    final id = vehicle.id;
    assert(id != null, 'Vehicle.id must be set to update an existing vehicle');
    final data = await ApiClient.instance.put(
      '/api/vehicles/$id',
      vehicle.toJson(),
    );
    return Vehicle.fromJson(data as Map<String, dynamic>);
  }

  /// `DELETE /api/vehicles/{id}`.
  Future<void> delete(int id) async {
    await ApiClient.instance.delete('/api/vehicles/$id');
  }
}
