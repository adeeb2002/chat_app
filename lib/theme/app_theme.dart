import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryColor = Color(0xFF075E54);
  static const Color primaryLight = Color(0xFF25D366);
  static const Color primaryDark = Color(0xFF054D44);
  static const Color accentColor = Color(0xFF128C7E);

  static const Color onlineColor = Color(0xFF25D366);
  static const Color offlineColor = Color(0xFFB0BEC5);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color successColor = Color(0xFF4CAF50);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Segoe UI',
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: const Color(0xFFF0F2F5),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: primaryLight,
        surface: Colors.white,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F6F8),
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: const TextStyle(fontSize: 14, color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE8E8E8),
        thickness: 0.5,
        space: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryColor;
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withValues(alpha: 0.5);
          }
          return Colors.grey.shade300;
        }),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A),
        ),
        headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A),
        ),
        titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A),
        ),
        titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A),
        ),
        bodyLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.normal, color: Color(0xFF1A1A1A),
        ),
        bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFF1A1A1A),
        ),
        bodySmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFF667781),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Segoe UI',
      brightness: Brightness.dark,
      primaryColor: primaryLight,
      scaffoldBackgroundColor: const Color(0xFF111B21),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryLight,
        secondary: primaryLight,
        surface: const Color(0xFF1F2C33),
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1F2C33),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1F2C33),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: const Color(0xFF111B21),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          side: const BorderSide(color: primaryLight, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A3942),
        hintStyle: const TextStyle(color: Color(0xFF8696A0), fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF374045)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryLight, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2A3942),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: const TextStyle(fontSize: 14, color: Colors.white),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF313D45),
        thickness: 0.5,
        space: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primaryLight,
        unselectedItemColor: Color(0xFF8696A0),
        backgroundColor: Color(0xFF1F2C33),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Color(0xFF111B21),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primaryLight;
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryLight.withValues(alpha: 0.5);
          }
          return Colors.grey.shade700;
        }),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.normal, color: Color(0xFFD1D7DB),
        ),
        bodyMedium: TextStyle(
          fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFD1D7DB),
        ),
        bodySmall: TextStyle(
          fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFF8696A0),
        ),
      ),
    );
  }

  static Color messageSentColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6);
  }

  static Color messageReceivedColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1F2C33) : Colors.white;
  }

  static Color chatBgColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD);
  }

  static Color textPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFD1D7DB)
        : const Color(0xFF1A1A1A);
  }

  static Color textSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF8696A0)
        : const Color(0xFF667781);
  }

  static Color surfaceContainer(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1F2C33)
        : Colors.white;
  }

  static Color shimmerBase(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A3942)
        : Colors.grey.shade100;
  }

  static Color shimmerHighlight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF374045)
        : Colors.grey.shade50;
  }

  static Color onlineDotColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF25D366)
        : const Color(0xFF25D366);
  }
}
