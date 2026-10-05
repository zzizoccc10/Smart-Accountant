// ============================================================================
// شاشة البداية (Splash) — ثم التوجيه لشاشة التهيئة أو الرئيسية
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/erp_provider.dart';
import '../providers/session_provider.dart';
import '../services/firebase_config.dart';
import '../theme/app_theme.dart';
import 'auth/login_screen.dart';
import 'setup_screen.dart';
import 'home_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final prov = Provider.of<ERPProvider>(context, listen: false);
    final session = Provider.of<SessionProvider>(context, listen: false);

    // 1) اعرض شاشة الدخول الرئيسية دائماً (لتتيح الاختيار بين الأوضاع)
    if (!session.isLoggedIn) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (!mounted) return;
    }

    // 2) مزامنة تلقائية في الخلفية إن كانت السحابة مُفعّلة
    if (FirebaseConfig.isConfigured && session.isCompanyMode) {
      // لا ننتظرها — تجري في الخلفية
      session.syncNow();
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => prov.isInit ? const HomeShell() : const SetupScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 72,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'المحاسب السهل',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'نظام محاسبي متكامل يعمل دون اتصال',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
