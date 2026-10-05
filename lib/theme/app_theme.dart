// ============================================================================
// ثيم التطبيق الموحّد — Material Design 3 مع دعم RTL كامل
// ----------------------------------------------------------------------------
// مصدر الحقيقة الواحد لكل الألوان والتدرّجات والمكوّنات في النظام.
// استخدم دائماً AppColors / AppGradients / AppTheme — لا ألوان مبعثرة.
// ============================================================================
import 'package:flutter/material.dart';

/// اللوحة الموحّدة للألوان (تُستخدم في كل شاشات النظام)
class AppColors {
  // الأساسي
  static const primary = Color(0xFF1565C0); // أزرق احترافي
  static const primaryDark = Color(0xFF0D47A1);
  static const primaryLight = Color(0xFF42A5F5);
  static const secondary = Color(0xFF00897B); // تركوازي
  static const secondaryDark = Color(0xFF00695C);

  // الحالات
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const warning = Color(0xFFF57C00);
  static const info = Color(0xFF0277BD);

  // لوحة إضافية
  static const purple = Color(0xFF6A1B9A);
  static const teal = Color(0xFF00695C);
  static const indigo = Color(0xFF3949AB);
  static const amber = Color(0xFFFFA000);

  // الأسطح
  static const bg = Color(0xFFF4F6F9);
  static const card = Colors.white;
  static const divider = Color(0xFFE4E8EE);
  static const textDark = Color(0xFF1A1A1A);
  static const textBody = Color(0xFF2A2A2A);
  static const textMuted = Color(0xFF6B7280);

  // الوضع الداكن
  static const darkBg = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
}

/// التدرّجات الموحّدة
class AppGradients {
  /// تدرّج الهوية (الأزرق) — الترويسات والدرج
  static const brand = LinearGradient(
    colors: [AppColors.primary, AppColors.primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// تدرّج البطاقات الترحيبية
  static const hero = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  /// تدرّج مالك النظام (بنفسجي)
  static const owner = LinearGradient(
    colors: [AppColors.purple, AppColors.indigo],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  /// تدرّج النجاح
  static const success = LinearGradient(
    colors: [AppColors.success, AppColors.secondary],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
}

/// ألوان ثابتة لكل نوع إشعار (لتوحيد المظهر)
class AppStatusColors {
  static const active = AppColors.success;
  static const stopped = AppColors.danger;
  static const pending = AppColors.warning;
  static const info = AppColors.info;
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD6E4F7),
      secondary: AppColors.secondary,
      error: AppColors.danger,
      surface: AppColors.card,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Cairo',
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: const TextStyle(fontFamily: 'Cairo'),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(fontFamily: 'Cairo', fontSize: 11),
        elevation: 8,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: AppColors.textMuted),
        selectedLabelTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: AppColors.primary),
        unselectedLabelTextStyle:
            TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
        indicatorColor: Color(0x1A1565C0),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicatorColor: Colors.white,
        labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        unselectedLabelStyle: TextStyle(fontFamily: 'Cairo'),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 17,
          color: AppColors.textDark,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        side: const BorderSide(color: AppColors.divider),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.primary,
        titleTextStyle: TextStyle(
            fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 14,
            color: AppColors.textDark),
        subtitleTextStyle: TextStyle(
            fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.success : null),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textDark,
        contentTextStyle: TextStyle(fontFamily: 'Cairo', color: Colors.white),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          color: AppColors.textDark,
        ),
        titleSmall: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        bodyLarge: TextStyle(fontFamily: 'Cairo', color: AppColors.textBody),
        bodyMedium: TextStyle(fontFamily: 'Cairo', color: AppColors.textBody),
        bodySmall: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
        labelLarge: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            color: AppColors.textBody),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF64B5F6),
      secondary: AppColors.secondary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: Brightness.dark,
      fontFamily: 'Cairo',
      scaffoldBackgroundColor: AppColors.darkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: Color(0xFF64B5F6),
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2C2C2C)),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: Colors.white,
      ),
    );
  }
}

/// تنسيق الأرقام والعملة
class Fmt {
  static String money(double v, [String currency = 'ر.ي']) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$intPart.${parts[1]} $currency';
  }

  static String num(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
