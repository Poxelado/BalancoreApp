import '../../features/profile/domain/user_profile.dart';

class MotivationContext {
  final int streakDays;
  final bool streakReadyToday;
  final bool trainedToday;
  final bool isRestDay;
  final bool firstWorkoutEver;
  final bool weekGoalMet;
  final int workoutsThisWeek;
  final int mealsToday;
  final bool justFinishedWorkout;

  const MotivationContext({
    this.streakDays = 0,
    this.streakReadyToday = false,
    this.trainedToday = false,
    this.isRestDay = false,
    this.firstWorkoutEver = false,
    this.weekGoalMet = false,
    this.workoutsThisWeek = 0,
    this.mealsToday = 0,
    this.justFinishedWorkout = false,
  });

  String get key => [
    streakDays,
    streakReadyToday,
    trainedToday,
    isRestDay,
    firstWorkoutEver,
    weekGoalMet,
    workoutsThisWeek,
    mealsToday,
    justFinishedWorkout,
  ].join('|');
}

class MotivationalMessages {
  MotivationalMessages._();

  static int _rotate = 0;
  static void advance() => _rotate++;

  static const _firstWorkout = [
    '¡Primer entrenamiento registrado! El hábito empieza hoy.',
    'Ya diste el paso más difícil: empezar. Sigue así.',
    'Primera sesión guardada. Cada rep cuenta.',
  ];
  static const _afterWorkout = [
    '¡Sesión lista! Descansa y recupera para la próxima.',
    'Buen trabajo. La constancia gana a la intensidad suelta.',
    'Entrenamiento guardado. Hidrátate y come algo decente.',
  ];
  static const _streak = [
    'Racha de {streak} días. No la rompas hoy.',
    '{streak} días seguidos. Eres de los que cumplen.',
    'Llevas {streak} días. Un hábito más y la racha sigue viva.',
  ];
  static const _streakReady = [
    'Hoy ya sumaste a la racha. Orgullo bien ganado.',
    '3 de 4 hábitos: racha segura por hoy. Buen trabajo.',
  ];
  static const _restDay = [
    'Día de descanso sugerido. Recuperar también es progreso.',
    'Sin entreno obligatorio hoy. Agua, sueño y comida igual cuentan.',
    'Descanso activo: camina, estira, duerme bien.',
  ];
  static const _weekDone = [
    'Semana sólida: {week} entrenos. Así se construye.',
    '{week} sesiones esta semana. Cierra con comida y sueño.',
  ];
  static const _emptyDay = [
    'Un vaso de agua o una comida ya enciende el día.',
    'No hace falta perfecto: registra algo y avanza.',
    'Pequeños registros diarios vencen a la motivación de un día.',
  ];
  static const _generic = [
    'Constancia > motivación. Un paso más hoy.',
    'Tu yo de mañana agradece lo que haces ahora.',
    'No busques el día perfecto: busca el día hecho.',
    'Agua, sueño o un bite: elige uno y marca el día.',
  ];

  static String pick(MotivationContext ctx, {int? seed}) {
    final list = _candidates(ctx);
    if (list.isEmpty) return _generic.first;
    final i = ((seed ?? 0) + _rotate).abs() % list.length;
    return list[i]
        .replaceAll('{streak}', '${ctx.streakDays}')
        .replaceAll('{week}', '${ctx.workoutsThisWeek}');
  }

  static List<String> _candidates(MotivationContext ctx) {
    if (ctx.justFinishedWorkout && ctx.firstWorkoutEver) return _firstWorkout;
    if (ctx.justFinishedWorkout) return _afterWorkout;
    if (ctx.firstWorkoutEver && !ctx.trainedToday) {
      return [
        'Tu primer entreno está a un tap. Abre Rutina cuando quieras.',
        'Hoy puede ser el día 1. No hace falta una sesión perfecta.',
      ];
    }
    if (ctx.streakReadyToday) return [..._streakReady, ..._generic];
    if (ctx.streakDays >= 3) return _streak;
    if (ctx.isRestDay && !ctx.trainedToday) return [..._restDay, ..._generic];
    if (ctx.weekGoalMet) return [..._weekDone, ..._generic, ..._emptyDay];
    if (ctx.mealsToday == 0 && !ctx.trainedToday && ctx.streakDays == 0) {
      return [..._emptyDay, ..._generic];
    }
    return _generic;
  }

  static bool isRestDayFromRoutines(List<RoutineDay> routines) {
    final name = WorkoutSession.weekdayName();
    try {
      return routines.firstWhere((r) => r.day == name).isRestDay;
    } catch (_) {
      return false;
    }
  }

  static int workoutsInCurrentWeek(List<WorkoutSession> history) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    var n = 0;
    for (final s in history) {
      if (!s.completed) continue;
      final d = s.startedAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      if (!day.isBefore(monday)) n++;
    }
    return n;
  }
}
