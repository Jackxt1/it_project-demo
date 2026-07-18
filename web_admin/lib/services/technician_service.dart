import '../api/api_client.dart';
import '../models/technician.dart';

class TechnicianService {
  final ApiClient api;
  TechnicianService(this.api);

  Future<List<Technician>> list({bool? active}) async {
    final json = await api.get(
      '/api/admin/technicians',
      query: active == null ? null : {'active': active.toString()},
    );
    return (json as List).map((e) => Technician.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Technician> create(String fullName, String? phone) async {
    final json = await api.post('/api/admin/technicians', {'fullName': fullName, 'phone': phone});
    return Technician.fromJson(json as Map<String, dynamic>);
  }

  Future<Technician> update(int id, String fullName, String? phone) async {
    final json = await api.put('/api/admin/technicians/$id', {'fullName': fullName, 'phone': phone});
    return Technician.fromJson(json as Map<String, dynamic>);
  }

  Future<Technician> deactivate(int id) async {
    final json = await api.patch('/api/admin/technicians/$id/deactivate', {});
    return Technician.fromJson(json as Map<String, dynamic>);
  }
}
