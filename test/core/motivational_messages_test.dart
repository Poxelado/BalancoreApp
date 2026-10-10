import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/core/motivation/motivational_messages.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';

WorkoutSession _session(DateTime at, {bool completed = true}) {
  return WorkoutSession(
    id: 's${at.millisecondsSinceEpoch}',
    dayName: 'Lunes',
    title: 'Entreno',
    startedAt: at,
    completed: completed,
  );
}

void main() {
  group('MotivationalMessages.pickSync', () {
    test('es determinista con la misma semilla', () {
      const ctx = MotivationContext();
      expect(
        MotivationalMessages.pickSync(ctx, seed: 42),
        MotivationalMessages.pickSync(ctx, seed: 42),
      );
    });

    test('primer entreno devuelve mensaje de bienvenida', () {
      const ctx = MotivationContext(
        justFinishedWorkout: true,
        firstWorkoutEver: true,
      );
      expect(
        MotivationalMessages.pickSync(ctx, seed: 0),
        '¡Primer entrenamiento registrado! El hábito empieza hoy.',
      );
    });

    test('tras entrenar devuelve mensaje de post-entreno', () {
      const ctx = MotivationContext(justFinishedWorkout: true);
      expect(
        MotivationalMessages.pickSync(ctx, seed: 0),
        '¡Sesión lista! Descansa y recupera para la próxima.',
      );
    });

    test('reemplaza {streak} por los días de racha', () {
      const ctx = MotivationContext(streakDays: 5);
      expect(
        MotivationalMessages.pickSync(ctx, seed: 6),
        'Racha de 5 días. No la rompas hoy.',
      );
    });

    test('reemplaza {week} por los entrenos de la semana', () {
      const ctx = MotivationContext(weekGoalMet: true, workoutsThisWeek: 4);
      expect(
        MotivationalMessages.pickSync(ctx, seed: 6),
        'Semana sólida: 4 entrenos. Así se construye.',
      );
    });

    test('día vacío devuelve un mensaje del pool de arranque', () {
      const ctx = MotivationContext();
      expect(
        MotivationalMessages.pickSync(ctx, seed: 6),
        'Un vaso de agua o una comida ya enciende el día.',
      );
    });

    test('siempre devuelve un texto no vacío', () {
      for (var seed = 0; seed < 20; seed++) {
        expect(
          MotivationalMessages.pickSync(const MotivationContext(), seed: seed),
          isNotEmpty,
        );
      }
    });
  });

  group('isRestDayFromRoutines', () {
    test('detecta el día de descanso de hoy', () {
      final today = WorkoutSession.weekdayName();
      final routines = [
        RoutineDay(day: today, title: 'Descanso', isRestDay: true),
      ];
      expect(MotivationalMessages.isRestDayFromRoutines(routines), isTrue);
    });

    test('devuelve false si hoy no es descanso', () {
      final today = WorkoutSession.weekdayName();
      final routines = [
        RoutineDay(day: today, title: 'Pecho', isRestDay: false),
      ];
      expect(MotivationalMessages.isRestDayFromRoutines(routines), isFalse);
    });
  });

  group('workoutsInCurrentWeek', () {
    test('cuenta solo sesiones completadas de esta semana', () {
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));

      final history = [
        _session(monday.add(const Duration(hours: 8))),
        _session(monday.add(const Duration(hours: 18))),
        _session(now), // hoy, misma semana
        _session(monday.subtract(const Duration(days: 1))), // semana pasada
        _session(now, completed: false), // incompleta
      ];

      expect(MotivationalMessages.workoutsInCurrentWeek(history), 3);
    });

    test('sin historial devuelve 0', () {
      expect(MotivationalMessages.workoutsInCurrentWeek(const []), 0);
    });
  });
}
