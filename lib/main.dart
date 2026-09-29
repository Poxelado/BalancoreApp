import 'package:flutter/material.dart';
import 'screens/profile_screen.dart';

void main() {
  runApp(const BalancoreApp());
}

class BalancoreApp extends StatelessWidget {
  const BalancoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balancore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B1228),
          primary: const Color(0xFF6B1228),
        ),
        useMaterial3: true,
      ),
      home: const BalancoreMainScreen(),
    );
  }
}
