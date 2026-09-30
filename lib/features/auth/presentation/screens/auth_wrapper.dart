import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const LoginScreen();
        }

        // Usuario logueado → verificar si completó onboarding
        final profileAsync = ref.watch(userProfileProvider);

        return profileAsync.when(
          data: (profile) {
            if (profile == null || !profile.onboardingCompleted) {
              return const OnboardingScreen();
            }
            return const ProfileScreen();
          },
          loading: () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF6B1228)),
            ),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('Error al cargar perfil: $e')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6B1228)),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }
}