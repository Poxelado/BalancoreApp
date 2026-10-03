import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class NotificationPreferences {
  final bool workoutEnabled;
  final bool mealEnabled;
  final bool weightEnabled;
  final bool progressEnabled;
  final bool streakEnabled;
  final bool smartEnabled;
  /// Minutos desde medianoche
  final int workoutMinutes;
  final int mealMinutes;
  final int weightMinutes;
  final int progressMinutes;
  /// 1=lunes … 7=domingo (DateTime.weekday)
  final int weightWeekday;
  /// 4 o 6 horas entre avisos de racha (después de las 12:00)
  final int streakIntervalHours;

  const NotificationPreferences({
    this.workoutEnabled = true,
    this.mealEnabled = true,
    this.weightEnabled = true,
    this.progressEnabled = true,
    this.streakEnabled = true,
    this.smartEnabled = true,
    this.workoutMinutes = 18 * 60,
    this.mealMinutes = 13 * 60,
    this.weightMinutes = 8 * 60,
    this.progressMinutes = 19 * 60,
    this.weightWeekday = DateTime.monday,
    this.streakIntervalHours = 4,
  });

  NotificationPreferences copyWith({
    bool? workoutEnabled,
    bool? mealEnabled,
    bool? weightEnabled,
    bool? progressEnabled,
    bool? streakEnabled,
    bool? smartEnabled,
    int? workoutMinutes,
    int? mealMinutes,
    int? weightMinutes,
    int? progressMinutes,
    int? weightWeekday,
    int? streakIntervalHours,
  }) {
    return NotificationPreferences(
      workoutEnabled: workoutEnabled ?? this.workoutEnabled,
      mealEnabled: mealEnabled ?? this.mealEnabled,
      weightEnabled: weightEnabled ?? this.weightEnabled,
      progressEnabled: progressEnabled ?? this.progressEnabled,
      streakEnabled: streakEnabled ?? this.streakEnabled,
      smartEnabled: smartEnabled ?? this.smartEnabled,
      workoutMinutes: workoutMinutes ?? this.workoutMinutes,
      mealMinutes: mealMinutes ?? this.mealMinutes,
      weightMinutes: weightMinutes ?? this.weightMinutes,
      progressMinutes: progressMinutes ?? this.progressMinutes,
      weightWeekday: weightWeekday ?? this.weightWeekday,
      streakIntervalHours: streakIntervalHours ?? this.streakIntervalHours,
    );
  }

  static String formatMinutes(int m) {
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final min = (m % 60).toString().padLeft(2, '0');
    return '$h:$min';
  }

  static const weekdayNames = {
    1: 'Lunes',
    2: 'Martes',
    3: 'Miércoles',
    4: 'Jueves',
    5: 'Viernes',
    6: 'Sábado',
    7: 'Domingo',
  };
}

class NotificationPreferencesNotifier
    extends StateNotifier<NotificationPreferences> {
  NotificationPreferencesNotifier() : super(const NotificationPreferences()) {
    _load();
  }

  static const _keys = {
    'w': 'notif_workout',
    'm': 'notif_meal',
    'wt': 'notif_weight',
    'p': 'notif_progress',
    's': 'notif_streak',
    'sm': 'notif_smart',
    'wm': 'notif_workout_m',
    'mm': 'notif_meal_m',
    'wtm': 'notif_weight_m',
    'pm': 'notif_progress_m',
    'ww': 'notif_weight_wd',
    'si': 'notif_streak_int',
  };

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = NotificationPreferences(
      workoutEnabled: p.getBool(_keys['w']!) ?? true,
      mealEnabled: p.getBool(_keys['m']!) ?? true,
      weightEnabled: p.getBool(_keys['wt']!) ?? true,
      progressEnabled: p.getBool(_keys['p']!) ?? true,
      streakEnabled: p.getBool(_keys['s']!) ?? true,
      smartEnabled: p.getBool(_keys['sm']!) ?? true,
      workoutMinutes: p.getInt(_keys['wm']!) ?? 18 * 60,
      mealMinutes: p.getInt(_keys['mm']!) ?? 13 * 60,
      weightMinutes: p.getInt(_keys['wtm']!) ?? 8 * 60,
      progressMinutes: p.getInt(_keys['pm']!) ?? 19 * 60,
      weightWeekday: p.getInt(_keys['ww']!) ?? DateTime.monday,
      streakIntervalHours: p.getInt(_keys['si']!) ?? 4,
    );
    await NotificationService.instance.rescheduleFromPrefs(state);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keys['w']!, state.workoutEnabled);
    await p.setBool(_keys['m']!, state.mealEnabled);
    await p.setBool(_keys['wt']!, state.weightEnabled);
    await p.setBool(_keys['p']!, state.progressEnabled);
    await p.setBool(_keys['s']!, state.streakEnabled);
    await p.setBool(_keys['sm']!, state.smartEnabled);
    await p.setInt(_keys['wm']!, state.workoutMinutes);
    await p.setInt(_keys['mm']!, state.mealMinutes);
    await p.setInt(_keys['wtm']!, state.weightMinutes);
    await p.setInt(_keys['pm']!, state.progressMinutes);
    await p.setInt(_keys['ww']!, state.weightWeekday);
    await p.setInt(_keys['si']!, state.streakIntervalHours);
    await NotificationService.instance.rescheduleFromPrefs(state);
  }

  Future<void> update(NotificationPreferences next) async {
    state = next;
    await _save();
  }
}

final notificationPreferencesProvider = StateNotifierProvider<
    NotificationPreferencesNotifier, NotificationPreferences>((ref) {
  return NotificationPreferencesNotifier();
});
