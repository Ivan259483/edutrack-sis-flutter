import 'package:flutter/material.dart';

/// Colors of the web portals: the student portal (Bootstrap 5 + slate) and
/// the admin portal (Tailwind tokens in admin/src/index.css).
class AppColors {
  // Slate (login card, student sidebar, dark pages)
  static const slate900 = Color(0xFF0F172A);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate100 = Color(0xFFF1F5F9);
  static const pageBg = Color(0xFFF8FAFC);

  // Student portal (Bootstrap defaults + custom blues)
  static const primary = Color(0xFF0D6EFD);
  static const blue700 = Color(0xFF1D4ED8);
  static const blue600 = Color(0xFF2563EB);
  static const blue500 = Color(0xFF3B82F6);
  static const blue50 = Color(0xFFEFF6FF);
  static const success = Color(0xFF198754);
  static const danger = Color(0xFFDC3545);
  static const warning = Color(0xFFFFC107);
  static const info = Color(0xFF0DCAF0);
  static const muted = Color(0xFF6C757D);
  static const dark = Color(0xFF212529);
  static const light = Color(0xFFF8F9FA);
  static const borderLight = Color(0xFFDEE2E6);

  // Tailwind palette used for accents
  static const green500 = Color(0xFF22C55E);
  static const green600 = Color(0xFF16A34A);
  static const green50 = Color(0xFFF0FDF4);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);
  static const emerald800 = Color(0xFF065F46);
  static const red500 = Color(0xFFEF4444);
  static const red400 = Color(0xFFF87171);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const amber50 = Color(0xFFFFFBEB);
  static const violet500 = Color(0xFF8B5CF6);
  static const violet50 = Color(0xFFF5F3FF);
  static const pink500 = Color(0xFFEC4899);

  // Admin portal tokens (hsl values from admin/src/index.css)
  static const adminPrimary = Color(0xFF0B64F4); // 217 91% 50%
  static const adminBg = Color(0xFFF8FAFC); // 210 40% 98%
  static const adminFg = Color(0xFF0F172A); // 222 47% 11%
  static const adminMuted = Color(0xFFF1F5F9); // 210 40% 96%
  static const adminMutedFg = Color(0xFF66768F); // 215 16% 47%
  static const adminAccent = Color(0xFFEAF0F6); // 210 40% 94%
  static const adminBorder = Color(0xFFE2E8F0); // 214 32% 91%
  static const adminDestructive = Color(0xFFEF4444); // 0 84% 60%
  static const chart2 = Color(0xFF22C35D); // 142 71% 45%
  static const chart3 = Color(0xFFF59E0B); // 38 92% 50%
  static const chart4 = Color(0xFFA855E0); // 280 65% 60%
  static const chart5 = Color(0xFFE23C76); // 340 75% 55%
}

ThemeData _base(Color primary, Color background, Color foreground, Color border) {
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    primary: primary,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: foreground,
    error: AppColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    dividerColor: border,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: foreground,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: border)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      shadowColor: Colors.black12,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      errorMaxLines: 3,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

final studentTheme = _base(AppColors.primary, AppColors.pageBg, AppColors.dark, AppColors.borderLight);
final adminTheme = _base(AppColors.adminPrimary, AppColors.adminBg, AppColors.adminFg, AppColors.adminBorder);
