import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:balancore/core/errors/app_exception.dart';
import 'package:balancore/features/auth/presentation/providers/auth_provider.dart';

class _FakeGoogleSignIn extends GoogleSignIn {
  @override
  Future<GoogleSignInAccount?> signIn() async => null;

  @override
  Future<GoogleSignInAccount?> signOut() async => null;
}

void main() {
  late MockFirebaseAuth auth;
  late GoogleSignIn google;
  late AuthService service;

  setUp(() {
    auth = MockFirebaseAuth();
    google = _FakeGoogleSignIn();
    service = AuthService(auth: auth, googleSignIn: google);
  });

  group('registro y login', () {
    test('registerWithEmail recorta el correo y devuelve credencial', () async {
      final cred = await service.registerWithEmail(
        email: '  a@b.com ',
        password: '123456',
      );
      expect(cred!.user!.email, 'a@b.com');
      expect(service.currentUser, isNotNull);
    });

    test('loginWithEmail funciona tras registrar', () async {
      await service.registerWithEmail(email: 'a@b.com', password: '123456');
      await service.signOut();

      final cred = await service.loginWithEmail(
        email: 'a@b.com',
        password: '123456',
      );
      expect(cred!.user!.email, 'a@b.com');
      expect(service.currentUser, isNotNull);
    });

    test('loginWithEmail lanza si el correo está vacío', () async {
      expect(
        () => service.loginWithEmail(email: '   ', password: 'x'),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('sesión', () {
    test('signOut deja al usuario sin sesión', () async {
      await service.registerWithEmail(email: 'a@b.com', password: '123456');
      expect(service.currentUser, isNotNull);

      await service.signOut();
      expect(service.currentUser, isNull);
    });

    test('resetPassword no lanza con correo válido', () async {
      await service.registerWithEmail(email: 'a@b.com', password: '123456');
      await service.resetPassword('a@b.com');
    });
  });

  group('Google', () {
    test('signInWithGoogle devuelve null si el usuario cancela', () async {
      final result = await service.signInWithGoogle();
      expect(result, isNull);
    });
  });
}
