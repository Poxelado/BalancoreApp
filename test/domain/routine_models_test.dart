import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';

void main() {
  group('RoutineExercise.effectiveSets', () {
    test('genera series desde sets/reps si no hay plannedSets', () {
      const e = RoutineExercise(
        exerciseId: 'ex_squat',
        exerciseName: 'Sentadilla',
        sets: 3,
        reps: 12,
      );
      final sets = e.effectiveSets;
      expect(sets.length, 3);
      expect(sets.every((s) => s.reps == 12), isTrue);
      expect(sets.every((s) => s.weight == 0), isTrue);
    });

    test('usa plannedSets cuando existen', () {
      const e = RoutineExercise(
        exerciseId: 'ex_squat',
        exerciseName: 'Sentadilla',
        sets: 5,
        plannedSets: [PlannedSet(weight: 80, reps: 5)],
      );
      expect(e.effectiveSets.length, 1);
      expect(e.effectiveSets.first.weight, 80);
    });

    test('sets <= 0 se limita a 1 serie', () {
      const e = RoutineExercise(
        exerciseId: 'x',
        exerciseName: 'x',
        sets: 0,
        reps: 10,
      );
      expect(e.effectiveSets.length, 1);
    });
  });

  group('RoutineExercise.estimateDayDuration', () {
    test('sin ejercicios devuelve cadena vacía', () {
      expect(RoutineExercise.estimateDayDuration(const []), '');
    });

    test('calcula minutos (trabajo + descansos)', () {
      const e = RoutineExercise(
        exerciseId: 'x',
        exerciseName: 'x',
        sets: 3,
        reps: 10,
      );
      // 3*60 trabajo + 2*60 descanso = 300 s = 5 min
      expect(RoutineExercise.estimateDayDuration([e]), '5 min');
    });

    test('formatea horas cuando supera los 60 minutos', () {
      const e = RoutineExercise(
        exerciseId: 'x',
        exerciseName: 'x',
        sets: 20,
        restSeconds: 300,
      );
      // 20*60 + 19*300 = 6900 s = 1h 55min
      expect(RoutineExercise.estimateDayDuration([e]), '1h 55min');
    });
  });

  group('RoutineDay serialización', () {
    test('toMap/fromMap conserva día y ejercicios', () {
      final day = RoutineDay(
        day: 'Lunes',
        title: 'Pecho',
        exercises: const [
          RoutineExercise(
            exerciseId: 'ex_bench_press',
            exerciseName: 'Press de banca',
            plannedSets: [PlannedSet(weight: 60, reps: 8)],
          ),
        ],
      );
      final restored = RoutineDay.fromMap(day.toMap());
      expect(restored.day, 'Lunes');
      expect(restored.exercises.length, 1);
      expect(restored.exercises.first.plannedSets.first.weight, 60);
    });

    test('fromMap tolera campos vacíos', () {
      final d = RoutineDay.fromMap(const {});
      expect(d.day, '');
      expect(d.exercises, isEmpty);
      expect(d.isRestDay, isFalse);
    });
  });

  group('SavedFood.toMeal', () {
    test('convierte a MealEntry con el tipo indicado', () {
      final food = SavedFood(
        id: 'f1',
        name: 'Avena',
        calories: 380,
        proteinGrams: 13,
        carbsGrams: 60,
        fatGrams: 7,
        portionGrams: 100,
        servingLabel: '100 g',
      );
      final meal = food.toMeal(mealType: 'Desayuno', mealId: 'm1');
      expect(meal.id, 'm1');
      expect(meal.name, 'Avena');
      expect(meal.mealType, 'Desayuno');
      expect(meal.calories, 380);
      expect(meal.grams, 100);
      expect(meal.servingLabel, '100 g');
    });
  });

  group('RecipeIngredient.scaled', () {
    test('multiplica valores por el factor', () {
      const ing = RecipeIngredient(
        name: 'Pollo',
        calories: 200,
        proteinGrams: 30,
        carbsGrams: 0,
        fatGrams: 8,
        grams: 150,
      );
      final doubled = ing.scaled(2);
      expect(doubled.calories, 400);
      expect(doubled.proteinGrams, 60);
      expect(doubled.fatGrams, 16);
      expect(doubled.grams, 300);
    });
  });

  group('SavedRecipe', () {
    const recipe = SavedRecipe(
      id: 'r1',
      name: 'Bowl',
      ingredients: [
        RecipeIngredient(name: 'Arroz', calories: 200, proteinGrams: 4),
        RecipeIngredient(name: 'Pollo', calories: 250, proteinGrams: 40),
      ],
    );

    test('calcula totales', () {
      expect(recipe.totalCalories, 450);
      expect(recipe.totalProtein, 44);
    });

    test('toMealEntry sin escala deja el nombre original', () {
      final meal = recipe.toMealEntry(mealType: 'Almuerzo', mealId: 'm1');
      expect(meal.name, 'Bowl');
      expect(meal.calories, 450);
      expect(meal.recipeId, 'r1');
      expect(meal.scale, 1.0);
      expect(meal.servingLabel, '2 ingredientes');
    });

    test('toMealEntry escala la porción y etiqueta', () {
      final half = recipe.toMealEntry(
        mealType: 'Almuerzo',
        scale: 0.5,
        mealId: 'm1',
      );
      expect(half.name, 'Bowl (½ porción)');
      expect(half.calories, 225);
      expect(half.servingLabel, '½ porción');
      expect(half.scale, 0.5);
    });

    test('toMealEntry con escala <= 0 usa 1.0', () {
      final meal = recipe.toMealEntry(
        mealType: 'Cena',
        scale: 0,
        mealId: 'm1',
      );
      expect(meal.scale, 1.0);
      expect(meal.calories, 450);
    });
  });

  group('MealEntry.isRecipe', () {
    test('es receta si trae recipeId o ingredientes', () {
      final m1 = MealEntry(
        id: '1',
        name: 'x',
        mealType: 'Snack',
        calories: 100,
        recipeId: 'r1',
      );
      expect(m1.isRecipe, isTrue);

      final m2 = MealEntry(
        id: '2',
        name: 'x',
        mealType: 'Snack',
        calories: 100,
        ingredients: const [RecipeIngredient(name: 'a', calories: 10)],
      );
      expect(m2.isRecipe, isTrue);

      final m3 = MealEntry(
        id: '3',
        name: 'x',
        mealType: 'Snack',
        calories: 100,
      );
      expect(m3.isRecipe, isFalse);
    });
  });
}
