import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// สไตล์ช่องกรอกที่ใช้ร่วมกันทุกหน้าในกลุ่ม auth
InputDecoration authFieldDecoration(String hint, {Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
    filled: true,
    fillColor: const Color(0xFFF5F5F5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
    ),
    suffixIcon: suffixIcon,
  );
}

/// Label ด้านบนช่องกรอก
Widget authFieldLabel(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.black87,
      ),
    ),
  );
}

/// โลโก้ร้าน คุมขนาดด้วย width เพื่อไม่ให้ดัน layout
class BkkLogo extends StatelessWidget {
  const BkkLogo({super.key, required this.isLight, this.width = 220});

  final bool isLight;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      isLight ? 'assets/image/white_logo.png' : 'assets/image/red_logo.png',
      width: width,
      fit: BoxFit.contain,
    );
  }
}
