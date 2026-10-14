import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balancore/core/offline/offline_store.dart';
import 'package:balancore/features/profile/data/profile_repository.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';

MealEntry _meal(String id, int cal) => MealEntry(
      id: id,
      name: 'Comida $id',
      mealType: 'Almuerzo',
      calories: cal,
      proteinGrams: 10,
      carbsGrams: 20,
      fatGrams: 5,
    );

Future<bool> _todayDocExists(FakeFirebaseFirestore db) async {
  final doc = await db
      .collection('users')
      .doc('u1')
      .collection('dailyLogs')
      .doc(WorkoutSession.dateKey())
      .get();
  return doc.exists;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late OfflineStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    store = OfflineStore();
  });

  test('sin conexión addMeal se encola y ya se ve en getTodayLog', () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    await repo.addMeal('u1', _meal('m1', 300));

    expect(store.length, 1, reason: 'queda pendiente en la cola');
    final log = await repo.getTodayLog('u1');
    expect(log.meals.length, 1);
    expect(log.consumedCalories, 300);

    expect(await _todayDocExists(db), isFalse,
        reason: 'todavía no se subió a Firestore');
  });

  test('applyOfflineOp sube la comida y es idempotente', () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    await repo.addMeal('u1', _meal('m1', 300));

    final op = store.ops.first;
    await repo.applyOfflineOp(op);
    await repo.applyOfflineOp(op);

    expect(await _todayDocExists(db), isTrue);
    final log = await repo.getTodayLog('u1');
    expect(log.meals.length, 1);
    expect(log.consumedCalories, 300);
  });

  test('sin conexión removeMeal quita la comida del overlay', () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    await repo.addMeal('u1', _meal('m1', 300));
    await repo.addMeal('u1', _meal('m2', 200));
    await repo.removeMeal('u1', 'm1');

    final log = await repo.getTodayLog('u1');
    expect(log.meals.length, 1);
    expect(log.meals.first.id, 'm2');
    expect(log.consumedCalories, 200);
    expect(store.length, 2, reason: 'add m2 + remove m1');
  });

  test('sin conexión saveWorkoutSession aparece en el historial', () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    final session = WorkoutSession(
      id: 's1',
      dayName: 'Lunes',
      title: 'Pecho',
      startedAt: DateTime.now(),
      completed: true,
    );
    await repo.saveWorkoutSession('u1', session);

    expect(store.length, 1);
    final history = await repo.getWorkoutHistory('u1');
    expect(history.any((s) => s.id == 's1'), isTrue);
  });

  test('con conexión se escribe directo y no queda nada pendiente', () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => true);
    await repo.addMeal('u1', _meal('m1', 200));

    expect(store.length, 0);
    final log = await repo.getTodayLog('u1');
    expect(log.meals.length, 1);
    expect(log.consumedCalories, 200);
  });

  test('sin conexión deleteWorkoutSession lo oculta y encola el borrado',
      () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    final session = WorkoutSession(
      id: 's1',
      dayName: 'Lunes',
      title: 'Pecho',
      startedAt: DateTime.now(),
      completed: true,
    );
    await repo.saveWorkoutSession('u1', session);
    expect(
      (await repo.getWorkoutHistory('u1')).any((s) => s.id == 's1'),
      isTrue,
    );

    await repo.deleteWorkoutSession('u1', 's1');

    final history = await repo.getWorkoutHistory('u1');
    expect(history.any((s) => s.id == 's1'), isFalse,
        reason: 'se oculta al instante sin conexión');
    final wsOps =
        store.ops.where((o) => o.dedupeKey == 'ws:s1').toList();
    expect(wsOps.length, 1, reason: 'el borrado reemplaza la subida pendiente');
    expect(wsOps.first.type.name, 'workoutDelete');
  });

  test('al aplicar un borrado pendiente se elimina en Firestore', () async {
    final online =
        ProfileRepository(db: db, offline: store, isOnline: () => true);
    await online.saveWorkoutSession(
      'u1',
      WorkoutSession(
        id: 's1',
        dayName: 'Lunes',
        title: 'Pecho',
        startedAt: DateTime.now(),
        completed: true,
      ),
    );

    final offline =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    await offline.deleteWorkoutSession('u1', 's1');
    for (final op in store.ops.toList()) {
      await offline.applyOfflineOp(op);
    }

    final doc = await db
        .collection('users')
        .doc('u1')
        .collection('workoutSessions')
        .doc('s1')
        .get();
    expect(doc.exists, isFalse);
  });

  test('sin conexión, una rutina reencuentra la sesión pendiente', () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    await repo.saveWorkoutSession(
      'u1',
      WorkoutSession(
        id: 's1',
        dayName: 'Lunes',
        title: 'Pecho',
        startedAt: DateTime.now(),
      ),
    );

    final found = await repo.findIncompleteSessionForRoutine(
      'u1',
      dayName: 'Lunes',
      title: 'Pecho',
    );
    expect(found?.id, 's1');
  });

  test('sin conexión el agua y el sueño se encolan y se ven al instante',
      () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    await repo.updateTodayLog('u1', waterGlasses: 5);
    await repo.updateTodayLog('u1', sleepHours: 7.5);

    expect(store.length, 1, reason: 'se fusiona en una sola operación del día');
    final log = await repo.getTodayLog('u1');
    expect(log.waterGlasses, 5);
    expect(log.sleepHours, 7.5);
    expect(await _todayDocExists(db), isFalse,
        reason: 'todavía no se subió a Firestore');
  });

  test('al aplicar el cambio del día se suben agua y sueño a Firestore',
      () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    await repo.updateTodayLog('u1', waterGlasses: 3, sleepHours: 6.0);

    for (final op in store.ops.toList()) {
      await repo.applyOfflineOp(op);
    }

    final doc = await db
        .collection('users')
        .doc('u1')
        .collection('dailyLogs')
        .doc(WorkoutSession.dateKey())
        .get();
    expect(doc.data()?['waterGlasses'], 3);
    expect(doc.data()?['sleepHours'], 6.0);
  });

  test('sin conexión los pasos se encolan y se ven al instante', () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    await repo.setTodaySteps('u1', 4321);

    expect(store.length, 1);
    final log = await repo.getTodayLog('u1');
    expect(log.steps, 4321);
  });

  test('sin conexión una receta se encola y aparece al instante', () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    final id = await repo.saveRecipe(
      'u1',
      const SavedRecipe(
        id: '',
        name: 'Arroz con pollo',
        ingredients: [RecipeIngredient(name: 'Arroz', calories: 200)],
      ),
    );

    expect(id, isNotEmpty, reason: 'se le asigna un id local');
    expect(store.length, 1);
    final recipes = await repo.getSavedRecipes('u1');
    expect(recipes.length, 1);
    expect(recipes.first.id, id);
    expect(recipes.first.name, 'Arroz con pollo');
    expect(recipes.first.totalCalories, 200);
  });

  test('al aplicar la receta pendiente se sube a Firestore', () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    final id = await repo.saveRecipe(
      'u1',
      const SavedRecipe(id: '', name: 'Tortilla'),
    );

    for (final op in store.ops.toList()) {
      await repo.applyOfflineOp(op);
    }

    final doc = await db
        .collection('users')
        .doc('u1')
        .collection('savedRecipes')
        .doc(id)
        .get();
    expect(doc.exists, isTrue);
    expect(doc.data()?['name'], 'Tortilla');
  });

  test('sin conexión borrar una receta la oculta y encola el borrado',
      () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    final id = await repo.saveRecipe(
      'u1',
      const SavedRecipe(id: '', name: 'Tortilla'),
    );
    await repo.deleteRecipe('u1', id);

    final recipes = await repo.getSavedRecipes('u1');
    expect(recipes, isEmpty);
    expect(store.ops.single.type.name, 'recipeDelete');
  });

  test('sin conexión un alimento se encola y aparece al instante', () async {
    final repo =
        ProfileRepository(db: db, offline: store, isOnline: () => false);
    final id = await repo.saveFood(
      'u1',
      SavedFood(id: '', name: 'Avena', calories: 150),
    );

    expect(id, isNotEmpty);
    expect(store.length, 1);
    final foods = await repo.getSavedFoods('u1');
    expect(foods.length, 1);
    expect(foods.first.name, 'Avena');
  });
}
