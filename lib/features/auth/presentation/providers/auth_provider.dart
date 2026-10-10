import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Login con correo O nombre de usuario.
  /// [resolveUsername] devuelve el email asociado al username, o null.
  Future<UserCredential?> loginWithEmailOrUsername({
    required String identifier,
    required String password,
    required Future<String?> Function(String username) resolveUsername,
  }) async {
    final raw = identifier.trim();
    if (raw.isEmpty) throw 'Ingresa tu correo o usuario.';

    String email;
    if (raw.contains('@')) {
      email = raw;
    } else {
      final username = raw.replaceAll('@', '').toLowerCase();
      final resolved = await resolveUsername(username);
      if (resolved == null || resolved.isEmpty) {
        throw 'No existe una cuenta con ese usuario. Debes registrarte.';
      }
      email = resolved;
    }

    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'wrong-password' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        throw 'No existe una cuenta con esas credenciales o la contraseña es incorrecta. Si eliminaste la cuenta, regístrate de nuevo.';
      }
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return loginWithEmailOrUsername(
      identifier: email,
      password: password,
      resolveUsername: (_) async => null,
    );
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
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Error al iniciar con Google: $e';
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
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
    if (user == null) throw 'No hay usuario autenticado';
    try {
      await user.delete();
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw 'Por seguridad, cierra sesión, vuelve a iniciar sesión e intenta eliminar la cuenta de nuevo.';
      }
      throw _handleAuthException(e);
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
