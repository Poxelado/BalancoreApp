import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balancore/features/profile/data/profile_repository.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/training/domain/exercise.dart';
import 'package:balancore/features/training/presentation/workout_builders.dart';

const _exercise = Exercise(
  id: 'ex1',
  name: 'Press Banca',
  muscleGroup: 'Pecho',
);

void main() {
  late FakeFirebaseFirestore db;
  late ProfileRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ProfileRepository(db: db);
  });

  test('sin usuario usa 3 series de 10 y 60s de descanso', () async {
    final log = await buildWorkoutExerciseLog(repo: repo, exercise: _exercise);

    expect(log.exerciseId, 'ex1');
    expect(log.exerciseName, 'Press Banca');
    expect(log.muscleGroup, 'Pecho');
    expect(log.restSeconds, 60);
    expect(log.sets.length, 3);
    expect(log.sets.map((s) => s.setNumber).toList(), [1, 2, 3]);
    expect(log.sets.every((s) => s.reps == 10), isTrue);
    expect(log.sets.every((s) => s.completed == false), isTrue);
  });

  test('respeta los valores por defecto guardados del usuario', () async {
    await repo.saveExerciseDefault(
      uid: 'u1',
      exerciseId: 'ex1',
      plannedSets: const [
        PlannedSet(weight: 60, reps: 8),
        PlannedSet(weight: 65, reps: 6),
      ],
      restSeconds: 120,
      notes: 'codo alto',
    );

    final log = await buildWorkoutExerciseLog(
      repo: repo,
      exercise: _exercise,
      uid: 'u1',
    );

    expect(log.restSeconds, 120);
    expect(log.notes, 'codo alto');
    expect(log.sets.length, 2);
    expect(log.sets[0].weight, 60);
    expect(log.sets[0].reps, 8);
    expect(log.sets[1].weight, 65);
    expect(log.sets[1].reps, 6);
  });
}
