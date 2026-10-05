// ============================================================================
// المحاسب السهل — نقطة البداية
// ----------------------------------------------------------------------------
// • تهيئة التخزين المحلي (Hive).
// • تهيئة Firebase (اختيارية — تعمل محلياً إن لم تُرفع الإعدادات).
// • تهيئة الإشعارات المحلية + السحابية.
// • ربط مزوّدي الحالة: ERPProvider + SessionProvider.
// ============================================================================
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'providers/erp_provider.dart';
import 'providers/session_provider.dart';
import 'services/firebase_config.dart';
import 'services/local_notifications.dart';
import 'services/push_notifications.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';
import 'ui/lock_screen.dart';
import 'ui/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) التخزين المحلي
  await AppDatabase.init();
  await UserService.initBoxes();

  // 2) Firebase (اختياري — يتخطى بهدوء إن لم تُرفع الإعدادات)
  await _initFirebase();

  // 3) الإشعارات المحلية
  await LocalNotifications.init();

  // 4) الإشعارات السحابية (FCM)
  await PushNotifications.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ERPProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()..bootstrap()),
      ],
      child: const EasyAccountantApp(),
    ),
  );
}

/// تهيئة Firebase بأمان — لا تُعطّل التطبيق إن فشلت
Future<void> _initFirebase() async {
  if (!FirebaseConfig.isConfigured) {
    if (kDebugMode) {
      debugPrint('[main] Firebase not configured — running offline-only');
    }
    return;
  }
  try {
    final options = FirebaseConfig.currentPlatformOptions;
    if (options != null) {
      await Firebase.initializeApp(options: options);
    } else {
      // على أندرويد/iOS: التهيئة التلقائية من google-services.json / plist
      await Firebase.initializeApp();
    }
    // تسجيل معالج الرسائل في الخلفية
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
    }
    if (kDebugMode) {
      debugPrint('[main] Firebase initialized ✓ (${FirebaseConfig.projectId})');
    }
  } catch (e) {
    if (kDebugMode) debugPrint('[main] Firebase init failed: $e');
  }
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
      themeMode: ThemeMode.system,
      // دعم اللغة العربية (أندرويد + iOS)
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('ar'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
