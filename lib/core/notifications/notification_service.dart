import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'notification_preferences.dart';

class _NotifId {
  static const workout = 1001;
  static const meal = 1002;
  static const weight = 1003;
  static const progress = 1004;
  /// 1100–1110 slots de racha
  static const streakBase = 1100;
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  int? smartWorkoutHour;
  int? smartMealHour;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Santiago'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    _ready = true;
  }

  void learnFromHistory({
    required List<DateTime> workoutTimes,
    required List<DateTime> mealTimes,
  }) {
    smartWorkoutHour = _mostCommonHour(workoutTimes);
    smartMealHour = _mostCommonHour(mealTimes);
  }

  int? _mostCommonHour(List<DateTime> times) {
    if (times.isEmpty) return null;
    final counts = <int, int>{};
    for (final t in times) {
      final h = t.toLocal().hour;
      counts[h] = (counts[h] ?? 0) + 1;
    }
    var bestH = counts.keys.first;
    var bestC = 0;
    counts.forEach((h, c) {
      if (c > bestC) {
        bestC = c;
        bestH = h;
      }
    });
    return bestC >= 2 ? bestH : null;
  }

  int _effectiveMinutes(bool smart, int? smartHour, int fallback) {
    if (smart && smartHour != null) return smartHour * 60;
    return fallback;
  }

  Future<void> rescheduleFromPrefs(NotificationPreferences prefs) async {
    if (!_ready) await init();
    await _plugin.cancelAll();

    if (prefs.workoutEnabled) {
      await _scheduleDaily(
        id: _NotifId.workout,
        minutes: _effectiveMinutes(
            prefs.smartEnabled, smartWorkoutHour, prefs.workoutMinutes),
        title: 'Hora de entrenar 💪',
        body: 'Tu rutina de hoy te espera en Balancore.',
      );
    }

    if (prefs.mealEnabled) {
      await _scheduleDaily(
        id: _NotifId.meal,
        minutes: _effectiveMinutes(
            prefs.smartEnabled, smartMealHour, prefs.mealMinutes),
        title: 'Registra tu comida 🍽️',
        body: 'Anota lo que comiste para macros y racha.',
      );
    }

    // Peso: SEMANAL
    if (prefs.weightEnabled) {
      await _scheduleWeekly(
        id: _NotifId.weight,
        minutes: prefs.weightMinutes,
        weekday: prefs.weightWeekday,
        title: 'Registra tu peso ⚖️',
        body: 'Un registro semanal basta para ver tu tendencia.',
      );
    }

    if (prefs.progressEnabled) {
      await _scheduleWeekly(
        id: _NotifId.progress,
        minutes: prefs.progressMinutes,
        weekday: DateTime.sunday,
        title: 'Revisa tu progreso 📊',
        body: 'Mira tu constancia y hábitos de la semana.',
      );
    }

    // Racha: cada 4 o 6 h después de las 12:00
    if (prefs.streakEnabled) {
      await _scheduleStreakNudges(prefs.streakIntervalHours);
    }

    if (kDebugMode) {
      debugPrint('[Notif] reprogramadas · streak cada ${prefs.streakIntervalHours}h');
    }
  }

  /// 12:00, luego +interval hasta la noche (máx ~22:00).
  Future<void> _scheduleStreakNudges(int intervalHours) async {
    final interval = intervalHours == 6 ? 6 : 4;
    var slot = 0;
    for (var hour = 12; hour <= 22; hour += interval) {
      final id = _NotifId.streakBase + slot;
      await _scheduleDaily(
        id: id,
        minutes: hour * 60,
        title: '¡No pierdas tu racha! 🔥',
        body:
        'Registra al menos 3 de 4 (entreno, agua, sueño o comida) antes de que termine el día.',
      );
      slot++;
      if (slot > 8) break;
    }
  }

  Future<void> _scheduleDaily({
    required int id,
    required int minutes,
    required String title,
    required String body,
  }) async {
    final when = _nextInstanceOfTime(minutes);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleWeekly({
    required int id,
    required int minutes,
    required int weekday,
    required String title,
    required String body,
  }) async {
    final when = _nextInstanceOfWeekday(weekday, minutes);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'balancore_reminders',
        'Recordatorios Balancore',
        channelDescription: 'Entreno, comidas, peso, racha y progreso',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int minutesFromMidnight) {
    final now = tz.TZDateTime.now(tz.local);
    final h = minutesFromMidnight ~/ 60;
    final m = minutesFromMidnight % 60;
    var scheduled =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int minutesFromMidnight) {
    final now = tz.TZDateTime.now(tz.local);
    final h = minutesFromMidnight ~/ 60;
    final m = minutesFromMidnight % 60;
    var scheduled =
    tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
    while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> showTest() async {
    if (!_ready) await init();
    await _plugin.show(
      9999,
      'Balancore',
      'Las notificaciones están activas ✅',
      _details(),
    );
  }
}
