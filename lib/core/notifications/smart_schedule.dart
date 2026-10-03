import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';
import 'notification_preferences.dart';
import 'notification_service.dart';

Future<void> refreshSmartNotifications(WidgetRef ref) async {
  try {
    final workouts = await ref.read(workoutHistoryProvider(30).future);
    final logs = await ref.read(dailyLogsHistoryProvider(30).future);
    final workoutTimes = [
      for (final s in workouts)
        if (s.completed) s.startedAt
    ];
    final mealTimes = <DateTime>[];
    for (final log in logs) {
      for (final meal in log.meals) {
        final p = DateTime.tryParse(meal.createdAt);
        if (p != null) mealTimes.add(p);
      }
    }
    NotificationService.instance.learnFromHistory(
      workoutTimes: workoutTimes,
      mealTimes: mealTimes,
    );
    await NotificationService.instance
        .rescheduleFromPrefs(ref.read(notificationPreferencesProvider));
  } catch (_) {}
}
