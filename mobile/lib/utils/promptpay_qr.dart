/// Builds a Thai PromptPay QR payload (the EMVCo-based "Thai QR Payment"
/// standard) for [promptPayId] — a 10-digit mobile number or 13-digit
/// national/tax ID — and a fixed [amount] in baht, so the customer's
/// banking app pre-fills the transfer amount when it scans the code.
///
/// Pure, deterministic string-building — no network call, no external
/// package beyond what's needed to render the resulting string as a QR
/// image (`qr_flutter`, used where this is called).
String buildPromptPayPayload({required String promptPayId, required double amount}) {
  final digits = promptPayId.replaceAll(RegExp(r'[^0-9]'), '');
  // A mobile number is 10 digits (0812345678); anything longer is treated
  // as a 13-digit national ID / juristic tax ID.
  final isMobileNumber = digits.length <= 10;
  final proxyTag = isMobileNumber ? '01' : '02';
  final proxyValue = isMobileNumber
      ? '0066${digits.replaceFirst(RegExp(r'^0'), '')}'
      : digits.padLeft(13, '0');

  final merchantAccountInfo =
      _tlv('00', 'A000000677010111') + _tlv(proxyTag, proxyValue);

  final payload = StringBuffer()
    ..write(_tlv('00', '01')) // Payload Format Indicator
    ..write(_tlv('01', '12')) // Point of Initiation Method: dynamic (has amount)
    ..write(_tlv('29', merchantAccountInfo)) // Merchant Account Info - PromptPay
    ..write(_tlv('53', '764')) // Transaction Currency: THB
    ..write(_tlv('54', amount.toStringAsFixed(2))) // Transaction Amount
    ..write(_tlv('58', 'TH')); // Country Code

  // CRC (tag 63) is always computed last, over everything before it
  // including this tag+length header, then appended as 4 uppercase hex
  // digits.
  final withCrcHeader = '${payload.toString()}6304';
  final crc = _crc16Ccitt(withCrcHeader).toRadixString(16).toUpperCase().padLeft(4, '0');
  return '$withCrcHeader$crc';
}

String _tlv(String tag, String value) {
  final length = value.length.toString().padLeft(2, '0');
  return '$tag$length$value';
}

/// CRC-16/CCITT-FALSE: poly 0x1021, init 0xFFFF, no input/output reflection.
int _crc16Ccitt(String data) {
  var crc = 0xFFFF;
  for (final byte in data.codeUnits) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) & 0xFFFF : (crc << 1) & 0xFFFF;
    }
  }
  return crc & 0xFFFF;
}
