import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/strength_stats.dart';

/// Stats de fuerza de un ejercicio (últimos days días de historial cargado).
final exerciseStrengthStatsProvider = FutureProvider.family<
    ExerciseStrengthStats, ({String exerciseId, String name, int days})>(
      (ref, args) async {
      final sessions = await ref.watch(workoutHistoryProvider(args.days).future);
    return StrengthStatsBuilder.forExercise(
      sessions,
      exerciseId: args.exerciseId,
      exerciseName: args.name,
    );
  },
);
