import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/strength_stats.dart';

/// Args: "exerciseId|name|days"  (evita problemas con records en family)
final exerciseStrengthStatsProvider =
FutureProvider.family<ExerciseStrengthStats, String>((ref, key) async {
  final parts = key.split('|');
  final exerciseId = parts.isNotEmpty ? parts[0] : '';
  final name = parts.length > 1 ? parts[1] : '';
  final days = parts.length > 2 ? int.tryParse(parts[2]) ?? 90 : 90;

  final sessions = await ref.watch(workoutHistoryProvider(days).future);
  return StrengthStatsBuilder.forExercise(
    sessions,
    exerciseId: exerciseId,
    exerciseName: name,
  );
});

String strengthStatsKey({
  required String exerciseId,
  required String name,
  required int days,
}) =>
    '$exerciseId|$name|$days';
