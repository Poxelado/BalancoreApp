import '../../profile/domain/user_profile.dart';

/// Progresión por reglas simples (sobrecarga progresiva, sin IA).
class ProgressionSuggestion {
  /// Peso sugerido por serie (índice = serie).
  final List<double> weights;
  /// Reps sugeridas por serie.
  final List<int> reps;
  /// Texto corto para la UI.
  final String message;
  /// true si recomienda subir peso respecto a la última sesión.
  final bool isIncrease;

  const ProgressionSuggestion({
    required this.weights,
    required this.reps,
    required this.message,
    this.isIncrease = false,
  });
}

class ProgressionRules {
  /// Incremento estándar de peso (kg).
  static const double weightStep = 2.5;

  /// Busca la última sesión completada que tenga el ejercicio con series hechas.
  static WorkoutExerciseLog? lastLoggedExercise(
      List<WorkoutSession> history,
      String exerciseId,
      ) {
    // history suele venir más reciente primero
    final sorted = [...history]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    for (final session in sorted) {
      if (!session.completed) continue;
      for (final ex in session.exercises) {
        if (ex.exerciseId != exerciseId) continue;
        if (ex.sets.any((s) => s.completed && (s.weight > 0 || s.reps > 0))) {
          return ex;
        }
      }
    }
    return null;
  }

  /// Sugiere peso/reps para [setCount] series según rendimiento anterior.
  static ProgressionSuggestion? suggest({
    required String exerciseId,
    required int setCount,
    required int targetReps,
    required List<WorkoutSession> history,
  }) {
    if (setCount <= 0) return null;
    final prev = lastLoggedExercise(history, exerciseId);
    if (prev == null) return null;

    final completed = prev.sets.where((s) => s.completed).toList();
    if (completed.isEmpty) return null;

    final allHitReps = completed.every((s) => s.reps >= targetReps);
    final anyMissed = completed.any((s) => s.reps < targetReps);
    final avgWeight = completed.fold<double>(0, (a, s) => a + s.weight) /
        completed.length;

    final weights = <double>[];
    final repsList = <int>[];

    for (var i = 0; i < setCount; i++) {
      final base = i < prev.sets.length ? prev.sets[i] : completed.last;
      final baseW = base.weight > 0 ? base.weight : avgWeight;
      final baseR = base.reps > 0 ? base.reps : targetReps;

      if (allHitReps && baseW > 0) {
        // Cumplió reps en todas las series → subir peso
        weights.add(_roundStep(baseW + weightStep));
        repsList.add(targetReps);
      } else if (anyMissed) {
        // No llegó a las reps → mantener peso, mismo objetivo
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
      message: msg,
      isIncrease: isIncrease,
    );
  }

  static double _roundStep(double w) {
    // Redondea al múltiplo de 0.5 más cercano (soporta 1.25 si se desea)
    return (w * 2).round() / 2.0;
  }

  static String _fmt(double w) {
    if (w == w.roundToDouble()) return '${w.toInt()}';
    return w.toStringAsFixed(1);
  }
}
