import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/presentation/providers/profile_provider.dart';
import 'achievements.dart';

/// Estadísticas acumuladas (all-time) que alimentan los logros.
final achievementStatsProvider = FutureProvider<AchievementStats>((ref) async {
  // Ventanas amplias para acercarnos a "de por vida"; el repo topea las
  // lecturas de entrenos en 120 documentos.
  final sessions = await ref.watch(workoutHistoryProvider(36500).future);
  final logs = await ref.watch(dailyLogsHistoryProvider(365).future);
  final weights = await ref.watch(weightHistoryProvider.future);
  final custom = await ref.watch(customRoutinesProvider.future);
  final today = await ref.watch(todayLogProvider.future);
  final session = await ref.watch(todayWorkoutSessionProvider.future);

  return AchievementStats.from(
    logs: logs,
    sessions: sessions,
    weights: weights,
    customRoutines: custom.length,
    todayLog: today,
    trainedToday: session?.completed ?? false,
  );
});
