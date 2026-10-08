import 'package:flutter/material.dart';

import 'api/auth_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BKK Car Glass',
      theme: AppTheme.light,
      // ริบบิ้น DEBUG มุมขวาบนบังเนื้อหาจริงเวลาเดโมและตอนแคปหน้าจอ
      // (ขึ้นเฉพาะ debug build อยู่แล้ว ไม่ได้ติดไป release)
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
