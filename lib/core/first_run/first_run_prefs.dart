import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de primera ejecución (tutorial / tooltips).
class FirstRunPrefs {
  static const _tutorialKey = 'balancore_home_tutorial_v1';

  static Future<bool> isTutorialDone() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_tutorialKey) ?? false;
  }

  static Future<void> markTutorialDone() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_tutorialKey, true);
  }

  /// Solo para pruebas: vuelve a mostrar el tutorial.
  static Future<void> resetTutorial() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_tutorialKey);
  }
}
