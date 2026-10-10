import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/training/domain/rest_day_suggestion.dart';

final _now = DateTime.now();

DateTime _dayAgo(int days) =>
    DateTime(_now.year, _now.month, _now.day).subtract(Duration(days: days));

WorkoutSession _session(
  DateTime day, {
  bool completed = true,
  List<int> rpes = const [],
}) {
  return WorkoutSession(
    id: 's${day.millisecondsSinceEpoch}_${rpes.length}',
    dayName: 'Lunes',
    title: 'Entreno',
    startedAt: day,
    completed: completed,
    exercises: [
      for (var i = 0; i < rpes.length; i++)
        WorkoutExerciseLog(
          exerciseId: 'ex$i',
          exerciseName: 'Ejercicio $i',
          rpe: rpes[i],
          sets: const [
            WorkoutSetLog(setNumber: 1, weight: 50, reps: 10, completed: true),
          ],
        ),
    ],
  );
}

void main() {
  group('RestDayRules.evaluate', () {
    test('sin historial no sugiere descanso', () {
      final advice = RestDayRules.evaluate(const []);
      expect(advice.suggestRest, isFalse);
      expect(advice.level, 'none');
    });

    test('ignora sesiones no completadas', () {
      final advice = RestDayRules.evaluate([
        _session(_dayAgo(0), completed: false),
        _session(_dayAgo(1), completed: false),
      ]);
      expect(advice.suggestRest, isFalse);
    });

    test('una sesión hoy no sugiere descanso', () {
      final advice = RestDayRules.evaluate([_session(_dayAgo(0))]);
      expect(advice.suggestRest, isFalse);
      expect(advice.consecutiveTrainingDays, 1);
    });

    test('3 días seguidos sugiere descanso suave', () {
      final advice = RestDayRules.evaluate([
        _session(_dayAgo(0)),
        _session(_dayAgo(1)),
        _session(_dayAgo(2)),
      ]);
      expect(advice.suggestRest, isTrue);
      expect(advice.level, 'soft');
      expect(advice.consecutiveTrainingDays, 3);
    });

    test('5 días seguidos sugiere descanso fuerte', () {
      final advice = RestDayRules.evaluate([
        for (var i = 0; i < 5; i++) _session(_dayAgo(i)),
      ]);
      expect(advice.suggestRest, isTrue);
      expect(advice.level, 'strong');
      expect(advice.consecutiveTrainingDays, 5);
    });

    test('6 sesiones en 7 días sugiere descanso aunque no sean seguidas', () {
      final advice = RestDayRules.evaluate([
        for (final i in [0, 1, 2, 4, 5, 6]) _session(_dayAgo(i)),
      ]);
      expect(advice.suggestRest, isTrue);
      expect(advice.level, 'strong');
      expect(advice.sessionsLast7Days, 6);
    });

    test('RPE alto con 3 días seguidos escala a descanso fuerte', () {
      final advice = RestDayRules.evaluate([
        _session(_dayAgo(0), rpes: const [9, 9]),
        _session(_dayAgo(1), rpes: const [9, 8]),
        _session(_dayAgo(2)),
      ]);
      expect(advice.level, 'strong');
      expect(advice.message, contains('RPE alto'));
    });

    test('RPE alto sin racha sugiere descanso suave', () {
      final advice = RestDayRules.evaluate([
        _session(_dayAgo(0), rpes: const [9, 9]),
      ]);
      expect(advice.suggestRest, isTrue);
      expect(advice.level, 'soft');
    });
  });
}
