import 'package:flutter/material.dart';

/// Paletas de color disponibles en la app.
enum AppColorTheme {
  darkRed,
  gold,
  blue,
  purple,
}

extension AppColorThemeX on AppColorTheme {
  String get label {
    switch (this) {
      case AppColorTheme.darkRed:
        return 'Rojo oscuro';
      case AppColorTheme.gold:
        return 'Dorado';
      case AppColorTheme.blue:
        return 'Azul';
      case AppColorTheme.purple:
        return 'Morado';
    }
  }

  Color get primary {
    switch (this) {
      case AppColorTheme.darkRed:
        return const Color(0xFF6B1228);
      case AppColorTheme.gold:
        return const Color(0xFFB8860B);
      case AppColorTheme.blue:
        return const Color(0xFF1A4B8C);
      case AppColorTheme.purple:
        return const Color(0xFF5B2C6F);
    }
  }

  Color get secondary {
    switch (this) {
      case AppColorTheme.darkRed:
        return const Color(0xFF9B2D4A);
      case AppColorTheme.gold:
        return const Color(0xFFD4A017);
      case AppColorTheme.blue:
        return const Color(0xFF2E6BB0);
      case AppColorTheme.purple:
        return const Color(0xFF8E44AD);
    }
  }

  Color get accent {
    switch (this) {
      case AppColorTheme.darkRed:
        return const Color(0xFFC45A6E);
      case AppColorTheme.gold:
        return const Color(0xFFE6C35C);
      case AppColorTheme.blue:
        return const Color(0xFF5B9BD5);
      case AppColorTheme.purple:
        return const Color(0xFFBB8FCE);
    }
  }

  static AppColorTheme fromName(String? name) {
    return AppColorTheme.values.firstWhere(
          (e) => e.name == name,
      orElse: () => AppColorTheme.darkRed,
    );
  }
}

class AppTheme {
  static ThemeData light(AppColorTheme colorTheme) {
    final primary = colorTheme.primary;
    final secondary = colorTheme.secondary;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        brightness: Brightness.light,
        surface: const Color(0xFFF8F6F4),
        onSurface: const Color(0xFF1A1A1A),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F6F4),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerColor: Colors.grey.shade300,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF1A1A1A)),
        bodyMedium: TextStyle(color: Color(0xFF1A1A1A)),
        bodySmall: TextStyle(color: Color(0xFF555555)),
        titleLarge: TextStyle(color: Color(0xFF1A1A1A)),
        titleMedium: TextStyle(color: Color(0xFF1A1A1A)),
        titleSmall: TextStyle(color: Color(0xFF1A1A1A)),
      ),
    );
  }

  static ThemeData dark(AppColorTheme colorTheme) {
    final primary = colorTheme.primary;
    final secondary = colorTheme.secondary;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        brightness: Brightness.dark,
        surface: const Color(0xFF1A1A2E),
        onSurface: const Color(0xFFF0F0F0),
      ),
      scaffoldBackgroundColor: const Color(0xFF12121F),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey.shade500,
        backgroundColor: const Color(0xFF1A1A2E),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A2E),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerColor: Colors.grey.shade800,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFF0F0F0)),
        bodyMedium: TextStyle(color: Color(0xFFF0F0F0)),
        bodySmall: TextStyle(color: Color(0xFFAAAAAA)),
        titleLarge: TextStyle(color: Color(0xFFF0F0F0)),
        titleMedium: TextStyle(color: Color(0xFFF0F0F0)),
        titleSmall: TextStyle(color: Color(0xFFF0F0F0)),
      ),
    );
  }

  // Compatibilidad
  static ThemeData get lightTheme => light(AppColorTheme.darkRed);
  static ThemeData get darkTheme => dark(AppColorTheme.darkRed);
  static const Color primaryColor = Color(0xFF6B1228);
  static const Color secondaryColor = Color(0xFF9B2D4A);
}