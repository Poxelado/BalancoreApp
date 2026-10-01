import '../../profile/domain/user_profile.dart';

/// Punto de progreso de un ejercicio en una sesión.
class StrengthPoint {
  final DateTime date;
  final String sessionId;
  final double maxWeight;
  final int repsAtMax;
  final double volume;
  final int completedSets;

  const StrengthPoint({
    required this.date,
    required this.sessionId,
    required this.maxWeight,
    required this.repsAtMax,
    required this.volume,
    required this.completedSets,
  });
}

class ExerciseStrengthStats {
  final String exerciseId;
  final String exerciseName;
  final List<StrengthPoint> points;

  const ExerciseStrengthStats({
    required this.exerciseId,
    required this.exerciseName,
    required this.points,
  });

  double get bestWeight {
    if (points.isEmpty) return 0;
    return points.map((p) => p.maxWeight).reduce((a, b) => a > b ? a : b);
  }

  StrengthPoint? get bestWeightPoint {
    if (points.isEmpty) return null;
    return points.reduce((a, b) => a.maxWeight >= b.maxWeight ? a : b);
  }

  double get bestVolume {
    if (points.isEmpty) return 0;
    return points.map((p) => p.volume).reduce((a, b) => a > b ? a : b);
  }

  double get avgVolume {
    if (points.isEmpty) return 0;
    final s = points.fold<double>(0, (a, p) => a + p.volume);
    return s / points.length;
  }

  double get totalVolume => points.fold<double>(0, (a, p) => a + p.volume);

  List<StrengthPoint> inPeriod(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return points.where((p) => !p.date.isBefore(cutoff)).toList();
  }
}

class StrengthStatsBuilder {
  static Map<String, ExerciseStrengthStats> fromSessions(
      List<WorkoutSession> sessions,
      ) {
    final names = <String, String>{};
    final byEx = <String, List<StrengthPoint>>{};

    final ordered = List<WorkoutSession>.from(sessions)
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    for (final session in ordered) {
      for (final ex in session.exercises) {
        final id = ex.exerciseId.isNotEmpty
            ? ex.exerciseId
            : 'name:${ex.exerciseName}';
        names[id] = ex.exerciseName;

        double maxW = 0;
        int repsAtMax = 0;
        double volume = 0;
        int completed = 0;

        for (final s in ex.sets) {
          final w = s.weight;
          final r = s.reps;
          if (s.completed || w > 0) {
            volume += w * r;
            if (s.completed) completed++;
            if (w > maxW) {
              maxW = w;
              repsAtMax = r;
            }
          }
        }

        if (maxW <= 0 && completed == 0 && volume <= 0) continue;

        byEx.putIfAbsent(id, () => []);
        byEx[id]!.add(
          StrengthPoint(
            date: session.startedAt,
            sessionId: session.id,
            maxWeight: maxW,
            repsAtMax: repsAtMax,
            volume: volume,
            completedSets: completed,
          ),
        );
      }
    }

    return {
      for (final e in byEx.entries)
        e.key: ExerciseStrengthStats(
          exerciseId: e.key,
          exerciseName: names[e.key] ?? e.key,
          points: e.value,
        ),
    };
  }

  /// Siempre devuelve un objeto (lista vacía si no hay datos).
  static ExerciseStrengthStats forExercise(
      List<WorkoutSession> sessions, {
        required String exerciseId,
        String? exerciseName,
      }) {
    final all = fromSessions(sessions);

    if (all.containsKey(exerciseId)) {
      return all[exerciseId]!;
    }

    if (exerciseName != null && exerciseName.isNotEmpty) {
      final key = 'name:$exerciseName';
      if (all.containsKey(key)) {
        return all[key]!;
      }
      for (final s in all.values) {
        if (s.exerciseName.toLowerCase() == exerciseName.toLowerCase()) {
          return s;
        }
      }
    }

    return ExerciseStrengthStats(
      exerciseId: exerciseId,
      exerciseName: exerciseName ?? exerciseId,
      points: const [],
    );
  }
}
