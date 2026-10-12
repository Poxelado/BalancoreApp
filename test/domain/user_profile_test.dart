import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';

UserProfile _profile({
  String uid = 'u1',
  String sex = 'Masculino',
  double weight = 70,
  double height = 175,
  int age = 25,
  String activity = 'Sedentario',
  String goal = 'Mantenimiento',
  int targetCalories = 2000,
}) {
  return UserProfile(
    uid: uid,
    sex: sex,
    currentWeight: weight,
    height: height,
    age: age,
    activityLevel: activity,
    goal: goal,
    targetCalories: targetCalories,
  );
}

void main() {
  group('calculateWaterMl', () {
    test('usa ~35 ml por kg', () {
      expect(UserProfile.calculateWaterMl(weightKg: 60), 2100);
    });

    test('peso 0 o negativo devuelve 2000 por defecto', () {
      expect(UserProfile.calculateWaterMl(weightKg: 0), 2000);
      expect(UserProfile.calculateWaterMl(weightKg: -5), 2000);
    });

    test('respeta los límites 1500-5000 ml', () {
      expect(UserProfile.calculateWaterMl(weightKg: 10), 1500);
      expect(UserProfile.calculateWaterMl(weightKg: 200), 5000);
    });
  });

  group('waterGlassesFromMl', () {
    test('convierte a vasos de 250 ml con límites 6-20', () {
      expect(UserProfile.waterGlassesFromMl(2000), 8);
      expect(UserProfile.waterGlassesFromMl(100), 6);
      expect(UserProfile.waterGlassesFromMl(10000), 20);
    });
  });

  group('calculateMacros', () {
    test('Perder grasa: 2.2 g proteína/kg y 25% grasa', () {
      final m = UserProfile.calculateMacros(
        weight: 70,
        calories: 2000,
        goal: 'Perder grasa',
      );
      expect(m.protein, 154);
      expect(m.fat, 56);
      expect(m.carbs, 220);
    });

    test('Ganar músculo: 2.0 g proteína/kg', () {
      final m = UserProfile.calculateMacros(
        weight: 70,
        calories: 2500,
        goal: 'Ganar músculo',
      );
      expect(m.protein, 140);
    });

    test('los carbohidratos nunca son negativos', () {
      final m = UserProfile.calculateMacros(
        weight: 120,
        calories: 1200,
        goal: 'Perder grasa',
      );
      expect(m.carbs, greaterThanOrEqualTo(0));
    });
  });

  group('calculateTMB', () {
    test('distingue sexo (Mifflin-St Jeor)', () {
      final male = UserProfile.calculateTMB(
        sex: 'Masculino',
        weight: 70,
        height: 175,
        age: 25,
        activityLevel: 'Sedentario',
      );
      final female = UserProfile.calculateTMB(
        sex: 'Femenino',
        weight: 70,
        height: 175,
        age: 25,
        activityLevel: 'Sedentario',
      );
      expect(male, greaterThan(female));
      expect(male, closeTo(2009, 1));
      expect(female, closeTo(1809, 1));
    });

    test('aplica el ajuste por objetivo y los límites', () {
      final maintain = UserProfile.calculateTMB(
        sex: 'Masculino',
        weight: 70,
        height: 175,
        age: 25,
        activityLevel: 'Sedentario',
      );
      final gain = UserProfile.calculateTMB(
        sex: 'Masculino',
        weight: 70,
        height: 175,
        age: 25,
        activityLevel: 'Sedentario',
        goal: 'Ganar músculo',
      );
      expect(gain, greaterThan(maintain));

      final clamped = UserProfile.calculateTMB(
        sex: 'Femenino',
        weight: 30,
        height: 140,
        age: 80,
        activityLevel: 'Sedentario',
      );
      expect(clamped, 1200);
    });
  });

  group('activityFromWeeklyWorkouts', () {
    test('mapea cantidad de entrenos a nivel de actividad', () {
      expect(UserProfile.activityFromWeeklyWorkouts(0), 'Sedentario');
      expect(UserProfile.activityFromWeeklyWorkouts(1), 'Ligero');
      expect(UserProfile.activityFromWeeklyWorkouts(3), 'Moderado');
      expect(UserProfile.activityFromWeeklyWorkouts(5), 'Activo');
      expect(UserProfile.activityFromWeeklyWorkouts(6), 'Muy activo');
    });
  });

  group('serialización', () {
    test('toMap/fromMap conserva los campos principales', () {
      final original = _profile(uid: 'abc', goal: 'Ganar músculo');
      final restored = UserProfile.fromMap(original.toMap());

      expect(restored.uid, 'abc');
      expect(restored.goal, 'Ganar músculo');
      expect(restored.currentWeight, 70);
      expect(restored.height, 175);
      expect(restored.age, 25);
    });

    test('targetWaterGlasses deriva del peso si no hay objetivo', () {
      final p = _profile(weight: 60);
      expect(p.targetWaterGlasses, 8);
    });
  });

  group('DailyLog', () {
    test('fromMap recalcula totales desde las comidas', () {
      final log = DailyLog.fromMap({
        'date': '2026-10-10',
        'waterGlasses': 5,
        'meals': [
          {
            'id': 'm1',
            'name': 'Avena',
            'mealType': 'Desayuno',
            'calories': 350,
            'proteinGrams': 20,
            'carbsGrams': 50,
            'fatGrams': 10,
          },
          {
            'id': 'm2',
            'name': 'Pollo',
            'mealType': 'Almuerzo',
            'calories': 450,
            'proteinGrams': 40,
            'carbsGrams': 0,
            'fatGrams': 25,
          },
        ],
      });

      expect(log.consumedCalories, 800);
      expect(log.proteinGrams, 60);
      expect(log.carbsGrams, 50);
      expect(log.fatGrams, 35);
      expect(log.waterGlasses, 5);
      expect(log.meals.length, 2);
    });

    test('caloriesOfType suma solo el tipo indicado', () {
      final log = DailyLog(
        date: '2026-10-10',
        meals: [
          MealEntry(
            id: '1',
            name: 'A',
            mealType: 'Desayuno',
            calories: 300,
          ),
          MealEntry(
            id: '2',
            name: 'B',
            mealType: 'Desayuno',
            calories: 200,
          ),
          MealEntry(
            id: '3',
            name: 'C',
            mealType: 'Cena',
            calories: 500,
          ),
        ],
      );
      expect(log.caloriesOfType('Desayuno'), 500);
      expect(log.caloriesOfType('Cena'), 500);
    });
  });

  group('WorkoutSetLog', () {
    test('toMap/fromMap conserva tipo y nota', () {
      const s = WorkoutSetLog(
        setNumber: 2,
        weight: 80,
        reps: 8,
        completed: true,
        type: SetType.warmup,
        note: 'sin dolor',
      );
      final r = WorkoutSetLog.fromMap(s.toMap());
      expect(r.setNumber, 2);
      expect(r.weight, 80);
      expect(r.reps, 8);
      expect(r.completed, isTrue);
      expect(r.type, SetType.warmup);
      expect(r.note, 'sin dolor');
    });

    test('fromMap sin type cae a normal (retrocompatible)', () {
      final r = WorkoutSetLog.fromMap({
        'setNumber': 1,
        'weight': 60,
        'reps': 10,
        'completed': false,
      });
      expect(r.type, SetType.normal);
      expect(r.note, '');
    });

    test('SetType.fromName tolera valores desconocidos', () {
      expect(SetType.fromName('dropset'), SetType.dropset);
      expect(SetType.fromName('xxx'), SetType.normal);
      expect(SetType.fromName(null), SetType.normal);
    });

    test('copyWith permite cambiar setNumber', () {
      const s = WorkoutSetLog(setNumber: 1, weight: 50, reps: 5);
      expect(s.copyWith(setNumber: 3).setNumber, 3);
    });
  });

  group('WorkoutExerciseLog', () {
    WorkoutExerciseLog ex({List<WorkoutSetLog>? sets, String? superset}) =>
        WorkoutExerciseLog(
          exerciseId: 'ex1',
          exerciseName: 'Press Banca',
          sets: sets ?? const [],
          supersetId: superset,
        );

    test('supersetId hace round-trip y vacío es null', () {
      final a = ex(superset: 'ss1');
      expect(WorkoutExerciseLog.fromMap(a.toMap()).supersetId, 'ss1');
      expect(a.hasSuperset, isTrue);

      final b = WorkoutExerciseLog.fromMap({
        'exerciseId': 'ex1',
        'exerciseName': 'Press Banca',
        'supersetId': '',
      });
      expect(b.supersetId, isNull);
      expect(b.hasSuperset, isFalse);
    });

    test('volume excluye calentamiento', () {
      final e = ex(sets: const [
        WorkoutSetLog(setNumber: 1, weight: 40, reps: 12, type: SetType.warmup),
        WorkoutSetLog(setNumber: 2, weight: 80, reps: 8),
        WorkoutSetLog(setNumber: 3, weight: 80, reps: 8),
      ]);
      expect(e.workingSets.length, 2);
      expect(e.volume, 1280);
    });

    test('copyWith clearSuperset quita el superset', () {
      final e = ex(superset: 'ss1');
      expect(e.copyWith(clearSuperset: true).supersetId, isNull);
    });
  });

  group('WorkoutSession helpers', () {
    test('dateKey formatea yyyy-MM-dd', () {
      expect(WorkoutSession.dateKey(DateTime(2026, 10, 5)), '2026-10-05');
    });

    test('weekdayName devuelve el día en español', () {
      expect(WorkoutSession.weekdayName(DateTime(2026, 10, 5)), 'Lunes');
      expect(WorkoutSession.weekdayName(DateTime(2026, 10, 10)), 'Sábado');
    });

    test('newSessionId incluye fecha y hora', () {
      final id = WorkoutSession.newSessionId(DateTime(2026, 10, 5, 9, 8, 7));
      expect(id, startsWith('2026-10-05_090807_'));
    });
  });
}
