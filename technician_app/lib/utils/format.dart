import 'package:intl/intl.dart';

final NumberFormat _thb = NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 0);

String formatBaht(double amount) => _thb.format(amount);
