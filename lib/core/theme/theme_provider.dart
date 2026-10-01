import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

const _kThemeModeKey = 'balancore_theme_mode';
const _kColorThemeKey = 'balancore_color_theme';

class ThemePreferences {
  final ThemeMode themeMode;
  final AppColorTheme colorTheme;

  const ThemePreferences({
    this.themeMode = ThemeMode.dark,
    this.colorTheme = AppColorTheme.darkRed,
  });

  ThemePreferences copyWith({
    ThemeMode? themeMode,
    AppColorTheme? colorTheme,
  }) {
    return ThemePreferences(
      themeMode: themeMode ?? this.themeMode,
      colorTheme: colorTheme ?? this.colorTheme,
    );
  }
}

class ThemePreferencesNotifier extends StateNotifier<ThemePreferences> {
  ThemePreferencesNotifier() : super(const ThemePreferences()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_kThemeModeKey);
    final colorStr = prefs.getString(_kColorThemeKey);

    ThemeMode mode = ThemeMode.dark;
    if (modeStr == 'light') {
      mode = ThemeMode.light;
    } else if (modeStr == 'system') {
      mode = ThemeMode.system;
    }

    state = ThemePreferences(
      themeMode: mode,
      colorTheme: AppColorThemeX.fromName(colorStr),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_kThemeModeKey, value);
  }

  Future<void> toggleLightDark() async {
    final next =
    state.themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(next);
  }

  Future<void> setColorTheme(AppColorTheme color) async {
    state = state.copyWith(colorTheme: color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kColorThemeKey, color.name);
  }
}

final themePreferencesProvider =
StateNotifierProvider<ThemePreferencesNotifier, ThemePreferences>(
      (ref) => ThemePreferencesNotifier(),
);

final lightThemeDataProvider = Provider<ThemeData>((ref) {
  final color = ref.watch(themePreferencesProvider).colorTheme;
  return AppTheme.light(color);
});

final darkThemeDataProvider = Provider<ThemeData>((ref) {
  final color = ref.watch(themePreferencesProvider).colorTheme;
  return AppTheme.dark(color);
});