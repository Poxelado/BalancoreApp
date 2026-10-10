import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/core/notifications/notification_preferences.dart';

void main() {
  group('NotificationPreferences', () {
    test('valores por defecto coherentes', () {
      const p = NotificationPreferences();
      expect(p.masterEnabled, isFalse);
      expect(p.workoutEnabled, isTrue);
      expect(p.inactivityDays, 3);
      expect(p.workoutMinutes, 18 * 60);
      expect(p.weightWeekday, DateTime.monday);
      expect(p.streakIntervalHours, 4);
    });

    test('copyWith solo cambia los campos indicados', () {
      const p = NotificationPreferences();
      final q = p.copyWith(masterEnabled: true, inactivityDays: 5);
      expect(q.masterEnabled, isTrue);
      expect(q.inactivityDays, 5);
      expect(q.workoutEnabled, p.workoutEnabled);
      expect(q.mealMinutes, p.mealMinutes);
    });

    test('formatMinutes formatea HH:mm', () {
      expect(NotificationPreferences.formatMinutes(0), '00:00');
      expect(NotificationPreferences.formatMinutes(75), '01:15');
      expect(NotificationPreferences.formatMinutes(18 * 60), '18:00');
      expect(NotificationPreferences.formatMinutes(23 * 60 + 59), '23:59');
    });

    test('weekdayNames cubre los 7 días', () {
      expect(NotificationPreferences.weekdayNames.length, 7);
      expect(NotificationPreferences.weekdayNames[1], 'Lunes');
      expect(NotificationPreferences.weekdayNames[7], 'Domingo');
    });
  });
}
