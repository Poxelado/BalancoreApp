
import 'package:flutter/foundation.dart';
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
      } catch (e) {
        debugPrint('inactivity_check: fecha inválida "${log.date}": $e');
      }
    }

    final startToday = DateTime(today.year, today.month, today.day);

    // Sin ningún registro histórico no hay nada que medir: no avisamos para
    // no molestar a un usuario nuevo con un "llevas N días" falso.
    if (lastTrain == null && lastFood == null) return;

    int? daysSince(DateTime? last) {
      if (last == null) return null;
      return startToday.difference(last).inDays;
    }

    final daysTrain = daysSince(lastTrain);
    final daysFood = daysSince(lastFood);

    // Sólo cuenta como inactiva una categoría que el usuario ya usaba antes;
    // si nunca la registró, no lo tratamos como inactivo.
    final inactiveTrain = daysTrain != null && daysTrain >= threshold;
    final inactiveFood = daysFood != null && daysFood >= threshold;
    if (!inactiveTrain && !inactiveFood) return;

    String body;
    if (inactiveTrain && inactiveFood) {
      body =
      'Llevas varios días sin entrenar ni registrar comida. ¡Retoma el ritmo en Balancore!';
    } else if (inactiveTrain) {
      body =
      'Llevas $daysTrain días sin entrenar. Una sesión corta cuenta.';
    } else {
      body =
      'Llevas $daysFood días sin registrar comida. Anota algo y mantén el hábito.';
    }

    await NotificationService.instance.showInactivity(body);
    await sp.setString(_kLastInactivityNotif, todayKey);
  } catch (e) {
    debugPrint('inactivity_check: no se pudo evaluar/enviar el aviso: $e');
  }
}
