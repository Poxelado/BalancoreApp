import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/profile/presentation/screens/profile_screen.dart';

class BalancoreApp extends StatelessWidget {
  const BalancoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balancore',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Más adelante lo controlaremos con Riverpod
      home: const ProfileScreen(), // Temporalmente, luego cambiaremos esto
    );
  }
}