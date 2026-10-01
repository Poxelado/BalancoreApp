import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/screens/auth_wrapper.dart';

class BalancoreApp extends ConsumerWidget {
  const BalancoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themePreferencesProvider);
    final lightTheme = ref.watch(lightThemeDataProvider);
    final darkTheme = ref.watch(darkThemeDataProvider);

    // ValueKey fuerza rebuild completo al cambiar modo o color
    return MaterialApp(
      key: ValueKey('${prefs.themeMode.name}_${prefs.colorTheme.name}'),
      title: 'Balancore',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: prefs.themeMode,
      home: const AuthWrapper(),
    );
  }
}