import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balancore/core/achievements/achievements.dart';
import 'package:balancore/core/achievements/achievements_store.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';

WorkoutSession _session(
  DateTime at, {
  double weight = 100,
  int reps = 5,
  int sets = 1,
  bool completed = true,
}) {
  return WorkoutSession(
    id: 'ses_${at.microsecondsSinceEpoch}',
    dayName: 'Lunes',
    title: 'Push',
    startedAt: at,
    completed: completed,
    exercises: [
      WorkoutExerciseLog(
        exerciseId: 'e1',
        exerciseName: 'Press banca',
        sets: List.generate(
          sets,
          (i) => WorkoutSetLog(
            setNumber: i + 1,
            weight: weight,
            reps: reps,
            completed: true,
          ),
        ),
      ),
    ],
  );
}

DailyLog _log(
  DateTime day, {
  int water = 0,
  double sleep = 0,
  int meals = 0,
}) =>
    DailyLog(
      date: WorkoutSession.dateKey(day),
      waterGlasses: water,
      sleepHours: sleep,
      consumedCalories: meals > 0 ? meals * 300 : 0,
      meals: List.generate(
        meals,
        (i) => MealEntry(
          id: 'm$i',
          name: 'Comida $i',
          mealType: 'Almuerzo',
          calories: 300,
        ),
      ),
    );

void main() {
  group('AchievementStats.from', () {
    test('cuenta entrenos, volumen y series', () {
      final stats = AchievementStats.from(
        logs: const [],
        sessions: [
          _session(DateTime(2026, 1, 1, 10), weight: 100, reps: 5, sets: 3),
          _session(DateTime(2026, 1, 2, 10), weight: 50, reps: 10, sets: 2),
        ],
        weights: const [],
      );
      expect(stats.workouts, 2);
      // 100*5*3 + 50*10*2 = 1500 + 1000
      expect(stats.totalVolumeKg, 2500);
      expect(stats.totalSets, 5);
    });

    test('ignora sesiones no completadas', () {
      final stats = AchievementStats.from(
        logs: const [],
        sessions: [
          _session(DateTime(2026, 1, 1, 10), completed: false),
          _session(DateTime(2026, 1, 2, 10)),
        ],
        weights: const [],
      );
      expect(stats.workouts, 1);
    });

    test('detecta madrugador y noctámbulo', () {
      final morning = AchievementStats.from(
        logs: const [],
        sessions: [_session(DateTime(2026, 1, 1, 6))],
        weights: const [],
      );
      expect(morning.morningWorkout, isTrue);
      expect(morning.nightWorkout, isFalse);

      final night = AchievementStats.from(
        logs: const [],
        sessions: [_session(DateTime(2026, 1, 1, 22))],
        weights: const [],
      );
      expect(night.nightWorkout, isTrue);
      expect(night.morningWorkout, isFalse);
    });

    test('suma comidas, agua, sueño y mejor día de agua', () {
      final stats = AchievementStats.from(
        logs: [
          _log(DateTime(2026, 1, 1), water: 8, sleep: 7, meals: 3),
          _log(DateTime(2026, 1, 2), water: 12, sleep: 6, meals: 2),
        ],
        sessions: const [],
        weights: const [],
      );
      expect(stats.meals, 5);
      expect(stats.waterGlasses, 20);
      expect(stats.sleepNights, 2);
      expect(stats.bestWaterDay, 12);
      expect(stats.activeDays, 2);
    });

    test('calcula días perfectos y racha más larga', () {
      final today = DateTime.now();
      final logs = <DailyLog>[];
      final sessions = <WorkoutSession>[];
      for (var i = 1; i <= 3; i++) {
        final d = today.subtract(Duration(days: i));
        logs.add(_log(d, water: 8, sleep: 7, meals: 3));
        sessions.add(_session(DateTime(d.year, d.month, d.day, 10)));
      }
      final stats = AchievementStats.from(
        logs: logs,
        sessions: sessions,
        weights: const [],
      );
      expect(stats.perfectDays, 3);
      expect(stats.longestStreak, greaterThanOrEqualTo(3));
    });

    test('cuenta registros de peso y rutinas personalizadas', () {
      final stats = AchievementStats.from(
        logs: const [],
        sessions: const [],
        weights: [
          WeightEntry(id: 'w1', weight: 80, date: DateTime(2026, 1, 1)),
          WeightEntry(id: 'w2', weight: 79, date: DateTime(2026, 1, 2)),
        ],
        customRoutines: 1,
      );
      expect(stats.weightEntries, 2);
      expect(stats.customRoutines, 1);
    });

    test('cuenta el entreno de hoy vía trainedToday', () {
      final stats = AchievementStats.from(
        logs: const [],
        sessions: const [],
        weights: const [],
        trainedToday: true,
      );
      expect(stats.workouts, 0); // de la lista
      expect(stats.activeDays, 1);
      // La racha exige 3 de 4 hábitos, así que un día sólo con entreno no
      // cuenta como racha.
      expect(stats.longestStreak, 0);
    });
  });

  group('Catálogo', () {
    test('los ids son únicos y hay logros en cada categoría', () {
      final ids = AchievementsCatalog.all.map((a) => a.id).toSet();
      expect(ids.length, AchievementsCatalog.all.length);
      for (final c in AchievementCategory.values) {
        expect(AchievementsCatalog.all.any((a) => a.category == c), isTrue,
            reason: 'Sin logros en ${c.label}');
      }
    });

    test('unlockedBy selecciona sólo lo alcanzado', () {
      final stats = AchievementStats.from(
        logs: const [],
        sessions: [_session(DateTime(2026, 1, 1, 10))],
        weights: const [],
      );
      final unlocked = AchievementsCatalog.unlockedBy(stats).map((a) => a.id);
      expect(unlocked, contains('first_workout'));
      expect(unlocked, isNot(contains('w5')));
      expect(unlocked, isNot(contains('w100')));
    });

    test('progress se limita entre 0 y 1', () {
      final ach = AchievementsCatalog.all.firstWhere((a) => a.id == 'w5');
      expect(ach.progress(const AchievementStats(workouts: 0)), 0);
      expect(ach.progress(const AchievementStats(workouts: 5)), 1);
      expect(ach.progress(const AchievementStats(workouts: 99)), 1);
    });
  });

  group('AchievementUnlockNotifier', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('primera sincronización no avisa (inicializa en silencio)', () async {
      final notifier = AchievementUnlockNotifier();
      final stats1 = AchievementStats.from(
        logs: const [],
        sessions: [_session(DateTime(2026, 1, 1, 10))],
        weights: const [],
      );
      final first = await notifier.sync(stats1);
      expect(first, isEmpty);
      expect(notifier.state, contains('first_workout'));
    });

    test('sólo devuelve los logros nuevos', () async {
      final notifier = AchievementUnlockNotifier();
      await notifier.sync(AchievementStats.from(
        logs: const [],
        sessions: [_session(DateTime(2026, 1, 1, 10))],
        weights: const [],
      ));
      final newOnes = await notifier.sync(const AchievementStats(workouts: 5));
      final ids = newOnes.map((a) => a.id).toList();
      expect(ids, contains('w5'));
      expect(ids, isNot(contains('first_workout')));
    });

    test('persiste lo desbloqueado entre instancias', () async {
      final a = AchievementUnlockNotifier();
      await a.sync(const AchievementStats(workouts: 1));
      final b = AchievementUnlockNotifier();
      final newOnes = await b.sync(const AchievementStats(workouts: 1));
      expect(newOnes, isEmpty);
      expect(b.state, contains('first_workout'));
    });
  });
}
