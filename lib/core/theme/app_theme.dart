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

/// Colores semánticos que [ColorScheme] no expone (éxito, aviso, descanso…).
///
/// Se resuelven desde el tema con [AppSemanticColors.of], así que se mantienen
/// coherentes en claro/oscuro sin importar la paleta elegida.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color info;
  final Color rest;

  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.info,
    required this.rest,
  });

  static const AppSemanticColors light = AppSemanticColors(
    success: Color(0xFF2E7D32),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD7F1D9),
    warning: Color(0xFFB26A00),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFE7C2),
    info: Color(0xFF1565C0),
    rest: Color(0xFF546E7A),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF81C784),
    onSuccess: Color(0xFF0B2E0D),
    successContainer: Color(0xFF1B3A1E),
    warning: Color(0xFFFFD54F),
    onWarning: Color(0xFF3A2A00),
    warningContainer: Color(0xFF4A3400),
    info: Color(0xFF90CAF9),
    rest: Color(0xFFB0BEC5),
  );

  static AppSemanticColors of(BuildContext context) =>
      Theme.of(context).extension<AppSemanticColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? info,
    Color? rest,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      rest: rest ?? this.rest,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      rest: Color.lerp(rest, other.rest, t)!,
    );
  }
}

/// Tono claro de la paleta para usar como PRIMER PLANO (textos, iconos,
/// bordes, botones delineados) sobre el fondo oscuro. En modo claro coincide
/// con el primario. Usa `accentOf(context)`.
@immutable
class AppAccentColors extends ThemeExtension<AppAccentColors> {
  final Color accent;

  const AppAccentColors({required this.accent});

  static AppAccentColors of(BuildContext context) =>
      Theme.of(context).extension<AppAccentColors>() ??
      const AppAccentColors(accent: Color(0xFF6B1228));

  @override
  AppAccentColors copyWith({Color? accent}) =>
      AppAccentColors(accent: accent ?? this.accent);

  @override
  AppAccentColors lerp(ThemeExtension<AppAccentColors>? other, double t) {
    if (other is! AppAccentColors) return this;
    return AppAccentColors(accent: Color.lerp(accent, other.accent, t)!);
  }
}

/// Primer plano legible con el color de la paleta elegida.
Color accentOf(BuildContext context) => AppAccentColors.of(context).accent;

/// Paleta ÚNICA de colores de dato (macros, calorías, agua, sueño, entreno,
/// racha). A diferencia de [AppSemanticColors], estos colores no cambian con
/// el tema ni la paleta: identifican una magnitud concreta y deben ser siempre
/// los mismos en toda la app. Antes de esto existían dos paletas de macros
/// distintas (verde/ámbar/rosa y naranja/azul/rojo); aquí queda una sola.
class AppDataColors {
  static const Color calories = Color(0xFFFF9800);
  static const Color protein = Color(0xFF4CAF50);
  static const Color carbs = Color(0xFFFFC107);
  static const Color fat = Color(0xFFE91E63);
  static const Color water = Color(0xFF2196F3);
  static const Color sleep = Color(0xFF7E57C2);
  static const Color training = Color(0xFFE91E63);
  static const Color streak = Color(0xFFFF6D00);
}

class AppTheme {
  /// Radio base usado por tarjetas, botones e inputs.
  static const double radius = 16;

  /// Texto/icono legible sobre [background] (blanco o negro según contraste).
  static Color _on(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? Colors.white
          : Colors.black;

  static ThemeData light(AppColorTheme colorTheme) =>
      _build(colorTheme, Brightness.light);

  static ThemeData dark(AppColorTheme colorTheme) =>
      _build(colorTheme, Brightness.dark);

  static ThemeData _build(AppColorTheme colorTheme, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // El primario de cada paleta es oscuro: sirve de fondo de botones con
    // texto blanco. Para primer plano sobre el fondo oscuro se usa el tono
    // claro de la paleta (accent), que mantiene el color elegido legible.
    final primary = colorTheme.primary;
    final secondary = colorTheme.secondary;
    final accent = isDark ? colorTheme.accent : colorTheme.primary;
    final onPrimary = _on(primary);
    final onSecondary = _on(secondary);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: isDark ? const Color(0xFF1A1A1C) : const Color(0xFFFFFFFF),
      onSurface: isDark ? const Color(0xFFEDEDED) : const Color(0xFF1A1A1A),
    );

    final scaffold = isDark ? const Color(0xFF0F0F10) : const Color(0xFFF7F7F8);
    final textMain = isDark ? const Color(0xFFEDEDED) : const Color(0xFF1A1A1A);
    final textMuted = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF6B6B70);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      extensions: [
        isDark ? AppSemanticColors.dark : AppSemanticColors.light,
        AppAccentColors(accent: accent),
      ],
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
        foregroundColor: textMain,
        iconTheme: IconThemeData(color: textMain),
        titleTextStyle: TextStyle(
          color: textMain,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent.withValues(alpha: 0.55)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? const Color(0xFF232326)
            : const Color(0xFFF1F1F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
        ),
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: shape,
        iconColor: textMuted,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        selectedColor:
            isDark ? accent.withValues(alpha: 0.22) : scheme.primaryContainer,
        checkmarkColor: accent,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      dividerColor: scheme.outlineVariant,
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textMain),
        bodyMedium: TextStyle(color: textMain),
        bodySmall: TextStyle(color: textMuted),
        titleLarge: TextStyle(color: textMain),
        titleMedium: TextStyle(color: textMain),
        titleSmall: TextStyle(color: textMain),
      ),
    );
  }

  // Compatibilidad
  static ThemeData get lightTheme => light(AppColorTheme.darkRed);
  static ThemeData get darkTheme => dark(AppColorTheme.darkRed);
  static const Color primaryColor = Color(0xFF6B1228);
  static const Color secondaryColor = Color(0xFF9B2D4A);
}
