import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/errors/app_exception.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Mensaje genérico para no revelar si un correo existe.
  static const _loginError =
      'Correo o contraseña incorrectos. Si no tienes cuenta, regístrate.';

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Si el último intento de enviar el correo de verificación falló, aquí queda
  /// el motivo para que la UI pueda avisarlo (no rompe el registro).
  String? lastVerificationError;

  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Enviar correo de verificación (best-effort: no rompe el registro).
      lastVerificationError = null;
      try {
        await cred.user?.sendEmailVerification();
      } catch (e) {
        lastVerificationError = e is FirebaseAuthException
            ? _handleAuthException(e)
            : 'No se pudo enviar el correo de verificación.';
        debugPrint('auth: no se pudo enviar el correo de verificación: $e');
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e));
    }
  }

  /// Reenvía el correo de verificación al usuario actual.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e));
    }
  }

  /// Recarga el usuario y devuelve si ya verificó el correo.
  /// Fuerza el refresco del token para que el claim `email_verified` de las
  /// reglas de Firestore se actualice.
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null) return false;
    await refreshed.getIdToken(true);
    return refreshed.emailVerified;
  }

  /// Login con correo y contraseña.
  Future<UserCredential?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final raw = email.trim();
    if (raw.isEmpty) throw const ValidationException('Ingresa tu correo.');

    try {
      return await _auth.signInWithEmailAndPassword(
        email: raw,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        throw const AuthException(_loginError);
      }
      throw AuthException(_handleAuthException(e));
    }
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e));
    } catch (e) {
      throw AuthException('Error al iniciar con Google: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e));
    }
  }

  /// true si la cuenta usa correo/contraseña (y por tanto puede cambiarla).
  bool get hasPasswordProvider =>
      _auth.currentUser?.providerData
          .any((p) => p.providerId == 'password') ??
      false;

  String? get currentEmail => _auth.currentUser?.email;

  /// Reautentica con la contraseña actual. Requerido por Firebase antes de
  /// operaciones sensibles (cambiar contraseña o correo).
  Future<void> _reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No hay usuario autenticado');
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AuthException('Tu cuenta no tiene un correo asociado.');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _reauthenticate(currentPassword);
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthException('La contraseña actual no es correcta.');
      }
      if (e.code == 'weak-password') {
        throw const AuthException(
            'La nueva contraseña es muy débil (mínimo 6 caracteres).');
      }
      if (e.code == 'requires-recent-login') {
        throw const AuthException(
            'Por seguridad, vuelve a iniciar sesión e intenta de nuevo.');
      }
      throw AuthException(_handleAuthException(e));
    }
  }

  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final trimmed = newEmail.trim();
    if (trimmed == _auth.currentUser?.email) {
      throw const AuthException('Ese ya es tu correo actual.');
    }
    try {
      await _reauthenticate(currentPassword);
      final user = _auth.currentUser;
      if (user == null) throw const AuthException('No hay usuario autenticado');
      // verifyBeforeUpdateEmail envía un enlace de verificación al correo nuevo;
      // el cambio se aplica cuando el usuario lo confirma.
      await user.verifyBeforeUpdateEmail(trimmed);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthException('La contraseña actual no es correcta.');
      }
      if (e.code == 'email-already-in-use') {
        throw const AuthException('Ese correo ya está en uso por otra cuenta.');
      }
      if (e.code == 'invalid-email') {
        throw const AuthException('El correo no es válido.');
      }
      if (e.code == 'requires-recent-login') {
        throw const AuthException(
            'Por seguridad, vuelve a iniciar sesión e intenta de nuevo.');
      }
      throw AuthException(_handleAuthException(e));
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Borra el usuario de Firebase Auth.
  /// Debe llamarse ANTES de borrar Firestore solo si tiene éxito.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('No hay usuario autenticado');
    try {
      await user.delete();
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthException(
            'Por seguridad, cierra sesión, vuelve a iniciar sesión e intenta eliminar la cuenta de nuevo.');
      }
      throw AuthException(_handleAuthException(e));
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este correo ya está registrado.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres).';
      case 'user-not-found':
        return 'No existe una cuenta con este correo. Debes registrarte.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'invalid-credential':
        return 'Credenciales incorrectas. Si no tienes cuenta, regístrate.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.';
      case 'account-exists-with-different-credential':
        return 'Ya existe una cuenta con este correo usando otro método.';
      default:
        return 'Ocurrió un error: ${e.message}';
    }
  }
}
