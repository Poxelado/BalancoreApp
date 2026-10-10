import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/profile/domain/macro_week_analysis.dart';

DailyLog _log(
  String date, {
  int calories = 0,
  int protein = 0,
  int carbs = 0,
  int fat = 0,
}) {
  return DailyLog(
    date: date,
    consumedCalories: calories,
    proteinGrams: protein,
    carbsGrams: carbs,
    fatGrams: fat,
  );
}

void main() {
  group('startOfWeek', () {
    test('devuelve el lunes de la semana del día dado', () {
      expect(MacroWeekAnalysis.startOfWeek(DateTime(2026, 10, 10)),
          DateTime(2026, 10, 5));
      expect(MacroWeekAnalysis.startOfWeek(DateTime(2026, 10, 5)),
          DateTime(2026, 10, 5));
      expect(MacroWeekAnalysis.startOfWeek(DateTime(2026, 10, 11)),
          DateTime(2026, 10, 5));
    });
  });

  group('build', () {
    final now = DateTime(2026, 10, 10);

    test('promedia solo los días con datos de la semana actual', () {
      final report = MacroWeekAnalysis.build(
        logs: [
          _log('2026-10-06', calories: 500, protein: 40),
          _log('2026-10-07', calories: 700, protein: 60),
          _log('2026-10-01', calories: 999), // semana anterior
        ],
        profile: null,
        now: now,
      );

      expect(report.daysWithData, 2);
      expect(report.avgCalories, 600);
      expect(report.avgProtein, 50);
      expect(report.weekStart, DateTime(2026, 10, 5));
      expect(report.weekEnd, DateTime(2026, 10, 11));
    });

    test('calcula delta frente a la semana anterior', () {
      final report = MacroWeekAnalysis.build(
        logs: [
          _log('2026-10-06', calories: 600, protein: 50),
          _log('2026-09-29', calories: 400, protein: 30),
        ],
        profile: null,
        now: now,
      );

      expect(report.prevAvgCalories, 400);
      expect(report.deltaCalories, 200);
      expect(report.deltaProtein, 20);
    });

    test('sin datos previos el delta es null', () {
      final report = MacroWeekAnalysis.build(
        logs: [_log('2026-10-06', calories: 600)],
        profile: null,
        now: now,
      );
      expect(report.prevAvgCalories, isNull);
      expect(report.deltaCalories, isNull);
    });

    test('usa los objetivos del perfil para contar días cumplidos', () {
      final profile = UserProfile(
        uid: 'u1',
        sex: 'Masculino',
        currentWeight: 70,
        height: 175,
        age: 25,
        activityLevel: 'Moderado',
        goal: 'Mantenimiento',
        targetCalories: 2000,
        targetProtein: 150,
      );
      final report = MacroWeekAnalysis.build(
        logs: [
          _log('2026-10-06', calories: 2000, protein: 150),
          _log('2026-10-07', calories: 1000, protein: 50),
        ],
        profile: profile,
        now: now,
      );

      expect(report.targetCalories, 2000);
      expect(report.targetProtein, 150);
      expect(report.daysHitCalories, 1);
      expect(report.daysHitProtein, 1);
    });

    test('sin días con datos no divide por cero', () {
      final report = MacroWeekAnalysis.build(
        logs: const [],
        profile: null,
        now: now,
      );
      expect(report.daysWithData, 0);
      expect(report.avgCalories, 0);
      expect(report.deltaCalories, isNull);
    });
  });
}
