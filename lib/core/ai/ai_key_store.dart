import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clave de Gemini incluida por quien compila la app (opcional).
///
/// Se pasa al compilar con `--dart-define=GEMINI_API_KEY=AIza...`, de forma
/// que nunca queda escrita en el código fuente ni en el repositorio. Si está
/// presente, los usuarios no necesitan configurar ninguna clave.
///
/// Aviso: al viajar dentro del APK, cualquiera puede extraerla. Es un atajo
/// aceptable para una demo o una tesis, no para producción. La alternativa
/// correcta es una función en la nube que guarde la clave en el servidor.
const String kEmbeddedGeminiKey = String.fromEnvironment('GEMINI_API_KEY');

/// true si la app trae una clave de IA incorporada.
bool get hasEmbeddedAiKey => kEmbeddedGeminiKey.trim().isNotEmpty;

/// Elige qué clave usar: la del usuario manda; si no hay, la incorporada.
String? resolveAiKey({String? userKey, String? embedded}) {
  final u = userKey?.trim();
  if (u != null && u.isNotEmpty) return u;
  final e = embedded?.trim();
  if (e != null && e.isNotEmpty) return e;
  return null;
}

/// Guarda la clave que el usuario trae para el modelo de lenguaje.
///
/// Se guarda cifrada en el almacén seguro del sistema (Keystore/Keychain a
/// través de `flutter_secure_storage`): la clave nunca se sube a Firestore ni
/// se sincroniza entre dispositivos. Las versiones anteriores la guardaban sin
/// cifrar en `SharedPreferences`; al leerla se migra sola al almacén seguro.
class AiKeyStore {
  static const _key = 'ai.gemini_key_v1';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<String?> read() async {
    final value = await _storage.read(key: _key);
    if (value != null && value.trim().isNotEmpty) return value.trim();

    // Migración desde versiones anteriores (SharedPreferences sin cifrar).
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_key);
    if (legacy != null && legacy.trim().isNotEmpty) {
      await _storage.write(key: _key, value: legacy.trim());
      await prefs.remove(_key);
      return legacy.trim();
    }
    return null;
  }

  static Future<void> save(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return clear();
    await _storage.write(key: _key, value: trimmed);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _key);
    // Limpia también cualquier copia heredada sin cifrar.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Future<bool> hasKey() async => (await read()) != null;

  /// Hay IA disponible: o el usuario trajo clave, o la app incorpora una.
  static Future<bool> isConfigured() async =>
      hasEmbeddedAiKey || await hasKey();
}
