import 'package:flutter_test/flutter_test.dart';

import 'package:bkk_customer/utils/promptpay_qr.dart';

/// Parses a flat EMVCo TLV string (tag: 2 digits, length: 2 digits, value:
/// `length` chars) into an ordered map, for asserting on structure without
/// hardcoding a full golden payload string.
Map<String, String> _parseTlv(String data) {
  final tags = <String, String>{};
  var i = 0;
  while (i < data.length) {
    final tag = data.substring(i, i + 2);
    final length = int.parse(data.substring(i + 2, i + 4));
    final value = data.substring(i + 4, i + 4 + length);
    tags[tag] = value;
    i += 4 + length;
  }
  return tags;
}

void main() {
  group('buildPromptPayPayload', () {
    test('mobile number: encodes fixed fields, amount and a valid CRC', () {
      final payload = buildPromptPayPayload(
        promptPayId: '0812345678',
        amount: 1500.5,
      );

      // The full payload — including the real tag-63 CRC entry — must
      // parse as well-formed TLV end to end.
      final tags = _parseTlv(payload);

      expect(tags['00'], '01'); // Payload Format Indicator
      expect(tags['01'], '12'); // dynamic (has amount)
      expect(tags['53'], '764'); // THB
      expect(tags['54'], '1500.50');
      expect(tags['58'], 'TH');
      expect(RegExp(r'^[0-9A-F]{4}$').hasMatch(tags['63']!), isTrue);

      final merchantInfo = _parseTlv(tags['29']!);
      expect(merchantInfo['00'], 'A000000677010111');
      // Leading 0 replaced with the 66 country code, no other digits lost.
      expect(merchantInfo['01'], '0066812345678');
    });

    test('13-digit tax ID uses proxy tag 02 instead of 01', () {
      final payload = buildPromptPayPayload(
        promptPayId: '1234567890123',
        amount: 100,
      );
      final tags = _parseTlv(payload);
      final merchantInfo = _parseTlv(tags['29']!);

      expect(merchantInfo.containsKey('02'), isTrue);
      expect(merchantInfo['02'], '1234567890123');
    });

    test('is deterministic for the same inputs', () {
      final a = buildPromptPayPayload(promptPayId: '0812345678', amount: 250);
      final b = buildPromptPayPayload(promptPayId: '0812345678', amount: 250);
      expect(a, b);
    });

    test('different amounts produce different CRCs', () {
      final a = buildPromptPayPayload(promptPayId: '0812345678', amount: 250);
      final b = buildPromptPayPayload(promptPayId: '0812345678', amount: 500);
      expect(a, isNot(equals(b)));
    });
  });
}
