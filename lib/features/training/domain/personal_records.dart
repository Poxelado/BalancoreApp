import '../../profile/domain/user_profile.dart';

/// Marca de récord personal (PR) lograda en una serie.
enum PrKind {
  /// Peso más alto levantado en una serie.
  weight,
  /// Volumen (peso × reps) más alto en una serie.
  volume,
  /// 1RM estimado (Epley) más alto en una serie.
  e1rm,
}

/// Un récord personal detectado.
class PersonalRecord {
  final String exerciseId;
  final String exerciseName;
  final PrKind kind;

  /// Valor que se alcanzó (kg, o kg·reps para volumen).
  final double value;
  /// Récord anterior del que se superó (0 si es el primero registrado).
  final double previous;

  const PersonalRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.kind,
    required this.value,
    this.previous = 0,
  });

  bool get isFirst => previous <= 0;

  String get label => switch (kind) {
        PrKind.weight => 'Peso',
        PrKind.volume => 'Volumen',
        PrKind.e1rm => '1RM',
      };
}

/// 1RM estimado con la fórmula de Epley. Misma que la de la UI.
double? epley(double weight, int reps) {
  if (weight <= 0 || reps <= 0) return null;
  if (reps <= 1) return weight;
  return weight * (1 + reps / 30);
}

/// Detecta los récords de [session] comparando con [history] (todo lo anterior).
///
/// Ignora calentamiento y series al fallo: un peso alto en una serie de
/// calentamiento no es un récord, igual que una serie al fallo no indica
/// cuánto podría haber movido.
List<PersonalRecord> detectPersonalRecords(
  WorkoutSession session,
  List<WorkoutSession> history,
) {
  // Máximos previos por ejercicio.
  final prevWeight = <String, double>{};
  final prevVolume = <String, double>{};
  final prevE1rm = <String, double>{};
  for (final s in history) {
    if (s.id == session.id) continue;
    for (final ex in s.exercises) {
      final key = ex.exerciseId.isNotEmpty ? ex.exerciseId : ex.exerciseName;
      for (final set in ex.sets) {
        if (!set.completed || !set.countsForRecord) continue;
        prevWeight[key] = _max(prevWeight[key], set.weight);
        prevVolume[key] = _max(prevVolume[key], set.weight * set.reps);
        final e = epley(set.weight, set.reps);
        if (e != null) prevE1rm[key] = _max(prevE1rm[key], e);
      }
    }
  }

  final records = <PersonalRecord>[];
  for (final ex in session.exercises) {
    final key = ex.exerciseId.isNotEmpty ? ex.exerciseId : ex.exerciseName;
    for (final set in ex.sets) {
      if (!set.completed || !set.countsForRecord) continue;
      if (set.weight <= 0) continue;
      final volume = set.weight * set.reps;

      if (set.weight > (prevWeight[key] ?? 0)) {
        records.add(PersonalRecord(
          exerciseId: ex.exerciseId,
          exerciseName: ex.exerciseName,
          kind: PrKind.weight,
          value: set.weight,
          previous: prevWeight[key] ?? 0,
        ));
      }
      if (set.reps > 0 && volume > (prevVolume[key] ?? 0)) {
        records.add(PersonalRecord(
          exerciseId: ex.exerciseId,
          exerciseName: ex.exerciseName,
          kind: PrKind.volume,
          value: volume,
          previous: prevVolume[key] ?? 0,
        ));
      }
      final e1 = epley(set.weight, set.reps);
      if (e1 != null && e1 > (prevE1rm[key] ?? 0)) {
        records.add(PersonalRecord(
          exerciseId: ex.exerciseId,
          exerciseName: ex.exerciseName,
          kind: PrKind.e1rm,
          value: e1,
          previous: prevE1rm[key] ?? 0,
        ));
      }
    }
  }
  return records;
}

double _max(double? a, double b) => (a ?? 0) > b ? a! : b;

/// Marca de récord personal en una serie de la sesión en curso.
///
/// Se evalúa al completar la serie contra [history]; devuelve null si no es
/// récord. Se usa para el badge "PR" en vivo.
List<PersonalRecord> recordsForSet({
  required WorkoutExerciseLog exercise,
  required WorkoutSetLog set,
  required List<WorkoutSession> history,
}) {
  final probe = WorkoutSession(
    id: '__probe__',
    dayName: '',
    title: '',
    startedAt: DateTime.now(),
    exercises: [
      exercise.copyWith(
        sets: [
          WorkoutSetLog(
            setNumber: set.setNumber,
            weight: set.weight,
            reps: set.reps,
            completed: true,
            type: set.type,
          ),
        ],
      ),
    ],
  );
  return detectPersonalRecords(probe, history);
}