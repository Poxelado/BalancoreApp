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
}
