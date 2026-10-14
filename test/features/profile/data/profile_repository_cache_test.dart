import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balancore/core/offline/local_cache.dart';
import 'package:balancore/core/offline/offline_store.dart';
import 'package:balancore/features/profile/data/profile_repository.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';

/// Base "caída": cualquier acceso a colección lanza, simulando sin red.
class _ThrowingDb extends FakeFirebaseFirestore {
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    throw Exception('sin conexión');
  }
}

UserProfile _profile() => UserProfile(
      uid: 'u1',
      displayName: 'Ana',
      sex: 'Femenino',
      currentWeight: 60,
      height: 165,
      age: 30,
      activityLevel: 'Moderado',
      targetCalories: 2000,
    );

Future<FakeFirebaseFirestore> _downDb() async => _ThrowingDb();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late OfflineStore store;
  late LocalCache cache;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    store = OfflineStore();
    cache = LocalCache();
  });

  test('getProfile cae en la caché local si Firestore falla', () async {
    final repo = ProfileRepository(db: db, offline: store, cache: cache);
    await repo.saveProfile(_profile());
    expect((await repo.getProfile('u1'))?.displayName, 'Ana');
    await Future<void>.delayed(Duration.zero);

    final offlineRepo = ProfileRepository(
      db: await _downDb(),
      offline: store,
      cache: cache,
    );
    expect((await offlineRepo.getProfile('u1'))?.displayName, 'Ana');
  });

  test('getRoutines cae en la caché local si Firestore falla', () async {
    final repo = ProfileRepository(db: db, offline: store, cache: cache);
    await repo.saveRoutine('u1', RoutineDay(day: 'Lunes', title: 'Pecho'));
    final live = await repo.getRoutines('u1');
    expect(live.any((r) => r.title == 'Pecho'), isTrue);
    await Future<void>.delayed(Duration.zero);

    final offlineRepo = ProfileRepository(
      db: await _downDb(),
      offline: store,
      cache: cache,
    );
    final cached = await offlineRepo.getRoutines('u1');
    expect(cached.any((r) => r.title == 'Pecho'), isTrue);
  });

  test('getSavedFoods cae en la caché local si Firestore falla', () async {
    final repo = ProfileRepository(db: db, offline: store, cache: cache);
    await repo.saveFood(
      'u1',
      SavedFood(id: '', name: 'Avena', calories: 120, useCount: 3),
    );
    final live = await repo.getSavedFoods('u1');
    expect(live.any((f) => f.name == 'Avena'), isTrue);
    await Future<void>.delayed(Duration.zero);

    final offlineRepo = ProfileRepository(
      db: await _downDb(),
      offline: store,
      cache: cache,
    );
    final cached = await offlineRepo.getSavedFoods('u1');
    final avena = cached.firstWhere((f) => f.name == 'Avena');
    expect(avena.useCount, 3);
    expect(avena.id, isNotEmpty);
  });
}
