import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';

/// รูปสินค้าสำหรับการ์ด/กริดสินค้า
///
/// ถ้าแอดมินใส่ `imageUrl` ไว้ก็ใช้รูปนั้น แต่ตอนนี้สินค้าส่วนใหญ่ยังไม่มีรูป
/// ซึ่งเดิมขึ้นเป็นกล่องเทาเปล่าๆ ดูเหมือนรูปโหลดไม่ขึ้น แทนที่จะปล่อยว่าง
/// เลยวาดตัวอย่างเฉดฟิล์มจากค่า **ความเข้ม (VLT)** ของสินค้าเอง — ฟิล์ม VLT
/// ต่ำจะได้แผ่นเข้ม ฟิล์ม VLT สูงจะได้แผ่นใส ลูกค้ากวาดตาดูกริดก็เดาได้ทันที
/// ว่ารุ่นไหนเข้มกว่ากัน ซึ่งเป็นข้อมูลจริงที่ร้านมีอยู่แล้ว ไม่ใช่ภาพประดับ
///
/// สินค้าที่ไม่มี VLT (เช่นแพ็กเกจล้างรถ) ได้แผ่นโทนแบรนด์พร้อมไอคอนของบริการ
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({super.key, required this.product, this.showLabel = true});

  final Product product;

  /// ป้ายบอกความเข้มมุมล่าง ปิดได้เมื่อใช้ในที่แคบๆ
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        // รูปเสีย/เน็ตหลุด ตกมาที่แผ่นเฉดเหมือนกัน ดีกว่าโชว์กล่อง error ของ Flutter
        errorBuilder: (_, _, _) => _painted(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _painted(),
      );
    }
    return _painted();
  }

  Widget _painted() {
    final vlt = product.vltPct;
    if (vlt == null) return _ServiceSwatch(productName: product.name);
    return _FilmSwatch(vltPct: vlt, showLabel: showLabel);
  }
}

class _FilmSwatch extends StatelessWidget {
  const _FilmSwatch({required this.vltPct, required this.showLabel});

  final int vltPct;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    // VLT คือปริมาณแสงที่ผ่าน ยิ่งน้อยยิ่งเข้ม — ไล่จากกระจกเกือบดำไปจนเกือบใส
    final t = (vltPct.clamp(0, 100)) / 100;
    final dark = Color.lerp(const Color(0xFF0D1319), const Color(0xFF93A7B8), t)!;
    final light = Color.lerp(const Color(0xFF2A3A49), const Color(0xFFD7E3ED), t)!;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [dark, light],
            ),
          ),
        ),
        CustomPaint(painter: _GlassPainter(tint: t)),
        if (showLabel)
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ความเข้ม $vltPct%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// เงากระจกรถกับแถบแสงสะท้อน ให้แผ่นสีดูเป็นกระจกติดฟิล์ม ไม่ใช่สี่เหลี่ยมสีเปล่า
class _GlassPainter extends CustomPainter {
  const _GlassPainter({required this.tint});

  /// 0 = ฟิล์มเข้มสุด, 1 = ใสสุด — ใช้กลับทิศความเข้มของเส้นให้เห็นบนพื้นทั้งสองแบบ
  final double tint;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // รูปทรงกระจกหน้า: สี่เหลี่ยมคางหมูมุมมน
    final glass = Path()
      ..moveTo(w * 0.22, h * 0.34)
      ..quadraticBezierTo(w * 0.5, h * 0.24, w * 0.78, h * 0.34)
      ..lineTo(w * 0.88, h * 0.66)
      ..quadraticBezierTo(w * 0.5, h * 0.76, w * 0.12, h * 0.66)
      ..close();

    canvas.drawPath(
      glass,
      Paint()..color = Colors.white.withValues(alpha: 0.10 + 0.06 * (1 - tint)),
    );
    canvas.drawPath(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.22),
    );

    // แถบแสงสะท้อนพาดเฉียง
    canvas.save();
    canvas.clipPath(glass);
    final gloss = Path()
      ..moveTo(w * 0.1, h * 0.8)
      ..lineTo(w * 0.42, h * 0.18)
      ..lineTo(w * 0.56, h * 0.18)
      ..lineTo(w * 0.24, h * 0.8)
      ..close();
    canvas.drawPath(gloss, Paint()..color = Colors.white.withValues(alpha: 0.14));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassPainter oldDelegate) => oldDelegate.tint != tint;
}

class _ServiceSwatch extends StatelessWidget {
  const _ServiceSwatch({required this.productName});

  final String productName;

  IconData get _icon {
    if (productName.contains('ล้าง')) return Icons.local_car_wash_outlined;
    if (productName.contains('เคลือบ') || productName.contains('ขัด')) {
      return Icons.auto_awesome_outlined;
    }
    return Icons.directions_car_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDarker],
        ),
      ),
      child: Center(
        child: Icon(_icon, size: 44, color: Colors.white.withValues(alpha: 0.9)),
      ),
    );
  }
}
