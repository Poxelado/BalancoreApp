import 'package:flutter/services.dart';

/// Límites y validación de entradas de toda la app.
///
/// Antes cada pantalla decidía por su cuenta si un campo tenía tope o no: casi
/// ninguno lo tenía, un campo numérico aceptaba letras y las listas (ejercicios,
/// series, comidas) crecían sin freno hasta saturar el teléfono. Aquí queda un
/// único lugar con los topes y los [TextInputFormatter]/validadores reutilizables.
///
/// Los valores de [InputLimits] también se aplican en los puntos donde se
/// agregan elementos a una lista, para no depender solo de la UI.
class InputLimits {
  InputLimits._();

  // Longitudes de texto (en caracteres, contando runas).
  static const int nameMax = 40;
  static const int usernameMin = 3;
  static const int usernameMax = 21;
  static const int emailMax = 254;
  static const int passwordMin = 6;
  static const int passwordMax = 72; // límite práctico de Firebase Auth
  static const int bioMax = 160;
  static const int notesMax = 500;
  static const int titleMax = 60;
  static const int searchMax = 80;
  static const int apiKeyMax = 200;
  static const int barcodeMax = 20;

  // Rangos numéricos.
  static const int ageMin = 12;
  static const int ageMax = 100;
  static const double weightKgMin = 30;
  static const double weightKgMax = 300;
  static const double heightCmMin = 100;
  static const double heightCmMax = 250;
  static const int caloriesMax = 10000;
  static const int macroGramsMax = 2000;
  static const int waterGlassesMax = 40;
  static const double sleepHoursMax = 24;
  static const int setRepsMin = 1;
  static const int setRepsMax = 100;
  static const double setWeightMax = 1000;

  // Topes de listas: el usuario no puede seguir agregando más allá.
  static const int maxExercisesPerRoutine = 20;
  static const int maxExercisesPerSession = 20;
  static const int maxWorkoutsPerRoutine = 14;
  static const int maxSetsPerExercise = 20;
  static const int maxMealsPerDay = 30;
  static const int maxRecipeIngredients = 30;
}

/// Valida / formatea texto y números. Todos los métodos devuelven `null`
/// cuando el valor es válido, igual que un `validator` de Flutter.
class Validators {
  Validators._();

  static final RegExp _username = RegExp(r'^[a-z0-9._]+$');
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Normaliza un usuario: sin `@`, minúsculas y sin espacios en los bordes.
  static String cleanUsername(String value) =>
      value.trim().replaceAll('@', '').toLowerCase();

  static String? username(String? value) {
    final v = cleanUsername(value ?? '');
    if (v.isEmpty) return 'El usuario es obligatorio';
    if (v.length < InputLimits.usernameMin) {
      return 'Mínimo ${InputLimits.usernameMin} caracteres';
    }
    if (v.length > InputLimits.usernameMax) {
      return 'Máximo ${InputLimits.usernameMax} caracteres';
    }
    if (!_username.hasMatch(v)) {
      return 'Solo a-z, 0-9, punto y guión bajo';
    }
    return null;
  }

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Ingresa tu correo';
    if (v.length > InputLimits.emailMax) return 'Correo demasiado largo';
    if (!_email.hasMatch(v)) return 'Correo no válido';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Ingresa una contraseña';
    if (v.length < InputLimits.passwordMin) {
      return 'Mínimo ${InputLimits.passwordMin} caracteres';
    }
    if (v.length > InputLimits.passwordMax) {
      return 'Máximo ${InputLimits.passwordMax} caracteres';
    }
    return null;
  }

  static String? required(String? value, String label) {
    if ((value ?? '').trim().isEmpty) return '$label es obligatorio';
    return null;
  }

  static String? maxLength(String? value, int max, String label) {
    if ((value ?? '').trim().length > max) return '$label: máximo $max caracteres';
    return null;
  }

  /// Entero dentro de [min, max]. Acepta separadores de miles opcionales.
  static String? intInRange(
    String? value, {
    required int min,
    required int max,
    String? label,
  }) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return '${label ?? 'Valor'} es obligatorio';
    final n = int.tryParse(v);
    if (n == null) return 'Ingresa un número válido';
    if (n < min || n > max) {
      return '${label ?? 'Valor'} debe estar entre $min y $max';
    }
    return null;
  }

  /// Decimal dentro de [min, max].
  static String? doubleInRange(
    String? value, {
    required double min,
    required double max,
    String? label,
  }) {
    final v = (value ?? '').trim().replaceAll(',', '.');
    if (v.isEmpty) return '${label ?? 'Valor'} es obligatorio';
    final n = double.tryParse(v);
    if (n == null) return 'Ingresa un número válido';
    if (n < min || n > max) {
      return '${label ?? 'Valor'} debe estar entre ${_fmt(min)} y ${_fmt(max)}';
    }
    return null;
  }

  static String _fmt(double n) =>
      n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toString();

  /// Convierte texto a `double` aceptando coma o punto decimal. Lanza
  /// [FormatException] con un mensaje claro (no el crudo de Dart) para que la
  /// UI pueda mostrarlo sin asustar al usuario.
  static double parseDouble(String? value, {String label = 'valor'}) {
    final v = (value ?? '').trim().replaceAll(',', '.');
    final n = double.tryParse(v);
    if (n == null) {
      throw FormatException('Ingresa un $label válido.');
    }
    return n;
  }

  /// Convierte texto a `int`. Lanza [FormatException] con mensaje claro.
  static int parseInt(String? value, {String label = 'valor'}) {
    final v = (value ?? '').trim();
    final n = int.tryParse(v);
    if (n == null) {
      throw FormatException('Ingresa un $label válido.');
    }
    return n;
  }
}

/// Formatters listos para usar en los `inputFormatters` de los campos.
class InputFormatters {
  InputFormatters._();

  /// Solo dígitos, con tope opcional de longitud.
  static List<TextInputFormatter> digits({int? maxLength}) => [
        FilteringTextInputFormatter.digitsOnly,
        if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ];

  /// Entero/decimal con un solo separador decimal y tope de longitud.
  static List<TextInputFormatter> decimal({required int maxLength}) => [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        _SingleDecimalFormatter(),
        LengthLimitingTextInputFormatter(maxLength),
      ];

  /// Texto libre con tope de longitud.
  static List<TextInputFormatter> text(int maxLength) => [
        LengthLimitingTextInputFormatter(maxLength),
      ];
}

/// Mensaje uniforme cuando se alcanza un tope de lista.
String listLimitMessage(String singular, int max) =>
    'Máximo $max $singular';

/// Deja pasar un único separador decimal (`.` o `,`).
class _SingleDecimalFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final dots = '.'.allMatches(text).length;
    final commas = ','.allMatches(text).length;
    if (dots + commas > 1) return oldValue;
    return newValue;
  }
}
