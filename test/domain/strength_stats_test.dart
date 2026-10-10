import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/training/domain/strength_stats.dart';

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

void main() {
  group('StrengthStatsBuilder.fromSessions', () {
    test('agrupa por ejercicio y calcula volumen y máximo', () {
      final sessions = [
        _session(
          id: 'a',
          startedAt: DateTime(2026, 10, 1),
          sets: const [
            WorkoutSetLog(setNumber: 1, weight: 100, reps: 5, completed: true),
            WorkoutSetLog(setNumber: 2, weight: 80, reps: 5, completed: true),
          ],
        ),
        _session(
          id: 'b',
          startedAt: DateTime(2026, 10, 6),
          sets: const [
            WorkoutSetLog(setNumber: 1, weight: 110, reps: 5, completed: true),
          ],
        ),
      ];

      final stats = StrengthStatsBuilder.fromSessions(sessions);
      final squat = stats['squat'];

      expect(squat, isNotNull);
      expect(squat!.points.length, 2);
      expect(squat.bestWeight, 110);
      expect(squat.totalVolume, 100 * 5 + 80 * 5 + 110 * 5);
      expect(squat.avgVolume, (900 + 550) / 2);
    });

    test('ignora sesiones sin series relevantes', () {
      final sessions = [
        _session(
          id: 'a',
          startedAt: DateTime(2026, 10, 1),
          sets: const [
            WorkoutSetLog(setNumber: 1, weight: 0, reps: 0, completed: false),
          ],
        ),
      ];

      final stats = StrengthStatsBuilder.fromSessions(sessions);
      expect(stats, isEmpty);
    });
  });

  group('forExercise', () {
    test('devuelve objeto vacío si no hay datos', () {
      final stats = StrengthStatsBuilder.forExercise(
        const [],
        exerciseId: 'squat',
      );
      expect(stats.points, isEmpty);
      expect(stats.bestWeight, 0);
    });

    test('encuentra por nombre cuando no hay id', () {
      final sessions = [
        _session(
          id: 'a',
          exerciseId: '',
          exerciseName: 'Sentadilla',
          startedAt: DateTime(2026, 10, 1),
          sets: const [
            WorkoutSetLog(setNumber: 1, weight: 90, reps: 8, completed: true),
          ],
        ),
      ];

      final stats = StrengthStatsBuilder.forExercise(
        sessions,
        exerciseId: '',
        exerciseName: 'Sentadilla',
      );
      expect(stats.bestWeight, 90);
    });
  });
}
