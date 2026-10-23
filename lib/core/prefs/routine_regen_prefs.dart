import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de la confirmación al regenerar una rutina generada.
///
/// Evita repetir el diálogo "¿Generar otra rutina?" cuando el usuario marca
/// "No volver a preguntar".
class RoutineRegenPrefs {
  static const _dontAskKey = 'routine_regen_dont_ask_v1';

  /// true = el usuario pidió no volver a ver la confirmación.
  static Future<bool> dontAsk() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_dontAskKey) ?? false;
  }

  static Future<void> setDontAsk(bool value) async {
    final p = await SharedPreferences.getInstance();
    if (value) {
      await p.setBool(_dontAskKey, true);
    } else {
      await p.remove(_dontAskKey);
    }
  }
}
