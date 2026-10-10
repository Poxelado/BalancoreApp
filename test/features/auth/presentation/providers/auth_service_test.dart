import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

    test('loginWithEmailOrUsername resuelve el usuario a correo', () async {
      await service.registerWithEmail(email: 'a@b.com', password: '123456');
      await service.signOut();

      final cred = await service.loginWithEmailOrUsername(
        identifier: 'pedro',
        password: '123456',
        resolveUsername: (u) async => 'a@b.com',
      );
      expect(cred!.user!.email, 'a@b.com');
    });

    test('loginWithEmailOrUsername lanza si el usuario no existe', () async {
      expect(
        () => service.loginWithEmailOrUsername(
          identifier: 'nadie',
          password: 'x',
          resolveUsername: (_) async => null,
        ),
        throwsA(isA<String>()),
      );
    });

    test('loginWithEmailOrUsername lanza si el identificador está vacío',
        () async {
      expect(
        () => service.loginWithEmailOrUsername(
          identifier: '   ',
          password: 'x',
          resolveUsername: (_) async => null,
        ),
        throwsA(isA<String>()),
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
