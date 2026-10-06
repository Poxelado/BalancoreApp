import '../../profile/domain/user_profile.dart';

/// Resultado de la heurística de descanso.
class RestDayAdvice {
  /// true → conviene no entrenar duro hoy (o hacer movilidad ligera).
  final bool suggestRest;
  /// soft = aviso suave; strong = bastante claro que toca parar.
  final String level; // 'none' | 'soft' | 'strong'
  final String message;
  /// Días seguidos con al menos un entreno completado (hasta hoy).
  final int consecutiveTrainingDays;
  /// Entrenos completados en los últimos 7 días.
  final int sessionsLast7Days;

  const RestDayAdvice({
    required this.suggestRest,
    required this.level,
    required this.message,
    required this.consecutiveTrainingDays,
    required this.sessionsLast7Days,
  });

  static const none = RestDayAdvice(
    suggestRest: false,
    level: 'none',
    message: '',
    consecutiveTrainingDays: 0,
    sessionsLast7Days: 0,
  );
}

/// Reglas simples (sin IA) para sugerir día de descanso.
class RestDayRules {
  /// Días seguidos entrenando a partir de los cuales avisamos.
  static const int softStreak = 3;
  static const int strongStreak = 5;

  /// Entrenos en 7 días.
  static const int softWeekly = 5;
  static const int strongWeekly = 6;

  /// RPE medio alto en las últimas sesiones.
  static const double highRpe = 8.5;

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static RestDayAdvice evaluate(List<WorkoutSession> history) {
    final completed = history.where((s) => s.completed).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    if (completed.isEmpty) return RestDayAdvice.none;

    final today = _dayOnly(DateTime.now());

    // Días de calendario con ≥1 sesión completada
    final trainDays = <DateTime>{};
    for (final s in completed) {
      trainDays.add(_dayOnly(s.startedAt));
    }

    // Racha hacia atrás desde hoy o desde el último día entrenado
    var streak = 0;
    var cursor = trainDays.contains(today) ? today : today.subtract(const Duration(days: 1));
    // Si ayer no entrenó y hoy tampoco, racha 0
    if (!trainDays.contains(today) && !trainDays.contains(today.subtract(const Duration(days: 1)))) {
      streak = 0;
    } else {
      if (!trainDays.contains(today)) {
        cursor = today.subtract(const Duration(days: 1));
      }
      while (trainDays.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }

    final weekStart = today.subtract(const Duration(days: 6));
    final sessionsLast7 = completed
        .where((s) => !_dayOnly(s.startedAt).isBefore(weekStart))
        .length;

    // RPE medio de las 2 últimas sesiones (ejercicios con rpe)
    double? avgRpe;
    final rpeValues = <double>[];
    for (final s in completed.take(2)) {
      for (final e in s.exercises) {
        if (e.rpe != null && e.rpe! >= 1) rpeValues.add(e.rpe!.toDouble());
      }
    }
    if (rpeValues.isNotEmpty) {
      avgRpe = rpeValues.reduce((a, b) => a + b) / rpeValues.length;
    }

    final highRpe = avgRpe != null && avgRpe >= highRpe;

    if (streak >= strongStreak || sessionsLast7 >= strongWeekly || highRpe && streak >= softStreak) {
      final parts = <String>[];
      if (streak >= strongStreak) parts.add('$streak días seguidos entrenando');
      if (sessionsLast7 >= strongWeekly) parts.add('$sessionsLast7 sesiones esta semana');
      if (highRpe) parts.add('RPE alto (~${avgRpe!.toStringAsFixed(1)})');
      return RestDayAdvice(
        suggestRest: true,
        level: 'strong',
        message:
        'Hoy conviene descanso o algo muy suave. ${parts.join(' · ')}.',
        consecutiveTrainingDays: streak,
        sessionsLast7Days: sessionsLast7,
      );
    }

    if (streak >= softStreak || sessionsLast7 >= softWeekly || highRpe) {
      final reason = highRpe
          ? 'El esfuerzo percibido viene alto'
          : (streak >= softStreak
          ? 'Llevas $streak días seguidos'
          : 'Ya van $sessionsLast7 entrenos en 7 días');
      return RestDayAdvice(
        suggestRest: true,
        level: 'soft',
        message: '$reason. Valora un día de recuperación.',
        consecutiveTrainingDays: streak,
        sessionsLast7Days: sessionsLast7,
      );
    }

    return RestDayAdvice(
      suggestRest: false,
      level: 'none',
      message: '',
      consecutiveTrainingDays: streak,
      sessionsLast7Days: sessionsLast7,
    );
  }
}
