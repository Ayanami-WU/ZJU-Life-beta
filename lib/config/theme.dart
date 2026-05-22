import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// ZJU Life Cupertino-like theme configuration.
///
/// The app still runs on MaterialApp/router for compatibility, but the shared
/// tokens mirror iOS grouped backgrounds, system text colors, light separators,
/// and restrained press feedback.
class AppTheme {
  // Brand colors.
  static const Color zjuBlue = Color(0xFF003D87);
  static const Color zjuBlueLight = Color(0xFF0A84FF);
  static const Color zjuBlueDark = Color(0xFF002855);

  // Accent colors.
  static const Color accentOrange = Color(0xFFFF6B35);
  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color amber = accentOrange;

  // Font aliases kept for old call sites.
  static const String serifFont = 'NotoSerifSC';
  static const String sansFont = 'NotoSansSC';

  // iOS grouped background tokens.
  static const Color backgroundLight = Color(0xFFF2F2F7);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color secondarySurfaceLight = Color(0xFFF7F7FA);
  static const Color textPrimaryLight = Color(0xFF111113);
  static const Color textSecondaryLight = Color(0xFF6E6E73);
  static const Color dividerLight = Color(0xFFD1D1D6);

  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF1C1C1E);
  static const Color cardDark = Color(0xFF1C1C1E);
  static const Color secondarySurfaceDark = Color(0xFF2C2C2E);
  static const Color textPrimaryDark = Color(0xFFF2F2F7);
  static const Color textSecondaryDark = Color(0xFF8E8E93);
  static const Color dividerDark = Color(0xFF38383A);

  // Status colors.
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = Color(0xFF007AFF);

  // Gradients are kept for branded entry cards.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [zjuBlue, zjuBlueLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFF9F0A), Color(0xFFFFCC00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const double radiusSmall = 10.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 22.0;

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.045),
          blurRadius: 14,
          offset: const Offset(0, 5),
        ),
      ];

  static List<BoxShadow> get cardShadowDark => const [];

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? zjuBlueLight : zjuBlue;
    final background = isDark ? backgroundDark : backgroundLight;
    final surface = isDark ? surfaceDark : surfaceLight;
    final secondarySurface =
        isDark ? secondarySurfaceDark : secondarySurfaceLight;
    final textPrimary = isDark ? textPrimaryDark : textPrimaryLight;
    final textSecondary = isDark ? textSecondaryDark : textSecondaryLight;
    final divider = isDark ? dividerDark : dividerLight;

    final colorScheme = isDark
        ? ColorScheme.dark(
            primary: primary,
            onPrimary: Colors.white,
            primaryContainer: primary.withValues(alpha: 0.18),
            secondary: accentOrange,
            onSecondary: Colors.white,
            surface: surface,
            onSurface: textPrimary,
            error: error,
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: primary,
            onPrimary: Colors.white,
            primaryContainer: primary.withValues(alpha: 0.12),
            secondary: accentOrange,
            onSecondary: Colors.white,
            surface: surface,
            onSurface: textPrimary,
            error: error,
            onError: Colors.white,
          );

    return ThemeData(
      useMaterial3: true,
      platform: TargetPlatform.iOS,
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: primary.withValues(alpha: 0.05),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: primary,
        scaffoldBackgroundColor: background,
        barBackgroundColor: surface.withValues(alpha: 0.88),
        textTheme: CupertinoTextThemeData(
          primaryColor: primary,
          textStyle: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            height: 1.28,
          ),
          actionTextStyle: TextStyle(
            color: primary,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
          navTitleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          navLargeTitleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.12,
          ),
          tabLabelTextStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface.withValues(alpha: 0.92),
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? primary : textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primary : textSecondary,
            size: 24,
          );
        }),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.12,
        ),
        displayMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.16,
        ),
        displaySmall: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textPrimary,
          height: 1.45,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textSecondary,
          height: 1.35,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: divider.withValues(alpha: isDark ? 0.72 : 0.82),
        thickness: 0.5,
        space: 0.5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondarySurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: divider.withValues(alpha: 0.75)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: divider.withValues(alpha: 0.75)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ).copyWith(
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: divider.withValues(alpha: 0.9)),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: secondarySurface,
        selectedColor: primary.withValues(alpha: isDark ? 0.22 : 0.13),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        secondaryLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        side: BorderSide(color: divider.withValues(alpha: 0.65)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        indicatorColor: primary,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
    );
  }
}

/// Theme extension - short aliases used across the app.
extension ThemeContextExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => theme.textTheme;
  ColorScheme get colorScheme => theme.colorScheme;

  bool get isDark => theme.brightness == Brightness.dark;
  bool get isDarkMode => isDark;

  Color get primaryColor => colorScheme.primary;
  Color get textColor =>
      isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight;
  Color get secondaryColor =>
      isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
  Color get backgroundColor =>
      isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight;
  Color get groupedBackgroundColor => backgroundColor;
  Color get secondaryBackgroundColor =>
      isDark ? AppTheme.secondarySurfaceDark : AppTheme.secondarySurfaceLight;
  Color get cardColor => isDark ? AppTheme.cardDark : AppTheme.cardLight;
  Color get dividerColor =>
      isDark ? AppTheme.dividerDark : AppTheme.dividerLight;
  Color get borderColor => dividerColor;
  Color get surfaceColor => colorScheme.surface;
  Color get onSurfaceColor => colorScheme.onSurface;
  Color get amberColor => AppTheme.accentOrange;

  List<BoxShadow> get cardShadow =>
      isDark ? AppTheme.cardShadowDark : AppTheme.cardShadow;
}
