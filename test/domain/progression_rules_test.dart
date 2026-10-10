import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/training/domain/progression_rules.dart';

WorkoutSession _session({
  required String id,
  required DateTime startedAt,
  required List<WorkoutSetLog> sets,
  String exerciseId = 'squat',
  String exerciseName = 'Sentadilla',
}) {
  return WorkoutSession(
    id: id,
    dayName: 'Lunes',
    title: 'Pierna',
    startedAt: startedAt,
    completed: true,
    exercises: [
      WorkoutExerciseLog(
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        sets: sets,
      ),
    ],
  );
}

List<WorkoutSetLog> _completedSets(double weight, int reps, {int count = 3}) {
  return [
    for (var i = 0; i < count; i++)
      WorkoutSetLog(
        setNumber: i + 1,
        weight: weight,
        reps: reps,
        completed: true,
      ),
  ];
}

ProgressionSuggestion? _suggest(List<WorkoutSession> history,
    {int targetReps = 8, int setCount = 3}) {
  return ProgressionRules.suggest(
    exerciseId: 'squat',
    setCount: setCount,
    targetReps: targetReps,
    history: history,
  );
}

void main() {
  group('suggest', () {
    test('devuelve null sin historial', () {
      expect(_suggest(const []), isNull);
    });

    test('con una sola sesión no propone subir', () {
      final s = _suggest([
        _session(
          id: 'a',
          startedAt: DateTime(2026, 10, 6),
          sets: _completedSets(100, 10),
        ),
      ]);

      expect(s, isNotNull);
      expect(s!.isIncrease, isFalse);
      expect(s.isRepIncrease, isFalse);
      expect(s.message, contains('Repite lo anterior'));
      expect(s.weights.every((w) => w == 100), isTrue);
    });

    test('dos sesiones al techo (12 reps) suben +2.5 kg', () {
      final s = _suggest([
        _session(
          id: 'a',
          startedAt: DateTime(2026, 10, 1),
          sets: _completedSets(100, 12),
        ),
        _session(
          id: 'b',
          startedAt: DateTime(2026, 10, 6),
          sets: _completedSets(100, 12),
        ),
      ]);

      expect(s, isNotNull);
      expect(s!.isIncrease, isTrue);
      expect(s.weights.every((w) => w == 102.5), isTrue);
      expect(s.reps.every((r) => r == 8), isTrue);
    });

    test('dos sesiones con 15+ reps suben +5 kg', () {
      final s = _suggest([
        _session(
          id: 'a',
          startedAt: DateTime(2026, 10, 1),
          sets: _completedSets(100, 15),
        ),
        _session(
          id: 'b',
          startedAt: DateTime(2026, 10, 6),
          sets: _completedSets(100, 15),
        ),
      ]);

      expect(s, isNotNull);
      expect(s!.isIncrease, isTrue);
      expect(s.weights.every((w) => w == 105.0), isTrue);
    });

    test('dos sesiones sólidas bajo el techo suman +1 rep', () {
      final s = _suggest([
        _session(
          id: 'a',
          startedAt: DateTime(2026, 10, 1),
          sets: _completedSets(100, 10),
        ),
        _session(
          id: 'b',
          startedAt: DateTime(2026, 10, 6),
          sets: _completedSets(100, 10),
        ),
      ]);

      expect(s, isNotNull);
      expect(s!.isRepIncrease, isTrue);
      expect(s.isIncrease, isFalse);
      expect(s.weights.every((w) => w == 100), isTrue);
      expect(s.reps.every((r) => r == 11), isTrue);
    });

    test('setCount <= 0 devuelve null', () {
      expect(_suggest(const [], setCount: 0), isNull);
    });

    test('rellena series según setCount solicitado', () {
      final s = _suggest(
        [
          _session(
            id: 'a',
            startedAt: DateTime(2026, 10, 1),
            sets: _completedSets(100, 12),
          ),
          _session(
            id: 'b',
            startedAt: DateTime(2026, 10, 6),
            sets: _completedSets(100, 12),
          ),
        ],
        setCount: 4,
      );

      expect(s!.weights.length, 4);
      expect(s.reps.length, 4);
    });
  });
}
