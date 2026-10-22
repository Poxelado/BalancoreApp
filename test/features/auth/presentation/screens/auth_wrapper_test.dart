import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/auth/presentation/screens/auth_wrapper.dart';

void main() {
  AuthGate gate({
    bool hasUser = true,
    bool hasProfile = true,
    bool onboardingCompleted = true,
    bool emailVerified = true,
    bool usesPasswordProvider = true,
    bool verificationSkipped = false,
  }) =>
      resolveAuthGate(
        hasUser: hasUser,
        hasProfile: hasProfile,
        onboardingCompleted: onboardingCompleted,
        emailVerified: emailVerified,
        usesPasswordProvider: usesPasswordProvider,
        verificationSkipped: verificationSkipped,
      );

  test('sin usuario → login', () {
    expect(gate(hasUser: false), AuthGate.login);
  });

  test('sin perfil → onboarding (no bloquea por verificación)', () {
    expect(
      gate(hasProfile: false, onboardingCompleted: false, emailVerified: false),
      AuthGate.onboarding,
    );
  });

  test('onboarding pendiente + correo sin verificar → onboarding', () {
    expect(
      gate(onboardingCompleted: false, emailVerified: false),
      AuthGate.onboarding,
    );
  });

  test('onboarding hecho + correo sin verificar → recordatorio de verificación', () {
    expect(
      gate(onboardingCompleted: true, emailVerified: false),
      AuthGate.verifyEmail,
    );
  });

  test('onboarding hecho + sin verificar pero pospuesto → home', () {
    expect(
      gate(
        onboardingCompleted: true,
        emailVerified: false,
        verificationSkipped: true,
      ),
      AuthGate.home,
    );
  });

  test('cuenta de Google (sin provider password) → home aunque no verifique', () {
    expect(
      gate(
        onboardingCompleted: true,
        emailVerified: false,
        usesPasswordProvider: false,
      ),
      AuthGate.home,
    );
  });

  test('todo completo y verificado → home', () {
    expect(gate(), AuthGate.home);
  });
}
