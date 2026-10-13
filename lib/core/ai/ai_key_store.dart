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
/// Se guarda solo en el dispositivo (SharedPreferences): la clave nunca se
/// sube a Firestore ni se sincroniza entre dispositivos. Es el mismo criterio
/// que el resto de preferencias locales de la app.
class AiKeyStore {
  static const _key = 'ai.gemini_key_v1';

  static Future<String?> read() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  static Future<void> save(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, key.trim());
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }

  static Future<bool> hasKey() async => (await read()) != null;

  /// Hay IA disponible: o el usuario trajo clave, o la app incorpora una.
  static Future<bool> isConfigured() async =>
      hasEmbeddedAiKey || await hasKey();
}