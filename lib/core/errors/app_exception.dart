/// Jerarquía de excepciones de Balancore.
///
/// [toString] devuelve el mensaje mostrable, así que los sitios que ya hacen
/// `Text('$e')` siguen mostrando el texto correcto sin cambios. La ventaja de
/// tiparlas es poder distinguirlas y manejarlas por tipo (`on AuthException`).
library;

/// Base de todas las excepciones de la app.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  /// Mensaje apto para mostrar al usuario.
  final String message;

  /// Código técnico opcional (para logs / diagnóstico).
  final String? code;

  @override
  String toString() => message;
}

/// Fallos de autenticación: registro, login, recuperación, borrado de cuenta.
class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

/// Datos inválidos del usuario: validaciones de formularios e inputs.
class ValidationException extends AppException {
  const ValidationException(super.message, {super.code});
}

/// Fallos al leer/escribir datos (Firestore, repositorios).
class DataException extends AppException {
  const DataException(super.message, {super.code});
}

/// Fallos de red o de servicios externos (p. ej. Open Food Facts).
class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}
