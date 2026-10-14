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
}
