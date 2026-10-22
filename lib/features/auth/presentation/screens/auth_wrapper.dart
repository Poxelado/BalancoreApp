import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'verify_email_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/achievements/achievement_watcher.dart';

/// Qué pantalla de nivel superior corresponde según el estado de la cuenta.
/// Se aísla para poder probarlo sin levantar toda la app.
enum AuthGate { login, onboarding, verifyEmail, home }

AuthGate resolveAuthGate({
  required bool hasUser,
  required bool hasProfile,
  required bool onboardingCompleted,
  required bool emailVerified,
  required bool usesPasswordProvider,
  required bool verificationSkipped,
}) {
  if (!hasUser) return AuthGate.login;
  // Primero completar el onboarding: la verificación no debe bloquearlo.
  if (!hasProfile || !onboardingCompleted) return AuthGate.onboarding;
  // Ya completó sus datos: se le recuerda verificar (con opción de posponer).
  if (!emailVerified && usesPasswordProvider && !verificationSkipped) {
    return AuthGate.verifyEmail;
  }
  return AuthGate.home;
}

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

        // Usuario logueado → primero completar el onboarding (datos básicos de
        // la cuenta). La verificación del correo se pide DESPUÉS: así el flujo
        // no se bloquea si el correo de Firebase no llega (p. ej. el proveedor
        // sigue en "developer mode" y la API responde OK sin entregarlo).
        final profileAsync = ref.watch(userProfileProvider);

        return profileAsync.when(
          data: (profile) {
            final gate = resolveAuthGate(
              hasUser: true,
              hasProfile: profile != null,
              onboardingCompleted: profile?.onboardingCompleted ?? false,
              emailVerified: user.emailVerified,
              usesPasswordProvider: _usesPasswordProvider(user),
              verificationSkipped:
                  ref.watch(skipEmailVerificationProvider) == user.uid,
            );
            switch (gate) {
              case AuthGate.onboarding:
                return const OnboardingScreen();
              case AuthGate.verifyEmail:
                return const VerifyEmailScreen();
              case AuthGate.home:
                return const AchievementWatcher(child: ProfileScreen());
              case AuthGate.login:
                return const LoginScreen();
            }
          },
          loading: () => Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          error: (e, _) => Scaffold(
            body: Center(child: Text('Error al cargar perfil: $e')),
          ),
        );
      },
      loading: () => Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  /// true si la cuenta puede verificar correo (tiene proveedor email/contraseña).
  /// Las de Google no necesitan esta pantalla.
  bool _usesPasswordProvider(User user) =>
      user.providerData.any((p) => p.providerId == 'password');
}