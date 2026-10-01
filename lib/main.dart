// ============================================================================
// المحاسب السهل — نقطة البداية
// ============================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/app_database.dart';
import 'providers/erp_provider.dart';
import 'theme/app_theme.dart';
import 'ui/splash_screen.dart';
import 'ui/lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ERPProvider(),
      child: const EasyAccountantApp(),
    ),
  );
}

class EasyAccountantApp extends StatelessWidget {
  const EasyAccountantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المحاسب السهل',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.light,
      locale: const Locale('ar', 'EG'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: LockScreen(child: child!),
        );
      },
      home: const SplashScreen(),
    );
  }
}
