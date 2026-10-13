import '../../profile/domain/user_profile.dart';

/// Métricas de una sesión terminada para la pantalla de resumen.
class SessionStats {
  final int durationSeconds;
  final int totalSets;
  final int completedSets;

  /// Volumen total (peso × reps), sin contar las series de calentamiento.
  final double totalVolume;

  /// Volumen por grupo muscular, de mayor a menor.
  final Map<String, double> volumeByMuscle;

  /// Volumen de la sesión anterior comparable (null si no hay ninguna).
  final double? previousVolume;

  /// Diferencia de volumen frente a la anterior, en kg.
  final double? volumeDelta;

  /// Diferencia de duración frente a la anterior, en segundos.
  final int? durationDelta;

  const SessionStats({
    required this.durationSeconds,
    required this.totalSets,
    required this.completedSets,
    required this.totalVolume,
    required this.volumeByMuscle,
    this.previousVolume,
    this.volumeDelta,
    this.durationDelta,
  });

  bool get hasPrevious => previousVolume != null;

  /// Variación porcentual del volumen respecto a la sesión anterior.
  double? get volumeDeltaPercent {
    final prev = previousVolume;
    if (prev == null || prev <= 0) return null;
    return (volumeDelta ?? 0) / prev * 100;
  }

  bool get volumeImproved => (volumeDelta ?? 0) > 0;
  bool get durationImproved => (durationDelta ?? 0) > 0;
}

/// Calcula las métricas de [session].
///
/// [history] debe ser el historial completo; se usa para buscar la sesión
/// anterior comparable (la más reciente que comparta algún ejercicio).
SessionStats computeSessionStats(
  WorkoutSession session,
  List<WorkoutSession> history,
) {
  var volume = 0.0;
  final byMuscle = <String, double>{};

  for (final ex in session.exercises) {
    final muscle = ex.muscleGroup.trim().isEmpty
        ? 'Otros'
        : ex.muscleGroup.trim();
    for (final s in ex.sets) {
      if (!s.completed || s.isWarmup) continue;
      final v = s.weight * s.reps;
      volume += v;
      byMuscle[muscle] = (byMuscle[muscle] ?? 0) + v;
    }
  }

  final sorted = Map<String, double>.fromEntries(
    byMuscle.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)),
  );

  final previous = _previousComparable(session, history);
  final prevVolume = previous == null ? null : _volumeOf(previous);

  return SessionStats(
    durationSeconds: session.elapsedSeconds,
    totalSets: session.totalSets,
    completedSets: session.completedSets,
    totalVolume: volume,
    volumeByMuscle: sorted,
    previousVolume: prevVolume,
    volumeDelta: prevVolume == null ? null : volume - prevVolume,
    durationDelta: previous == null
        ? null
        : session.elapsedSeconds - previous.elapsedSeconds,
  );
}

double _volumeOf(WorkoutSession s) {
  var v = 0.0;
  for (final ex in s.exercises) {
    for (final set in ex.sets) {
      if (set.completed && !set.isWarmup) v += set.weight * set.reps;
    }
  }
  return v;
}

String _keyOf(WorkoutExerciseLog e) =>
    e.exerciseId.isNotEmpty ? e.exerciseId : e.exerciseName;

/// Sesión anterior comparable: la más reciente terminada que trained algún
/// ejercicio de [session]. Comparar contra una rutina sin relación no
/// significa nada.
WorkoutSession? _previousComparable(
  WorkoutSession session,
  List<WorkoutSession> history,
) {
  final keys = session.exercises.map(_keyOf).toSet();
  final candidates = history
      .where((s) =>
          s.id != session.id &&
          s.startedAt.isBefore(session.startedAt) &&
          s.exercises.any((e) => keys.contains(_keyOf(e))))
      .toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return candidates.isEmpty ? null : candidates.first;
}