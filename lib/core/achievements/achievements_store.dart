import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'achievements.dart';

/// Guarda qué logros ya se desbloquearon (para que una vez ganados queden a
/// color aunque el historial se recorte) y detecta los recién ganados para
/// lanzar el aviso emergente.
class AchievementUnlockNotifier extends StateNotifier<Set<String>> {
  AchievementUnlockNotifier() : super(<String>{});

  static const _unlockedKey = 'achievements_unlocked';
  static const _initKey = 'achievements_initialized';

  bool _loaded = false;

  Future<void> _ensureLoaded(AchievementStats stats) async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final initialized = prefs.getBool(_initKey) ?? false;
    final stored = prefs.getStringList(_unlockedKey)?.toSet() ?? <String>{};

    if (!initialized) {
      // Primera vez: damos por desbloqueado lo que ya corresponde, sin
      // lanzar avisos en cadena por logros viejos.
      final now = AchievementsCatalog.unlockedBy(stats)
          .map((a) => a.id)
          .toSet();
      state = now;
      await prefs.setStringList(_unlockedKey, now.toList());
      await prefs.setBool(_initKey, true);
      return;
    }
    state = stored;
  }

  /// Sincroniza con las estadísticas y devuelve sólo los logros nuevos.
  Future<List<Achievement>> sync(AchievementStats stats) async {
    await _ensureLoaded(stats);
    final unlocked = AchievementsCatalog.unlockedBy(stats).toList();
    final newOnes = unlocked.where((a) => !state.contains(a.id)).toList();
    if (newOnes.isEmpty) return const [];

    final next = {...state, for (final a in newOnes) a.id};
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedKey, next.toList());
    return newOnes;
  }

  /// Sólo para pruebas: marca todos como vistos sin avisar.
  Future<void> markSeen(Iterable<String> ids) async {
    final next = {...state, ...ids};
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedKey, next.toList());
    await prefs.setBool(_initKey, true);
  }
}

final achievementUnlockProvider =
    StateNotifierProvider<AchievementUnlockNotifier, Set<String>>(
  (ref) => AchievementUnlockNotifier(),
);
