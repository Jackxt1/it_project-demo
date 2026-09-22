import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Section header like "01 เลือกวันที่" used throughout the booking flow —
/// the leading step number renders in the brand red so it reads as an
/// accent/badge rather than plain body text, while the rest of the label
/// stays black.
class SectionNumberTitle extends StatelessWidget {
  const SectionNumberTitle(this.text, {super.key});

  final String text;

  static final _leadingNumber = RegExp(r'^(\d+)(\s*)(.*)$');

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontWeight: FontWeight.w700, fontSize: 16);
    final match = _leadingNumber.firstMatch(text);
    if (match == null) {
      return Text(text, style: style);
    }
    // Text.rich (not a bare RichText) so the widget's type stays Text —
    // find.text() in widget tests only matches RichText when explicitly
    // asked to (findRichText: true), and every call site here predates that.
    return Text.rich(
      TextSpan(
        style: style.copyWith(color: Colors.black),
        children: [
          TextSpan(text: match.group(1), style: const TextStyle(color: AppColors.primary)),
          TextSpan(text: '${match.group(2)}${match.group(3)}'),
        ],
      ),
    );
  }
}
