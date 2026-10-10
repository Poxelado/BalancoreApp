import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/auth/presentation/providers/auth_provider.dart';
import 'package:balancore/features/profile/data/profile_repository.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/profile/presentation/providers/profile_provider.dart';

UserProfile _profile() => UserProfile(
      uid: 'u1',
      sex: 'Masculino',
      currentWeight: 70,
      height: 175,
      age: 25,
      activityLevel: 'Moderado',
      targetCalories: 2000,
      onboardingCompleted: true,
    );

void main() {
  late FakeFirebaseFirestore db;
  late ProfileRepository repo;
  late ProviderContainer container;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ProfileRepository(db: db);
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(
          AuthService(
            auth: MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(uid: 'u1', email: 'a@b.com'),
            ),
          ),
        ),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
  });

  test('userProfileProvider carga el perfil del usuario autenticado', () async {
    await repo.saveProfile(_profile());
    await container.read(authStateProvider.future);

    final profile = await container.read(userProfileProvider.future);
    expect(profile, isNotNull);
    expect(profile!.uid, 'u1');
    expect(profile.onboardingCompleted, isTrue);
  });

  test('routinesProvider devuelve la rutina por defecto', () async {
    await container.read(authStateProvider.future);
    final routines = await container.read(routinesProvider.future);
    expect(routines.length, 7);
  });

  test('todayRoutineProvider resuelve la rutina del día', () async {
    await container.read(authStateProvider.future);
    final today = await container.read(todayRoutineProvider.future);
    expect(today, isNotNull);
  });

  test('savedFoodsProvider refleja los alimentos guardados', () async {
    await container.read(authStateProvider.future);
    expect(await container.read(savedFoodsProvider.future), isEmpty);

    await repo.saveFood('u1', SavedFood(id: '', name: 'Avena', calories: 300));
    container.invalidate(savedFoodsProvider);
    final foods = await container.read(savedFoodsProvider.future);
    expect(foods.length, 1);
    expect(foods.first.name, 'Avena');
  });

  test('activeWorkoutSessionProvider devuelve la sesión sin completar',
      () async {
    await repo.saveProfile(_profile());
    await repo.saveWorkoutSession(
      'u1',
      WorkoutSession(
        id: 's1',
        dayName: 'Lunes',
        title: 'Pecho',
        startedAt: DateTime(2026, 10, 6, 18),
        completed: false,
      ),
    );
    await container.read(authStateProvider.future);

    final active = await container.read(activeWorkoutSessionProvider.future);
    expect(active, isNotNull);
    expect(active!.id, 's1');
  });

  test('invalidateProgressData refresca el log de hoy', () async {
    await repo.saveProfile(_profile());
    await container.read(authStateProvider.future);

    final sub = container.listen(todayLogProvider, (_, __) {});
    addTearDown(sub.close);

    var log = await container.read(todayLogProvider.future);
    expect(log.consumedCalories, 0);

    await repo.addMeal(
      'u1',
      MealEntry(
        id: 'm1',
        name: 'Almuerzo',
        mealType: 'Almuerzo',
        calories: 300,
      ),
    );
    invalidateProgressData(container);

    log = await container.read(todayLogProvider.future);
    expect(log.consumedCalories, 300);
  });
}
