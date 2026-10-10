import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/training/data/exercise_repository.dart';
import 'package:balancore/features/training/domain/exercise.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ExerciseRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ExerciseRepository(db: db);
  });

  test('getAllExercises devuelve el catálogo si no hay personalizados', () async {
    final all = await repo.getAllExercises('u1');
    expect(all.length, ExerciseCatalog.builtIn.length);
  });

  test('saveCustomExercise lo agrega al listado', () async {
    final id = await repo.saveCustomExercise(
      'u1',
      const Exercise(id: '', name: 'Ejercicio propio', muscleGroup: 'Pecho'),
    );
    final all = await repo.getAllExercises('u1');
    expect(all.length, ExerciseCatalog.builtIn.length + 1);
    final custom = await repo.getCustomExercises('u1');
    expect(custom.length, 1);
    expect(custom.first.id, id);
    expect(custom.first.isCustom, isTrue);
  });

  test('deleteCustomExercise lo elimina y lo saca de favoritos', () async {
    final id = await repo.saveCustomExercise(
      'u1',
      const Exercise(id: '', name: 'Ejercicio propio', muscleGroup: 'Pecho'),
    );
    await repo.toggleFavorite('u1', id);
    expect(await repo.getFavoriteIds('u1'), contains(id));

    await repo.deleteCustomExercise('u1', id);
    expect(await repo.getCustomExercises('u1'), isEmpty);
    expect(await repo.getFavoriteIds('u1'), isNot(contains(id)));
  });

  test('toggleFavorite alterna el favorito', () async {
    await repo.toggleFavorite('u1', 'ex_squat');
    expect(await repo.getFavoriteIds('u1'), contains('ex_squat'));

    await repo.toggleFavorite('u1', 'ex_squat');
    expect(await repo.getFavoriteIds('u1'), isEmpty);
  });
}
