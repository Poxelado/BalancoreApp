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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  Future<void> _evaluate() async {
    if (_busy) return;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AchievementStats>>(achievementStatsProvider,
        (previous, next) {
      if (next.hasValue) _evaluate();
    });
    return widget.child;
  }
}
