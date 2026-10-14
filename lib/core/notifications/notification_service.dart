import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'notification_preferences.dart';

class _NotifId {
  static const workout = 1001;
  static const meal = 1002;
  static const weight = 1003;
  static const progress = 1004;
  /// 1100–1110 slots de racha
  static const streakBase = 1100;
  static const inactivity = 1200;
  static const restDone = 1300;
  static const restTimer = 1301;
  static const steps = 1400;
  /// 9900+ avisos de prueba (nunca colisionan con los reales)
  static const testBase = 9900;
}

/// Un canal por tema: así el usuario puede silenciar uno sin apagar el resto
/// desde los ajustes del sistema.
class _Channel {
  static const workout = ('balancore_workout', 'Entrenamiento');
  static const meal = ('balancore_meal', 'Comidas');
  static const weight = ('balancore_weight', 'Peso');
  static const progress = ('balancore_progress', 'Progreso');
  static const streak = ('balancore_streak', 'Racha');
  static const rest = ('balancore_rest', 'Descanso');
  static const restCountdown = ('balancore_rest_countdown', 'Temporizador de descanso');
  static const general = ('balancore_general', 'General');
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  int? smartWorkoutHour;
  int? smartMealHour;

  /// Id del aviso de fin de descanso (cancelable desde [cancelRestTimer]).
  static const int kRestDoneId = _NotifId.restDone;
  static const int kRestTimerId = _NotifId.restTimer;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Santiago'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // No pedimos permisos en el arranque: se solicitan cuando el usuario
    // activa las notificaciones (evita el prompt apenas abre la app).
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  /// true = concedido. Solo abre los ajustes del sistema si el permiso quedó
  /// denegado de forma permanente; en una denegación simple devuelve false
  /// para que la UI pueda volver a pedirlo más adelante.
  Future<bool> requestPermission() async {
    if (!_ready) await init();
    var status = await Permission.notification.status;
    if (status.isGranted) return true;

    status = await Permission.notification.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  /// Abre los ajustes del sistema para que el usuario habilite o silencie
  /// notificaciones (incluye los canales por tema en Android).
  Future<void> openSystemSettings() async {
    await openAppSettings();
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

    if (!prefs.masterEnabled) return;

    if (prefs.workoutEnabled) {
      await _scheduleDaily(
        id: _NotifId.workout,
        minutes: _effectiveMinutes(
            prefs.smartEnabled, smartWorkoutHour, prefs.workoutMinutes),
        title: 'Hora de entrenar 💪',
        body: 'Tu rutina de hoy te espera en Balancore.',
        channel: _Channel.workout,
      );
    }

    if (prefs.mealEnabled) {
      await _scheduleDaily(
        id: _NotifId.meal,
        minutes: _effectiveMinutes(
            prefs.smartEnabled, smartMealHour, prefs.mealMinutes),
        title: 'Registra tu comida 🍽️',
        body: 'Anota lo que comiste para macros y racha.',
        channel: _Channel.meal,
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
        channel: _Channel.weight,
      );
    }

    if (prefs.progressEnabled) {
      await _scheduleWeekly(
        id: _NotifId.progress,
        minutes: prefs.progressMinutes,
        weekday: DateTime.sunday,
        title: 'Revisa tu progreso 📊',
        body: 'Mira tu constancia y hábitos de la semana.',
        channel: _Channel.progress,
      );
    }

    // Racha: cada 4 o 6 h después de las 12:00
    if (prefs.streakEnabled) {
      await _scheduleStreakNudges(prefs.streakIntervalHours);
    }

    if (kDebugMode) {
      debugPrint(
          '[Notif] reprogramadas · streak cada ${prefs.streakIntervalHours}h');
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
        channel: _Channel.streak,
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
    required (String, String) channel,
  }) async {
    final when = _nextInstanceOfTime(minutes);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      _details(channel),
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
    required (String, String) channel,
  }) async {
    final when = _nextInstanceOfWeekday(weekday, minutes);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      _details(channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  NotificationDetails _details(
    (String, String) channel, {
    Importance importance = Importance.defaultImportance,
    Priority priority = Priority.defaultPriority,
  }) {
    final (id, name) = channel;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        name,
        channelDescription: 'Recordatorios de Balancore · $name',
        importance: importance,
        priority: priority,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
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

  /// Avisa de que el descanso terminó. Se dispara aunque la app esté en
  /// segundo plano, para no perder el aviso al tener la pantalla apagada.
  ///
  /// Las notificaciones del descanso son un extra: si el plugin no está
  /// disponible (permisos denegados, sin plataforma de notificaciones) el
  /// entrenamiento debe seguir funcionando igual.
  Future<void> showRestDone() async {
    try {
      if (!_ready) await init();
      // Retira el contador en vivo y el aviso programado, y anuncia el fin.
      await _plugin.cancel(kRestTimerId);
      await _plugin.cancel(kRestDoneId);
      await _plugin.show(
        kRestDoneId,
        'Descanso terminado ⏱️',
        'Puedes con la siguiente serie.',
        _details(_Channel.rest,
            importance: Importance.high, priority: Priority.high),
      );
    } catch (e) {
      debugPrint('notifications: no se pudo avisar del fin de descanso: $e');
    }
  }

  /// Programa el aviso de fin de descanso en [seconds] y muestra un contador
  /// en vivo (cronómetro descendente de Android) mientras dura. El aviso de fin
  /// se calendariza para que llegue aunque la app quede en segundo plano.
  Future<void> showRestTimer(int seconds) async {
    try {
      if (!_ready) await init();
      final ends = DateTime.now().add(Duration(seconds: seconds));
      await _plugin.cancel(kRestDoneId);
      await _plugin.zonedSchedule(
        kRestDoneId,
        'Descanso terminado ⏱️',
        'Puedes con la siguiente serie.',
        tz.TZDateTime.from(ends, tz.local),
        _details(_Channel.rest,
            importance: Importance.high, priority: Priority.high),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      await _plugin.show(
        kRestTimerId,
        'Descanso en curso',
        'Termina en ${_humanSeconds(seconds)}',
        _countdownDetails(ends),
      );
    } catch (e) {
      debugPrint('notifications: no se pudo programar el descanso: $e');
    }
  }

  /// Contador en vivo: Android muestra un cronómetro descendente desde [ends].
  NotificationDetails _countdownDetails(DateTime ends) {
    final (id, name) = _Channel.restCountdown;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        id,
        name,
        channelDescription: 'Contador del descanso entre series',
        importance: Importance.low,
        priority: Priority.low,
        icon: '@mipmap/ic_launcher',
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: true,
        usesChronometer: true,
        chronometerCountDown: true,
        when: ends.millisecondsSinceEpoch,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  /// Cancela el descanso: tanto el contador en vivo como el aviso de fin.
  Future<void> cancelRestTimer() async {
    try {
      if (!_ready) await init();
      await _plugin.cancel(kRestTimerId);
      await _plugin.cancel(kRestDoneId);
    } catch (_) {
      // Sin plugin: no hay nada que cancelar.
    }
  }

  static String _humanSeconds(int s) {
    if (s >= 60) {
      final m = s ~/ 60;
      final r = s % 60;
      return r == 0 ? '$m min' : '$m min $r s';
    }
    return '$s s';
  }

  Future<void> showInactivity(String body) async {
    if (!_ready) await init();
    await _plugin.show(
      _NotifId.inactivity,
      'Te echamos de menos 👋',
      body,
      _details(_Channel.general),
    );
  }

  /// Confirma que el contador de pasos quedó activo. Es un aviso informativo:
  /// recuerda que funciona en 2do plano y puede consumir algo de batería.
  Future<void> showStepCounterActive() async {
    try {
      if (!_ready) await init();
      await _plugin.show(
        _NotifId.steps,
        'Contador de pasos activado 🚶',
        'Seguirá contando quedándose en 2do plano y sumará tus pasos como kcal '
            'del día. Puede usar algo de batería; puedes apagarlo en Ajustes.',
        _details(_Channel.general),
      );
    } catch (e) {
      debugPrint('notifications: no se pudo avisar del podómetro: $e');
    }
  }

  Future<void> showTest() async {
    await showTestKind('general');
  }

  /// Prueba inmediata por tipo.
  Future<void> showTestKind(String kind) async {
    if (!_ready) await init();
    final map = {
      'workout': (
        _NotifId.testBase + 1,
        'Prueba · Entrenamiento 💪',
        'Así se verá el recordatorio de entrenar.',
        _Channel.workout,
      ),
      'meal': (
        _NotifId.testBase + 2,
        'Prueba · Comida 🍽️',
        'Así se verá el recordatorio de registrar comida.',
        _Channel.meal,
      ),
      'weight': (
        _NotifId.testBase + 3,
        'Prueba · Peso ⚖️',
        'Así se verá el recordatorio semanal de peso.',
        _Channel.weight,
      ),
      'progress': (
        _NotifId.testBase + 4,
        'Prueba · Progreso 📊',
        'Así se verá el recordatorio de revisar progreso.',
        _Channel.progress,
      ),
      'streak': (
        _NotifId.testBase + 5,
        'Prueba · Racha 🔥',
        'Registra 3 de 4 hábitos para no perder la racha.',
        _Channel.streak,
      ),
      'inactivity': (
        _NotifId.testBase + 6,
        'Te echamos de menos 👋',
        'Llevas varios días sin registrar. Vuelve a Balancore y retoma el hábito.',
        _Channel.general,
      ),
      'general': (
        _NotifId.testBase,
        'Balancore',
        'Las notificaciones están activas ✅',
        _Channel.general,
      ),
    };
    final data = map[kind] ?? map['general']!;
    await _plugin.show(data.$1, data.$2, data.$3, _details(data.$4));
  }
}
