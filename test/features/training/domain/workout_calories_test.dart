import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/training/domain/workout_calories.dart';

WorkoutSession _session({
  String title = 'Pecho y tríceps',
  String dayName = 'Día 1',
  int elapsedSeconds = 3600,
  List<WorkoutExerciseLog> exercises = const [],
}) {
  return WorkoutSession(
    id: 's1',
    dayName: dayName,
    title: title,
    startedAt: DateTime(2026, 1, 1, 8),
    elapsedSeconds: elapsedSeconds,
    exercises: exercises,
  );
}

WorkoutExerciseLog _ex({
  String name = 'Press banca',
  String muscle = 'Pecho',
  int? rpe,
}) {
  return WorkoutExerciseLog(
    exerciseId: 'e1',
    exerciseName: name,
    muscleGroup: muscle,
    rpe: rpe,
  );
}

void main() {
  group('estimateWorkoutMet', () {
    test('fuerza sin RPE usa el MET por defecto (5.0)', () {
      expect(estimateWorkoutMet(_session()), 5.0);
    });

    test('sube el MET según el RPE medio', () {
      final s = _session(exercises: [_ex(rpe: 8), _ex(rpe: 8)]);
      expect(estimateWorkoutMet(s), closeTo(5.4, 0.001));
    });

    test('RPE bajo no baja del mínimo (3.5)', () {
      final s = _session(exercises: [_ex(rpe: 4)]);
      expect(estimateWorkoutMet(s), 3.5);
    });

    test('detecta cardio por título/músculo y usa MET 8.0', () {
      expect(estimateWorkoutMet(_session(title: 'Cardio HIIT')), 8.0);
      expect(
        estimateWorkoutMet(_session(exercises: [_ex(muscle: 'Correr')])),
        8.0,
      );
    });
  });

  group('estimateWorkoutCalories', () {
    test('1 h de fuerza a 70 kg rinde ~368 kcal', () {
      final s = _session(elapsedSeconds: 3600);
      expect(estimateWorkoutCalories(s, weightKg: 70), 368);
    });

    test('30 min de cardio a 70 kg rinde 294 kcal', () {
      final s = _session(title: 'Cardio', elapsedSeconds: 1800);
      expect(estimateWorkoutCalories(s, weightKg: 70), 294);
    });

    test('sin duración o sin peso devuelve 0', () {
      expect(
        estimateWorkoutCalories(_session(elapsedSeconds: 0), weightKg: 70),
        0,
      );
      expect(
        estimateWorkoutCalories(_session(), weightKg: 0),
        0,
      );
    });

    test('escala con el peso', () {
      final s = _session(elapsedSeconds: 3600);
      final a = estimateWorkoutCalories(s, weightKg: 50);
      final b = estimateWorkoutCalories(s, weightKg: 100);
      expect(b, greaterThan(a));
      expect(a, (368 * 50 / 70).round());
    });
  });
}
