import 'api_client.dart';

/// `GET /api/payment/config` — the shop's PromptPay ID for building the
/// payment QR, or null when the shop hasn't configured one yet.
class PaymentService {
  PaymentService();

  static PaymentService instance = PaymentService();

  Future<String?> fetchPromptPayId() async {
    final data = await ApiClient.instance.get('/api/payment/config')
        as Map<String, dynamic>;
    return data['promptPayId'] as String?;
  }
}
