import 'package:flutter/material.dart';

import '../api/auth_service.dart';
import '../theme/app_theme.dart';
import 'auth/phone_login_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/image/splash_bg.png',
            fit: BoxFit.cover,
          ),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  right: 24,
                  bottom: 64,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        final loggedIn = AuthService.instance.session != null;
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => loggedIn
                                ? const MainShell()
                                : const PhoneLoginScreen(),
                          ),
                        );
                      },
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        child: Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
