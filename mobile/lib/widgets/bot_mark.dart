import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// เครื่องหมายผู้ช่วยแชท: ฟองคำพูดกับประกายวิบวับ วาดเองแทน `Icons.smart_toy`
/// หรือ `Icons.chat_bubble_outline`
///
/// ไอคอนหุ่นยนต์สำเร็จรูปดูเป็นของเล่น ส่วนฟองคำพูดเปล่าๆ ก็แยกไม่ออกจากแชท
/// ธรรมดา — ฟองคำพูดบวกประกายคือภาษาภาพที่อ่านออกทันทีว่า "ผู้ช่วยอัจฉริยะ"
///
/// ใช้ตัวเดียวกันทั้งปุ่มลอยหน้าแรกและรูปโปรไฟล์บอทในหน้าแชท เพื่อให้ปุ่มที่กด
/// กับตัวที่คุยด้วยเป็นสิ่งเดียวกันในสายตาผู้ใช้
class BotMark extends StatelessWidget {
  const BotMark({super.key, required this.size, this.color = Colors.white});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _BotMarkPainter(color),
    );
  }
}

/// วงกลมไล่สีแบรนด์พร้อม [BotMark] อยู่กลาง — รูปโปรไฟล์ของบอท
class BotAvatar extends StatelessWidget {
  const BotAvatar({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDarker],
        ),
      ),
      child: Center(child: BotMark(size: size * 0.56)),
    );
  }
}

class _BotMarkPainter extends CustomPainter {
  const _BotMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;

    // ฟองคำพูด เว้นที่มุมขวาบนไว้ให้ประกายดวงเล็ก
    final bubble = RRect.fromLTRBR(
      w * 0.06,
      h * 0.10,
      w * 0.80,
      h * 0.70,
      Radius.circular(w * 0.22),
    );
    canvas.drawRRect(bubble, stroke);

    // หางฟองชี้ลงซ้าย
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.24, h * 0.70)
        ..lineTo(w * 0.24, h * 0.94)
        ..lineTo(w * 0.46, h * 0.70),
      stroke,
    );

    canvas.drawPath(_sparkle(w * 0.43, h * 0.40, w * 0.20), fill);
    canvas.drawPath(_sparkle(w * 0.88, h * 0.16, w * 0.12), fill);
  }

  /// ประกายสี่แฉกเว้าโค้ง
  Path _sparkle(double cx, double cy, double r) {
    return Path()
      ..moveTo(cx, cy - r)
      ..quadraticBezierTo(cx, cy, cx + r, cy)
      ..quadraticBezierTo(cx, cy, cx, cy + r)
      ..quadraticBezierTo(cx, cy, cx - r, cy)
      ..quadraticBezierTo(cx, cy, cx, cy - r)
      ..close();
  }

  @override
  bool shouldRepaint(_BotMarkPainter oldDelegate) => oldDelegate.color != color;
}
