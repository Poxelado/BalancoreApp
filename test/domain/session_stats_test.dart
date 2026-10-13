import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/training/domain/session_stats.dart';

WorkoutSetLog _s(int n, double w, int r,
        {bool done = true, SetType type = SetType.normal}) =>
    WorkoutSetLog(
      setNumber: n,
      weight: w,
      reps: r,
      completed: done,
      type: type,
    );

WorkoutSession _sess(
  String id,
  DateTime at, {
  List<WorkoutExerciseLog> exercises = const [],
  int elapsed = 3600,
  bool completed = true,
}) =>
    WorkoutSession(
      id: id,
      dayName: 'Lunes',
      title: 'Pecho',
      startedAt: at,
      elapsedSeconds: elapsed,
      completed: completed,
      exercises: exercises,
    );

void main() {
  WorkoutExerciseLog ex1(double w, int r, {SetType type = SetType.normal}) =>
      WorkoutExerciseLog(
        exerciseId: 'ex1',
        exerciseName: 'Press Banca',
        muscleGroup: 'Pecho',
        sets: [_s(1, w, r, type: type)],
      );

  group('computeSessionStats', () {
    test('suma volumen de series completadas', () {
      final s = _sess('a', DateTime(2026, 10, 5, 9), exercises: [
        ex1(50, 10),
        ex1(50, 10),
      ]);
      final stats = computeSessionStats(s, []);
      expect(stats.totalVolume, 1000);
      expect(stats.completedSets, 2);
      expect(stats.totalSets, 2);
    });

    test('excluye calentamiento del volumen', () {
      final s = _sess('a', DateTime(2026, 10, 5, 9), exercises: [
        WorkoutExerciseLog(
          exerciseId: 'ex1',
          exerciseName: 'Press Banca',
          muscleGroup: 'Pecho',
          sets: [
            _s(1, 40, 10, type: SetType.warmup),
            _s(2, 80, 5),
          ],
        ),
      ]);
      final stats = computeSessionStats(s, []);
      expect(stats.totalVolume, 400);
      expect(stats.completedSets, 2);
    });

    test('ignora series no completadas', () {
      final s = _sess('a', DateTime(2026, 10, 5, 9), exercises: [
        WorkoutExerciseLog(
          exerciseId: 'ex1',
          exerciseName: 'Press Banca',
          muscleGroup: 'Pecho',
          sets: [_s(1, 100, 10, done: false)],
        ),
      ]);
      expect(computeSessionStats(s, []).totalVolume, 0);
    });

    test('desglosa el volumen por grupo muscular de mayor a menor', () {
      final s = _sess('a', DateTime(2026, 10, 5, 9), exercises: [
        WorkoutExerciseLog(
          exerciseId: 'ex1',
          exerciseName: 'Press Banca',
          muscleGroup: 'Pecho',
          sets: [_s(1, 50, 10)],
        ),
        WorkoutExerciseLog(
          exerciseId: 'ex2',
          exerciseName: 'Curl',
          muscleGroup: 'Bíceps',
          sets: [_s(1, 20, 20)],
        ),
      ]);
      final stats = computeSessionStats(s, []);
      expect(stats.volumeByMuscle.keys.first, 'Pecho');
      expect(stats.volumeByMuscle['Pecho'], 500);
      expect(stats.volumeByMuscle['Bíceps'], 400);
    });

    test('sin grupo muscular usa "Otros"', () {
      final s = _sess('a', DateTime(2026, 10, 5, 9), exercises: [
        WorkoutExerciseLog(
          exerciseId: 'ex1',
          exerciseName: 'Ejercicio',
          sets: [_s(1, 10, 10)],
        ),
      ]);
      expect(computeSessionStats(s, []).volumeByMuscle.containsKey('Otros'), isTrue);
    });

    test('sin sesión anterior comparable no hay comparación', () {
      final s = _sess('a', DateTime(2026, 10, 5, 9), exercises: [ex1(50, 10)]);
      final stats = computeSessionStats(s, []);
      expect(stats.hasPrevious, isFalse);
      expect(stats.volumeDelta, isNull);
      expect(stats.volumeDeltaPercent, isNull);
    });

    test('compara con la sesión anterior que comparte ejercicios', () {
      final prev = _sess('p', DateTime(2026, 10, 1, 9), exercises: [
        ex1(50, 10),
      ], elapsed: 3000);
      final cur = _sess('a', DateTime(2026, 10, 5, 9), exercises: [
        ex1(60, 10),
      ], elapsed: 3600);
      final stats = computeSessionStats(cur, [prev]);
      expect(stats.hasPrevious, isTrue);
      expect(stats.previousVolume, 500);
      expect(stats.volumeDelta, 100);
      expect(stats.volumeImproved, isTrue);
      expect(stats.volumeDeltaPercent, closeTo(20, 0.01));
      expect(stats.durationDelta, 600);
    });

    test('ignora sesiones posteriores o de otra rutina', () {
      final future = _sess('f', DateTime(2026, 10, 9, 9), exercises: [ex1(50, 10)]);
      final other = _sess('o', DateTime(2026, 10, 1, 9), exercises: [
        WorkoutExerciseLog(
          exerciseId: 'zzz',
          exerciseName: 'Zancada',
          sets: [_s(1, 100, 10)],
        ),
      ]);
      final cur = _sess('a', DateTime(2026, 10, 5, 9), exercises: [ex1(50, 10)]);
      final stats = computeSessionStats(cur, [future, other]);
      expect(stats.hasPrevious, isFalse);
    });

    test('detecta una sesión con menos volumen', () {
      final prev = _sess('p', DateTime(2026, 10, 1, 9), exercises: [ex1(80, 10)]);
      final cur = _sess('a', DateTime(2026, 10, 5, 9), exercises: [ex1(60, 10)]);
      final stats = computeSessionStats(cur, [prev]);
      expect(stats.volumeImproved, isFalse);
      expect(stats.volumeDelta, -200);
    });
  });
}