
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

  Future<void> _test(BuildContext context, String kind, String label) async {
    await NotificationService.instance.requestPermission();
    await NotificationService.instance.showTestKind(kind);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prueba enviada: $label')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(notificationPreferencesProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final n = ref.read(notificationPreferencesProvider.notifier);
    final on = prefs.masterEnabled;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── Maestro Sí / No ──
          Card(
            child: SwitchListTile(
              title: Text(
                'Recibir notificaciones',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: onSurface,
                ),
              ),
              subtitle: Text(
                on
                    ? 'Activadas — se enviarán los recordatorios'
                    : 'Desactivadas — no se enviará ningún aviso',
              ),
              value: on,
              activeColor: primary,
              onChanged: (v) async {
                if (v) {
                  final ok =
                  await NotificationService.instance.requestPermission();
                  await n.update(prefs.copyWith(masterEnabled: true));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Permiso concedido'
                              : 'Activa notificaciones en Ajustes del sistema',
                        ),
                      ),
                    );
                  }
                } else {
                  await n.update(prefs.copyWith(masterEnabled: false));
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          IgnorePointer(
            ignoring: !on,
            child: Opacity(
              opacity: on ? 1 : 0.4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recordatorios',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _tile(
                    title: 'Entrenamiento',
                    subtitle: prefs.smartEnabled &&
                        NotificationService.instance.smartWorkoutHour !=
                            null
                        ? 'Inteligente · ~${NotificationService.instance.smartWorkoutHour.toString().padLeft(2, '0')}:00'
                        : NotificationPreferences.formatMinutes(
                        prefs.workoutMinutes),
                    value: prefs.workoutEnabled,
                    onChanged: (v) =>
                        n.update(prefs.copyWith(workoutEnabled: v)),
                    onTime: () => _pickTime(context, prefs.workoutMinutes,
                            (m) => n.update(prefs.copyWith(workoutMinutes: m))),
                    onTest: () => _test(context, 'workout', 'Entrenamiento'),
                  ),
                  _tile(
                    title: 'Comidas',
                    subtitle: prefs.smartEnabled &&
                        NotificationService.instance.smartMealHour != null
                        ? 'Inteligente · ~${NotificationService.instance.smartMealHour.toString().padLeft(2, '0')}:00'
                        : NotificationPreferences.formatMinutes(
                        prefs.mealMinutes),
                    value: prefs.mealEnabled,
                    onChanged: (v) =>
                        n.update(prefs.copyWith(mealEnabled: v)),
                    onTime: () => _pickTime(context, prefs.mealMinutes,
                            (m) => n.update(prefs.copyWith(mealMinutes: m))),
                    onTest: () => _test(context, 'meal', 'Comida'),
                  ),
                  _tile(
                    title: 'Peso (semanal)',
                    subtitle:
                    '${NotificationPreferences.weekdayNames[prefs.weightWeekday]} · ${NotificationPreferences.formatMinutes(prefs.weightMinutes)}',
                    value: prefs.weightEnabled,
                    onChanged: (v) =>
                        n.update(prefs.copyWith(weightEnabled: v)),
                    onTime: () async {
                      await _pickWeekday(context, prefs.weightWeekday,
                              (d) => n.update(prefs.copyWith(weightWeekday: d)));
                      if (context.mounted) {
                        await _pickTime(context, prefs.weightMinutes,
                                (m) => n.update(prefs.copyWith(weightMinutes: m)));
                      }
                    },
                    onTest: () => _test(context, 'weight', 'Peso'),
                  ),
                  _tile(
                    title: 'Progreso semanal',
                    subtitle:
                    'Domingo · ${NotificationPreferences.formatMinutes(prefs.progressMinutes)}',
                    value: prefs.progressEnabled,
                    onChanged: (v) =>
                        n.update(prefs.copyWith(progressEnabled: v)),
                    onTime: () => _pickTime(context, prefs.progressMinutes,
                            (m) => n.update(prefs.copyWith(progressMinutes: m))),
                    onTest: () => _test(context, 'progress', 'Progreso'),
                  ),
                  _tile(
                    title: 'Racha (después de mediodía)',
                    subtitle:
                    'Cada ${prefs.streakIntervalHours} h desde las 12:00 (3 de 4)',
                    value: prefs.streakEnabled,
                    onChanged: (v) =>
                        n.update(prefs.copyWith(streakEnabled: v)),
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
                    onTest: () => _test(context, 'streak', 'Racha'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Inteligentes',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primary,
                      fontSize: 16,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Horarios inteligentes'),
                    subtitle: const Text(
                        'Entreno y comida según tu historial (si hay datos)'),
                    value: prefs.smartEnabled,
                    onChanged: (v) =>
                        n.update(prefs.copyWith(smartEnabled: v)),
                  ),
                ],
              ),
            ),
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
    VoidCallback? onTest,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          children: [
            SwitchListTile(
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
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
            if (onTest != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTest,
                  icon: const Icon(Icons.notifications_active_outlined, size: 16),
                  label: const Text('Probar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
