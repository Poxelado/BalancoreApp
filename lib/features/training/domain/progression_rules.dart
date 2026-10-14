import '../../profile/domain/user_profile.dart';

/// Progresión por reglas: doble progresión (reps → peso), sin IA.
/// Las subidas se confirman tras **2 entrenamientos** del mismo ejercicio.
class ProgressionSuggestion {
  final List<double> weights;
  final List<int> reps;
  final List<double> previousWeights;
  final List<int> previousReps;
  final String message;
  final bool isIncrease;
  final bool isRepIncrease;

  const ProgressionSuggestion({
    required this.weights,
    required this.reps,
    required this.previousWeights,
    required this.previousReps,
    required this.message,
    this.isIncrease = false,
    this.isRepIncrease = false,
  });

  String previaLabel(int setIndex) {
    if (previousWeights.isEmpty && previousReps.isEmpty) return '—';
    final wi = previousWeights.isEmpty
        ? 0
        : (setIndex < previousWeights.length
        ? setIndex
        : previousWeights.length - 1);
    final ri = previousReps.isEmpty
        ? 0
        : (setIndex < previousReps.length
        ? setIndex
        : previousReps.length - 1);
    final w = previousWeights.isEmpty ? 0.0 : previousWeights[wi];
    final r = previousReps.isEmpty ? 0 : previousReps[ri];
    if (w <= 0 && r <= 0) return '—';
    if (w <= 0) return '× $r';
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
  static const double weightStep = 2.5;
  static const double bigWeightStep = 5.0;
  static const int repFloor = 6;
  static const int repCeiling = 12;
  static const int highRepThreshold = 15;

  /// Cuántas sesiones seguidas hacen falta para proponer subida.
  static const int sessionsToConfirm = 2;

  static bool _matches(WorkoutExerciseLog ex, String exerciseId, String? name) {
    if (exerciseId.isNotEmpty && ex.exerciseId == exerciseId) return true;
    if (name != null &&
        name.isNotEmpty &&
        ex.exerciseName.toLowerCase().trim() == name.toLowerCase().trim()) {
      return true;
    }
    return false;
  }

  /// Hasta [limit] logs completados del ejercicio (más reciente primero).
  static List<WorkoutExerciseLog> recentLoggedExercises(
      List<WorkoutSession> history,
      String exerciseId, {
        String? exerciseName,
        int limit = 5,
      }) {
    final sorted = [...history]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final out = <WorkoutExerciseLog>[];
    for (final session in sorted) {
      if (!session.completed) continue;
      for (final ex in session.exercises) {
        if (!_matches(ex, exerciseId, exerciseName)) continue;
        if (ex.sets.any((s) => s.completed && (s.weight > 0 || s.reps > 0))) {
          out.add(ex);
          if (out.length >= limit) return out;
        }
      }
    }
    return out;
  }

  static WorkoutExerciseLog? lastLoggedExercise(
      List<WorkoutSession> history,
      String exerciseId, {
        String? exerciseName,
      }) {
    final list = recentLoggedExercises(
      history,
      exerciseId,
      exerciseName: exerciseName,
      limit: 1,
    );
    return list.isEmpty ? null : list.first;
  }

  static int _minReps(List<WorkoutSetLog> completed) =>
      completed.map((s) => s.reps).reduce((a, b) => a < b ? a : b);

  static double _avgWeight(List<WorkoutSetLog> completed) =>
      completed.fold<double>(0, (a, s) => a + s.weight) / completed.length;

  static double _roundStep(double w) {
    if (w <= 0) return 0;
    return (w * 2).round() / 2.0;
  }

  static String _fmt(double w) {
    if (w == w.roundToDouble()) return '${w.toInt()}';
    return w.toStringAsFixed(1);
  }

  /// PREVIA = última sesión. Subida de peso/reps solo si las últimas
  /// [sessionsToConfirm] sesiones cumplen el criterio (menos agresivo).
  static ProgressionSuggestion? suggest({
    required String exerciseId,
    required int setCount,
    required int targetReps,
    required List<WorkoutSession> history,
    String? exerciseName,
  }) {
    if (setCount <= 0) return null;

    final recent = recentLoggedExercises(
      history,
      exerciseId,
      exerciseName: exerciseName,
      limit: sessionsToConfirm,
    );
    if (recent.isEmpty) return null;

    final prev = recent.first; // más reciente
    final completed = prev.sets.where((s) => s.completed).toList();
    if (completed.isEmpty) return null;

    final prevW = <double>[];
    final prevR = <int>[];
    for (final s in prev.sets) {
      prevW.add(s.weight);
      prevR.add(s.reps);
    }

    final floor = (targetReps >= 5 && targetReps <= 10) ? targetReps : repFloor;
    final minLast = _minReps(completed);
    final avgW = _avgWeight(completed);
    final hasLoad = avgW > 0;

    // ¿Hay 2 sesiones que confirmen la misma dirección?
    final confirmed = recent.length >= sessionsToConfirm;
    var bothHigh = false;
    var bothCeiling = false;
    var bothSolid = false;
    if (confirmed) {
      final older = recent[1].sets.where((s) => s.completed).toList();
      if (older.isNotEmpty) {
        final minOlder = _minReps(older);
        bothHigh =
            minLast >= highRepThreshold && minOlder >= highRepThreshold;
        bothCeiling = minLast >= repCeiling && minOlder >= repCeiling;
        bothSolid = minLast >= floor && minOlder >= floor;
      }
    }

    final weights = <double>[];
    final repsList = <int>[];
    var isIncrease = false;
    var isRepIncrease = false;
    late String message;

    void fillSameAsLast() {
      for (var i = 0; i < setCount; i++) {
        final base = i < completed.length ? completed[i] : completed.last;
        final baseW = base.weight > 0 ? base.weight : avgW;
        weights.add(baseW);
        repsList.add(base.reps > 0 ? base.reps : floor);
      }
    }

    // RPE de la última sesión: si quedó al límite, no se sube (evita forzar
    // una progresión sobre un esfuerzo ya máximo).
    final lastRpe = prev.rpe;
    final tooHard = lastRpe != null && lastRpe >= 9;

    // El ejercicio se trabajó al límite → consolidar antes de progresar
    if (tooHard && (bothHigh || bothCeiling || bothSolid)) {
      message =
          'Última sesión al límite (RPE $lastRpe) → consolida el peso antes de subir';
      fillSameAsLast();
    }
    // Sin 2 sesiones aún → no subir, solo repetir
    else if (!confirmed) {
      message =
      'Repite lo anterior. Tras $sessionsToConfirm entrenos del ejercicio sugeriremos progresión';
      fillSameAsLast();
    }
    // 2× muy altas reps → +5 kg
    else if (bothHigh) {
      isIncrease = true;
      final double step = hasLoad ? bigWeightStep : 0.0;
      message = hasLoad
          ? '2 sesiones con $highRepThreshold+ reps → +${_fmt(step)} kg y $floor reps'
          : '2 sesiones con muchas reps → añade carga; meta $floor-$repCeiling';
      for (var i = 0; i < setCount; i++) {
        final base = i < completed.length ? completed[i] : completed.last;
        final baseW = base.weight > 0 ? base.weight : avgW;
        weights.add(hasLoad ? _roundStep(baseW + step) : 0.0);
        repsList.add(floor);
      }
    }
    // 2× techo 12 → +2.5 kg
    else if (bothCeiling) {
      isIncrease = true;
      final double step = hasLoad ? weightStep : 0.0;
      message = hasLoad
          ? '2 sesiones a $repCeiling reps → +${_fmt(step)} kg y $floor reps'
          : '2 sesiones al techo de reps → añade peso; meta $floor-$repCeiling';
      for (var i = 0; i < setCount; i++) {
        final base = i < completed.length ? completed[i] : completed.last;
        final baseW = base.weight > 0 ? base.weight : avgW;
        weights.add(hasLoad ? _roundStep(baseW + step) : 0.0);
        repsList.add(floor);
      }
    }
    // 2× sólidas bajo el techo → +1 rep
    else if (bothSolid && minLast < repCeiling) {
      isRepIncrease = true;
      message =
      '2 sesiones sólidas → +1 rep (hasta $repCeiling), mismo peso';
      for (var i = 0; i < setCount; i++) {
        final base = i < completed.length ? completed[i] : completed.last;
        final baseW = base.weight > 0 ? base.weight : avgW;
        final nextReps = (base.reps + 1).clamp(floor, repCeiling);
        weights.add(baseW);
        repsList.add(nextReps);
      }
    }
    // Última sesión floja o aún no hay patrón → mantener
    else {
      if (minLast < floor) {
        message = 'Mantén peso y apunta a $floor-$repCeiling reps';
      } else {
        message =
        'Repite peso y reps. La subida se confirma tras $sessionsToConfirm sesiones fuertes';
      }
      fillSameAsLast();
    }

    return ProgressionSuggestion(
      weights: weights,
      reps: repsList,
      previousWeights: prevW,
      previousReps: prevR,
      message: message,
      isIncrease: isIncrease,
      isRepIncrease: isRepIncrease,
    );
  }
}
