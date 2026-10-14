import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Caché local de lecturas (JSON en `shared_preferences`).
///
/// Sirve para que la app muestre rutinas, comidas frecuentes, perfil, etc.
/// aunque no haya conexión. No es una cola: solo guarda la última lectura
/// buena para poder devolverla si Firestore falla.
class LocalCache {
  LocalCache({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> save(String key, Object? value) async {
    try {
      final prefs = await _instance();
      await prefs.setString(key, jsonEncode(value));
    } catch (_) {
      // Sin caché no pasa nada: la lectura en vivo sigue funcionando.
    }
  }

  Future<Object?> read(String key) async {
    try {
      final prefs = await _instance();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    try {
      final prefs = await _instance();
      await prefs.remove(key);
    } catch (_) {}
  }
}
