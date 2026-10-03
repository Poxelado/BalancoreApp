import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/notifications/notification_preferences.dart';
import '../../../../core/notifications/notification_service.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _pickTime(
      BuildContext context,
      int currentMinutes,
      void Function(int) onPicked,
      ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
    );
    if (picked != null) onPicked(picked.hour * 60 + picked.minute);
  }

  Future<void> _pickWeekday(
      BuildContext context,
      int current,
      void Function(int) onPicked,
      ) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Día del recordatorio de peso')),
            for (var d = 1; d <= 7; d++)
              ListTile(
                title: Text(NotificationPreferences.weekdayNames[d]!),
                trailing: current == d ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, d),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) onPicked(chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final n = ref.read(notificationPreferencesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('Recordatorios',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: primary, fontSize: 16)),
          const SizedBox(height: 8),
          _tile(
            title: 'Entrenamiento',
            subtitle: prefs.smartEnabled &&
                NotificationService.instance.smartWorkoutHour != null
                ? 'Inteligente · ~${NotificationService.instance.smartWorkoutHour.toString().padLeft(2, '0')}:00'
                : NotificationPreferences.formatMinutes(prefs.workoutMinutes),
            value: prefs.workoutEnabled,
            onChanged: (v) => n.update(prefs.copyWith(workoutEnabled: v)),
            onTime: () => _pickTime(context, prefs.workoutMinutes,
                    (m) => n.update(prefs.copyWith(workoutMinutes: m))),
          ),
          _tile(
            title: 'Comidas',
            subtitle: prefs.smartEnabled &&
                NotificationService.instance.smartMealHour != null
                ? 'Inteligente · ~${NotificationService.instance.smartMealHour.toString().padLeft(2, '0')}:00'
                : NotificationPreferences.formatMinutes(prefs.mealMinutes),
            value: prefs.mealEnabled,
            onChanged: (v) => n.update(prefs.copyWith(mealEnabled: v)),
            onTime: () => _pickTime(context, prefs.mealMinutes,
                    (m) => n.update(prefs.copyWith(mealMinutes: m))),
          ),
          _tile(
            title: 'Peso (semanal)',
            subtitle:
            '${NotificationPreferences.weekdayNames[prefs.weightWeekday]} · ${NotificationPreferences.formatMinutes(prefs.weightMinutes)}',
            value: prefs.weightEnabled,
            onChanged: (v) => n.update(prefs.copyWith(weightEnabled: v)),
            onTime: () async {
              await _pickWeekday(context, prefs.weightWeekday,
                      (d) => n.update(prefs.copyWith(weightWeekday: d)));
              if (context.mounted) {
                await _pickTime(context, prefs.weightMinutes,
                        (m) => n.update(prefs.copyWith(weightMinutes: m)));
              }
            },
          ),
          _tile(
            title: 'Progreso semanal',
            subtitle:
            'Domingo · ${NotificationPreferences.formatMinutes(prefs.progressMinutes)}',
            value: prefs.progressEnabled,
            onChanged: (v) => n.update(prefs.copyWith(progressEnabled: v)),
            onTime: () => _pickTime(context, prefs.progressMinutes,
                    (m) => n.update(prefs.copyWith(progressMinutes: m))),
          ),
          _tile(
            title: 'Racha (después de mediodía)',
            subtitle:
            'Cada ${prefs.streakIntervalHours} h desde las 12:00 (3 de 4 hábitos)',
            value: prefs.streakEnabled,
            onChanged: (v) => n.update(prefs.copyWith(streakEnabled: v)),
            onTime: () async {
              final c = await showModalBottomSheet<int>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text('Cada 4 horas'),
                        subtitle: const Text('12:00 · 16:00 · 20:00'),
                        onTap: () => Navigator.pop(ctx, 4),
                      ),
                      ListTile(
                        title: const Text('Cada 6 horas'),
                        subtitle: const Text('12:00 · 18:00'),
                        onTap: () => Navigator.pop(ctx, 6),
                      ),
                    ],
                  ),
                ),
              );
              if (c != null) {
                n.update(prefs.copyWith(streakIntervalHours: c));
              }
            },
          ),
          const SizedBox(height: 16),
          Text('Inteligentes',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: primary, fontSize: 16)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Horarios inteligentes'),
            subtitle: const Text(
                'Entreno y comida según tu historial (si hay datos)'),
            value: prefs.smartEnabled,
            onChanged: (v) => n.update(prefs.copyWith(smartEnabled: v)),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await NotificationService.instance.showTest();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notificación de prueba enviada')),
                );
              }
            },
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Probar notificación'),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    VoidCallback? onTime,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: InkWell(
          onTap: onTime,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Flexible(child: Text(subtitle)),
                if (onTime != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.edit_outlined, size: 14),
                ],
              ],
            ),
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
