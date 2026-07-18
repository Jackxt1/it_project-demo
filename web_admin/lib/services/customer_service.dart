import '../api/api_client.dart';
import '../models/customer.dart';

class CustomerService {
  final ApiClient api;
  CustomerService(this.api);

  Future<CustomerPage> list({String? search, int page = 0, int size = 20}) async {
    final json = await api.get('/api/admin/customers', query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'page': page.toString(),
      'size': size.toString(),
    });
    return CustomerPage.fromJson(json as Map<String, dynamic>);
  }

  Future<CustomerDetail> detail(int id) async {
    final json = await api.get('/api/admin/customers/$id');
    return CustomerDetail.fromJson(json as Map<String, dynamic>);
  }
}
