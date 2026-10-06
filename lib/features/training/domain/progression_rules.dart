import '../../profile/domain/user_profile.dart';

/// Progresión por reglas simples (sobrecarga progresiva, sin IA).
class ProgressionSuggestion {
  /// Peso sugerido por serie (lo que conviene intentar hoy).
  final List<double> weights;
  /// Reps sugeridas por serie.
  final List<int> reps;
  /// Lo que hiciste la vez pasada (columna PREVIA).
  final List<double> previousWeights;
  final List<int> previousReps;
  /// Texto corto para la UI.
  final String message;
  /// true si recomienda subir peso respecto a la última sesión.
  final bool isIncrease;

  const ProgressionSuggestion({
    required this.weights,
    required this.reps,
    required this.previousWeights,
    required this.previousReps,
    required this.message,
    this.isIncrease = false,
  });

  String previaLabel(int setIndex) {
    if (previousWeights.isEmpty) return '—';
    final i = setIndex < previousWeights.length
        ? setIndex
        : previousWeights.length - 1;
    final w = previousWeights[i];
    final r = i < previousReps.length
        ? previousReps[i]
        : (previousReps.isNotEmpty ? previousReps.last : 0);
    if (w <= 0 && r <= 0) return '—';
    final ws = w == w.roundToDouble() ? '${w.toInt()}' : w.toStringAsFixed(1);
    return '$ws × $r';
  }

  double weightFor(int setIndex) {
    if (weights.isEmpty) return 0;
    return setIndex < weights.length ? weights[setIndex] : weights.last;
  }

  int repsFor(int setIndex) {
    if (reps.isEmpty) return 0;
    return setIndex < reps.length ? reps[setIndex] : reps.last;
  }
}

class ProgressionRules {
  /// Incremento estándar de peso (kg).
  static const double weightStep = 2.5;

  static bool _matches(WorkoutExerciseLog ex, String exerciseId, String? name) {
    if (exerciseId.isNotEmpty && ex.exerciseId == exerciseId) return true;
    if (name != null &&
        name.isNotEmpty &&
        ex.exerciseName.toLowerCase().trim() == name.toLowerCase().trim()) {
      return true;
    }
    return false;
  }

  /// Última vez que este ejercicio se registró con series completadas.
  static WorkoutExerciseLog? lastLoggedExercise(
      List<WorkoutSession> history,
      String exerciseId, {
        String? exerciseName,
      }) {
    final sorted = [...history]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    for (final session in sorted) {
      if (!session.completed) continue;
      for (final ex in session.exercises) {
        if (!_matches(ex, exerciseId, exerciseName)) continue;
        if (ex.sets.any((s) => s.completed && (s.weight > 0 || s.reps > 0))) {
          return ex;
        }
      }
    }
    return null;
  }

  /// Sugiere peso/reps según la última sesión.
  static ProgressionSuggestion? suggest({
    required String exerciseId,
    required int setCount,
    required int targetReps,
    required List<WorkoutSession> history,
    String? exerciseName,
  }) {
    if (setCount <= 0) return null;
    final prev = lastLoggedExercise(
      history,
      exerciseId,
      exerciseName: exerciseName,
    );
    if (prev == null) return null;

    final completed = prev.sets.where((s) => s.completed).toList();
    if (completed.isEmpty) return null;

    final prevW = <double>[];
    final prevR = <int>[];
    for (final s in prev.sets) {
      prevW.add(s.weight);
      prevR.add(s.reps);
    }

    final allHitReps = completed.every((s) => s.reps >= targetReps);
    final anyMissed = completed.any((s) => s.reps < targetReps);
    final avgWeight =
        completed.fold<double>(0, (a, s) => a + s.weight) / completed.length;

    final weights = <double>[];
    final repsList = <int>[];

    for (var i = 0; i < setCount; i++) {
      final base = i < prev.sets.length ? prev.sets[i] : completed.last;
      final baseW = base.weight > 0 ? base.weight : avgWeight;
      final baseR = base.reps > 0 ? base.reps : targetReps;

      if (allHitReps && baseW > 0) {
        weights.add(_roundStep(baseW + weightStep));
        repsList.add(targetReps);
      } else if (anyMissed) {
        weights.add(baseW);
        repsList.add(targetReps);
      } else {
        weights.add(baseW);
        repsList.add(baseR > 0 ? baseR : targetReps);
      }
    }

    final isIncrease = allHitReps && avgWeight > 0;
    final msg = isIncrease
        ? 'Última vez cumpliste las reps → prueba +${_fmt(weightStep)} kg'
        : anyMissed
        ? 'La vez pasada no llegaste a $targetReps reps → mantén el peso'
        : 'Basado en tu última sesión de este ejercicio';

    return ProgressionSuggestion(
      weights: weights,
      reps: repsList,
      previousWeights: prevW,
      previousReps: prevR,
      message: msg,
      isIncrease: isIncrease,
    );
  }

  static double _roundStep(double w) => (w * 2).round() / 2.0;

  static String _fmt(double w) {
    if (w == w.roundToDouble()) return '${w.toInt()}';
    return w.toStringAsFixed(1);
  }
}
