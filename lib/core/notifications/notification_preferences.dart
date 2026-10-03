
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class NotificationPreferences {
  final bool masterEnabled;
  final bool workoutEnabled;
  final bool mealEnabled;
  final bool weightEnabled;
  final bool progressEnabled;
  final bool streakEnabled;
  final bool smartEnabled;
  final int workoutMinutes;
  final int mealMinutes;
  final int weightMinutes;
  final int progressMinutes;
  final int weightWeekday;
  final int streakIntervalHours;

  const NotificationPreferences({
    this.masterEnabled = false,
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
    bool? masterEnabled,
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
      masterEnabled: masterEnabled ?? this.masterEnabled,
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

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = NotificationPreferences(
      masterEnabled: p.getBool('notif_master') ?? false,
      workoutEnabled: p.getBool('notif_workout') ?? true,
      mealEnabled: p.getBool('notif_meal') ?? true,
      weightEnabled: p.getBool('notif_weight') ?? true,
      progressEnabled: p.getBool('notif_progress') ?? true,
      streakEnabled: p.getBool('notif_streak') ?? true,
      smartEnabled: p.getBool('notif_smart') ?? true,
      workoutMinutes: p.getInt('notif_workout_m') ?? 18 * 60,
      mealMinutes: p.getInt('notif_meal_m') ?? 13 * 60,
      weightMinutes: p.getInt('notif_weight_m') ?? 8 * 60,
      progressMinutes: p.getInt('notif_progress_m') ?? 19 * 60,
      weightWeekday: p.getInt('notif_weight_wd') ?? DateTime.monday,
      streakIntervalHours: p.getInt('notif_streak_int') ?? 4,
    );
    await NotificationService.instance.rescheduleFromPrefs(state);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notif_master', state.masterEnabled);
    await p.setBool('notif_workout', state.workoutEnabled);
    await p.setBool('notif_meal', state.mealEnabled);
    await p.setBool('notif_weight', state.weightEnabled);
    await p.setBool('notif_progress', state.progressEnabled);
    await p.setBool('notif_streak', state.streakEnabled);
    await p.setBool('notif_smart', state.smartEnabled);
    await p.setInt('notif_workout_m', state.workoutMinutes);
    await p.setInt('notif_meal_m', state.mealMinutes);
    await p.setInt('notif_weight_m', state.weightMinutes);
    await p.setInt('notif_progress_m', state.progressMinutes);
    await p.setInt('notif_weight_wd', state.weightWeekday);
    await p.setInt('notif_streak_int', state.streakIntervalHours);
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
