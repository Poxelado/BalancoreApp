import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/training/domain/personal_records.dart';

WorkoutSetLog _set(
  int n,
  double w,
  int r, {
  bool done = true,
  SetType type = SetType.normal,
}) =>
    WorkoutSetLog(
      setNumber: n,
      weight: w,
      reps: r,
      completed: done,
      type: type,
    );

WorkoutSession _sess(String id, List<WorkoutSetLog> sets, {bool done = true}) =>
    WorkoutSession(
      id: id,
      dayName: 'Lunes',
      title: 'Pecho',
      startedAt: DateTime(2026, 10, 5, 9),
      completed: done,
      exercises: [
        WorkoutExerciseLog(
          exerciseId: 'ex1',
          exerciseName: 'Press Banca',
          muscleGroup: 'Pecho',
          sets: sets,
        ),
      ],
    );

void main() {
  group('epley', () {
    test('reps <= 1 devuelve el peso', () {
      expect(epley(100, 1), 100);
    });

    test('aplica w * (1 + r/30)', () {
      expect(epley(100, 10), closeTo(133.33, 0.01));
    });

    test('datos inválidos devuelven null', () {
      expect(epley(0, 10), isNull);
      expect(epley(100, 0), isNull);
    });
  });

  group('detectPersonalRecords', () {
    test('sin historial, la primera serie marca todos los récords', () {
      final records =
          detectPersonalRecords(_sess('a', [_set(1, 80, 10)]), []);
      expect(records.map((r) => r.kind),
          containsAll([PrKind.weight, PrKind.volume, PrKind.e1rm]));
      expect(records.every((r) => r.isFirst), isTrue);
    });

    test('no marca récord si no supera el máximo previo', () {
      final history = [_sess('prev', [_set(1, 100, 5), _set(2, 80, 10)])];
      final records =
          detectPersonalRecords(_sess('a', [_set(1, 80, 10)]), history);
      // Mismo peso y mismo volumen (800) y mismo 1RM → ningún récord.
      expect(records, isEmpty);
    });

    test('marca récord de peso pero no de volumen si bajan las reps', () {
      final history = [_sess('prev', [_set(1, 100, 10)])];
      final records =
          detectPersonalRecords(_sess('a', [_set(1, 105, 3)]), history);
      final kinds = records.map((r) => r.kind).toSet();
      expect(kinds, contains(PrKind.weight));
      // 105*3 = 315 < 1000 del volumen previo.
      expect(kinds.contains(PrKind.volume), isFalse);
      // 1RM estimado 105*1.1 = 115.5 > 100*1.333 = 133.3? No, menor.
      expect(kinds.contains(PrKind.e1rm), isFalse);
    });

    test('ignora calentamiento y series al fallo', () {
      // El "récord" está en calentamiento y al fallo → no cuenta.
      final records = detectPersonalRecords(
        _sess('a', [
          _set(1, 200, 5, type: SetType.warmup),
          _set(2, 210, 5, type: SetType.failure),
        ]),
        [],
      );
      expect(records, isEmpty);
    });

    test('ignora series incompletas', () {
      final records =
          detectPersonalRecords(_sess('a', [_set(1, 150, 5, done: false)]), []);
      expect(records, isEmpty);
    });

    test('ignora series sin peso', () {
      final records = detectPersonalRecords(_sess('a', [_set(1, 0, 10)]), []);
      expect(records, isEmpty);
    });

    test('excluye la propia sesión del historial', () {
      final own = _sess('a', [_set(1, 100, 5)]);
      // La sesión no se compara consigo misma: sus series cuentan como primer
      // récord, no como "-superó 100 kg" contra su propio histórico.
      final records = detectPersonalRecords(own, [own]);
      final weight = records.firstWhere((r) => r.kind == PrKind.weight);
      expect(weight.value, 100);
      expect(weight.previous, 0);
      expect(weight.isFirst, isTrue);
    });

    test('lleva el récord anterior para poder comparar', () {
      final history = [_sess('prev', [_set(1, 100, 5)])];
      final records =
          detectPersonalRecords(_sess('a', [_set(1, 110, 5)]), history);
      final weight = records.firstWhere((r) => r.kind == PrKind.weight);
      expect(weight.value, 110);
      expect(weight.previous, 100);
      expect(weight.isFirst, isFalse);
    });

    test('el volumen cuenta solo sets con reps', () {
      // reps = 0 no genera volumen (0), así que no dispara récord de volumen.
      final history = [_sess('prev', [_set(1, 50, 10)])];
      final records =
          detectPersonalRecords(_sess('a', [_set(1, 200, 0)]), history);
      final kinds = records.map((r) => r.kind).toSet();
      expect(kinds, contains(PrKind.weight));
      expect(kinds.contains(PrKind.volume), isFalse);
    });
  });

  group('recordsForSet', () {
    test('devuelve los récords de esa serie concreta', () {
      final history = [_sess('prev', [_set(1, 100, 5)])];
      final exercise = WorkoutExerciseLog(
        exerciseId: 'ex1',
        exerciseName: 'Press Banca',
        sets: [_set(1, 100, 5), _set(2, 120, 5)],
      );
      // La serie 1 iguala el récord previo → nada.
      expect(recordsForSet(
        exercise: exercise,
        set: _set(1, 100, 5),
        history: history,
      ), isEmpty);
      // La serie 2 lo supera → récords de peso y 1RM.
      final r = recordsForSet(
        exercise: exercise,
        set: _set(2, 120, 5),
        history: history,
      );
      expect(r.map((x) => x.kind), contains(PrKind.weight));
    });
  });
}