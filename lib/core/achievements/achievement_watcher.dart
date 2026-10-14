import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'achievement_toast.dart';
import 'achievements.dart';
import 'achievements_provider.dart';
import 'achievements_store.dart';

/// Vigila las estadísticas y, cuando se desbloquea un logro nuevo, lanza el
/// aviso emergente con sonido. Envuelve la app (una sola instancia).
class AchievementWatcher extends ConsumerStatefulWidget {
  const AchievementWatcher({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AchievementWatcher> createState() => _AchievementWatcherState();
}

class _AchievementWatcherState extends ConsumerState<AchievementWatcher> {
  bool _busy = false;
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  Future<void> _evaluate() async {
    // Si ya estamos evaluando, marcamos para repetir con el valor más reciente
    // (una invalidación de datos emite primero AsyncLoading con el valor viejo
    // y luego AsyncData con el nuevo; no queremos perder ese segundo aviso).
    if (_busy) {
      _pending = true;
      return;
    }
    final stats = ref.read(achievementStatsProvider).valueOrNull;
    if (stats == null) return;
    _busy = true;
    try {
      final newOnes =
          await ref.read(achievementUnlockProvider.notifier).sync(stats);
      for (final a in newOnes) {
        if (!mounted) break;
        await showAchievementToast(context, a);
        await Future.delayed(const Duration(milliseconds: 250));
      }
    } finally {
      _busy = false;
      if (_pending) {
        _pending = false;
        _evaluate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AchievementStats>>(achievementStatsProvider,
        (previous, next) {
      // Sólo evaluamos con datos ya resueltos (evita usar el valor viejo que
      // Riverpod conserva durante un refresco).
      if (next.hasValue && !next.isLoading) _evaluate();
    });
    return widget.child;
  }
}
