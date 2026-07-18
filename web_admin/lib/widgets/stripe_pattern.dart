import 'package:flutter/material.dart';

/// Thin diagonal lines referencing the squeegee strokes left when applying
/// window tint film — the sidebar's one signature flourish, kept subtle.
class StripePatternPainter extends CustomPainter {
  final Color color;
  const StripePatternPainter({this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 2;

    const gap = 14.0;
    final diagonal = size.width + size.height;
    for (double x = -size.height; x < diagonal; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
