
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';
import 'notification_preferences.dart';
import 'notification_service.dart';

const _kLastInactivityNotif = 'notif_last_inactivity_day';

/// Si el usuario lleva [inactivityDays] sin entreno ni comida, avisa (máx. 1 vez/día).
Future<void> checkInactivityAndNotify(WidgetRef ref) async {
  try {
    final prefs = ref.read(notificationPreferencesProvider);
    if (!prefs.masterEnabled || !prefs.inactivityEnabled) return;

    final threshold = prefs.inactivityDays.clamp(2, 14);
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final sp = await SharedPreferences.getInstance();
    if (sp.getString(_kLastInactivityNotif) == todayKey) return;

    final workouts = await ref.read(workoutHistoryProvider(30).future);
    final logs = await ref.read(dailyLogsHistoryProvider(30).future);

    DateTime? lastTrain;
    for (final s in workouts) {
      if (!s.completed) continue;
      final d = s.startedAt.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      if (lastTrain == null || day.isAfter(lastTrain)) lastTrain = day;
    }

    DateTime? lastFood;
    for (final log in logs) {
      final hasFood =
          log.meals.isNotEmpty || log.consumedCalories > 0;
      if (!hasFood) continue;
      final parts = log.date.split('-');
      if (parts.length < 3) continue;
      try {
        final day = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        if (lastFood == null || day.isAfter(lastFood)) lastFood = day;
      } catch (_) {}
    }

    final startToday = DateTime(today.year, today.month, today.day);

    int daysSince(DateTime? last) {
      if (last == null) return 999;
      return startToday.difference(last).inDays;
    }

    final daysTrain = daysSince(lastTrain);
    final daysFood = daysSince(lastFood);

    // Aviso si AMBOS están por debajo del umbral (inactivo en general)
    // o si cualquiera supera el umbral (mensaje específico)
    final inactiveTrain = daysTrain >= threshold;
    final inactiveFood = daysFood >= threshold;
    if (!inactiveTrain && !inactiveFood) return;

    String body;
    if (inactiveTrain && inactiveFood) {
      body =
      'Llevas $threshold+ días sin entrenar ni registrar comida. ¡Retoma el ritmo en Balancore!';
    } else if (inactiveTrain) {
      body =
      'Llevas $daysTrain días sin entrenar. Una sesión corta cuenta.';
    } else {
      body =
      'Llevas $daysFood días sin registrar comida. Anota algo y mantén el hábito.';
    }

    await NotificationService.instance.showInactivity(body);
    await sp.setString(_kLastInactivityNotif, todayKey);
  } catch (_) {}
}
