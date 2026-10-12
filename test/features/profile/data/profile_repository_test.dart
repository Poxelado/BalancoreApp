import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/core/errors/app_exception.dart';
import 'package:balancore/features/profile/data/profile_repository.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';

UserProfile _profile({
  String uid = 'u1',
  String? username,
  double weight = 70,
  bool onboarding = false,
}) {
  return UserProfile(
    uid: uid,
    username: username,
    sex: 'Masculino',
    currentWeight: weight,
    height: 175,
    age: 25,
    activityLevel: 'Moderado',
    goal: 'Mantenimiento',
    targetCalories: 2000,
    onboardingCompleted: onboarding,
  );
}

MealEntry _meal(String id, int calories) => MealEntry(
      id: id,
      name: 'Comida $id',
      mealType: 'Almuerzo',
      calories: calories,
      proteinGrams: 10,
      carbsGrams: 20,
      fatGrams: 5,
    );

void main() {
  late FakeFirebaseFirestore db;
  late ProfileRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ProfileRepository(db: db);
  });

  group('Perfil', () {
    test('saveProfile + getProfile hace round-trip', () async {
      await repo.saveProfile(_profile(onboarding: true));
      final got = await repo.getProfile('u1');
      expect(got, isNotNull);
      expect(got!.uid, 'u1');
      expect(got.onboardingCompleted, isTrue);
      expect(got.currentWeight, 70);
    });

    test('getProfile devuelve null si no existe', () async {
      expect(await repo.getProfile('nadie'), isNull);
    });

    test('updateProfileFields fusiona campos', () async {
      await repo.saveProfile(_profile());
      await repo.updateProfileFields('u1', {'bio': 'hola'});
      final got = await repo.getProfile('u1');
      expect(got!.bio, 'hola');
    });
  });

  group('Historial de peso', () {
    test('addWeightEntry guarda y actualiza peso y agua', () async {
      await repo.saveProfile(_profile());
      await repo.addWeightEntry('u1', 82, DateTime(2026, 10, 1));

      final profile = await repo.getProfile('u1');
      expect(profile!.currentWeight, 82);
      expect(profile.targetWaterMl, UserProfile.calculateWaterMl(weightKg: 82));

      final history = await repo.getWeightHistory('u1');
      expect(history.length, 1);
      expect(history.first.weight, 82);
    });
  });

  group('Rutinas', () {
    test('getRoutines devuelve la rutina por defecto si no hay datos', () async {
      final routines = await repo.getRoutines('u1');
      expect(routines.length, 7);
      expect(routines.first.day, 'Lunes');
    });

    test('saveRoutine persiste y getRoutines la devuelve', () async {
      await repo.saveRoutine(
        'u1',
        RoutineDay(day: 'Lunes', title: 'Pecho', calories: 450),
      );
      final routines = await repo.getRoutines('u1');
      expect(routines.length, 1);
      expect(routines.first.title, 'Pecho');
    });

    test('saveAllRoutines guarda varios días', () async {
      await repo.saveAllRoutines('u1', [
        RoutineDay(day: 'Lunes', title: 'Pecho'),
        RoutineDay(day: 'Martes', title: 'Espalda'),
      ]);
      final routines = await repo.getRoutines('u1');
      final days = routines.map((r) => r.day).toList();
      expect(days, ['Lunes', 'Martes']);
    });
  });

  group('Comidas del día', () {
    setUp(() async {
      await repo.saveProfile(_profile());
    });

    test('getTodayLog sin datos devuelve un log vacío', () async {
      final log = await repo.getTodayLog('u1');
      expect(log.meals, isEmpty);
      expect(log.consumedCalories, 0);
    });

    test('addMeal acumula totales', () async {
      await repo.addMeal('u1', _meal('m1', 300));
      await repo.addMeal('u1', _meal('m2', 200));
      final log = await repo.getTodayLog('u1');
      expect(log.meals.length, 2);
      expect(log.consumedCalories, 500);
      expect(log.proteinGrams, 20);
    });

    test('removeMeal recalcula totales', () async {
      await repo.addMeal('u1', _meal('m1', 300));
      await repo.addMeal('u1', _meal('m2', 200));
      await repo.removeMeal('u1', 'm1');
      final log = await repo.getTodayLog('u1');
      expect(log.meals.length, 1);
      expect(log.consumedCalories, 200);
    });

    test('updateMeal reemplaza la comida por id', () async {
      await repo.addMeal('u1', _meal('m1', 300));
      await repo.updateMeal('u1', _meal('m1', 450));
      final log = await repo.getTodayLog('u1');
      expect(log.meals.length, 1);
      expect(log.consumedCalories, 450);
    });
  });

  group('Alimentos guardados', () {
    test('saveFood evita duplicados por nombre (case-insensitive)', () async {
      final id1 = await repo.saveFood(
        'u1',
        SavedFood(id: '', name: 'Avena', calories: 300),
      );
      final id2 = await repo.saveFood(
        'u1',
        SavedFood(id: '', name: 'avena', calories: 320),
      );
      expect(id2, id1);
      final foods = await repo.getSavedFoods('u1');
      expect(foods.length, 1);
      expect(foods.first.calories, 320);
    });

    test('incrementFoodUse aumenta el contador', () async {
      final id = await repo.saveFood(
        'u1',
        SavedFood(id: '', name: 'Avena', calories: 300),
      );
      await repo.incrementFoodUse('u1', id);
      final foods = await repo.getSavedFoods('u1');
      expect(foods.first.useCount, 1);
    });
  });

  group('Recetas', () {
    test('saveRecipe + getSavedRecipes', () async {
      final id = await repo.saveRecipe(
        'u1',
        const SavedRecipe(
          id: '',
          name: 'Bowl',
          ingredients: [RecipeIngredient(name: 'Arroz', calories: 200)],
        ),
      );
      final recipes = await repo.getSavedRecipes('u1');
      expect(recipes.length, 1);
      expect(recipes.first.id, id);
      expect(recipes.first.totalCalories, 200);
    });
  });

  group('Usernames', () {
    test('claim/available/resolve/release', () async {
      expect(await repo.isUsernameAvailable('juan'), isTrue);
      await repo.claimUsername(username: 'juan', uid: 'u1', email: 'a@b.com');
      expect(await repo.isUsernameAvailable('juan'), isFalse);
      expect(await repo.resolveUsernameToEmail('juan'), 'a@b.com');

      await repo.releaseUsername('juan');
      expect(await repo.isUsernameAvailable('juan'), isTrue);
      expect(await repo.resolveUsernameToEmail('juan'), isNull);
    });

    test('isUsernameAvailable respeta el propio uid', () async {
      await repo.claimUsername(username: 'juan', uid: 'u1', email: 'a@b.com');
      expect(await repo.isUsernameAvailable('juan', exceptUid: 'u1'), isTrue);
      expect(await repo.isUsernameAvailable('juan', exceptUid: 'u2'), isFalse);
    });

    test('claimUsername rechaza nombres muy cortos', () async {
      expect(
        () => repo.claimUsername(username: 'ab', uid: 'u1', email: 'a@b.com'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('claimUsername rechaza caracteres inválidos', () async {
      expect(
        () => repo.claimUsername(username: 'juan perez', uid: 'u1', email: 'a@b.com'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('changeUsername libera el anterior y reclama el nuevo', () async {
      await repo.claimUsername(username: 'viejo', uid: 'u1', email: 'a@b.com');
      await repo.changeUsername(
        uid: 'u1',
        email: 'a@b.com',
        oldUsername: 'viejo',
        newUsername: 'nuevo',
      );
      expect(await repo.resolveUsernameToEmail('nuevo'), 'a@b.com');
      expect(await repo.resolveUsernameToEmail('viejo'), isNull);
    });
  });

  group('deleteUserData', () {
    test('borra perfil, subcolecciones y libera el username', () async {
      await repo.saveProfile(_profile(username: 'juan', onboarding: true));
      await repo.claimUsername(username: 'juan', uid: 'u1', email: 'a@b.com');
      await repo.saveRoutine('u1', RoutineDay(day: 'Lunes', title: 'Pecho'));
      await repo.addWeightEntry('u1', 80, DateTime(2026, 10, 1));

      await repo.deleteUserData('u1');

      expect(await repo.getProfile('u1'), isNull);
      expect(await repo.isUsernameAvailable('juan'), isTrue);
      // La subcolección quedó vacía → getRoutines vuelve a los valores por defecto
      final routines = await repo.getRoutines('u1');
      expect(routines.length, 7);
    });
  });
}
