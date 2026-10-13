import 'package:shared_preferences/shared_preferences.dart';

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
}