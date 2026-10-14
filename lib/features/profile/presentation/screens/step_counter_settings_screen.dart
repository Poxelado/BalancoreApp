import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../core/steps/step_counter.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';

/// Ajustes del contador de pasos opcional. Cuenta con el sensor del teléfono
/// y aporta kcal al gasto del día.
class StepCounterSettingsScreen extends ConsumerWidget {
  const StepCounterSettingsScreen({super.key});

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, bool enable) async {
    final notifier = ref.read(stepCounterProvider.notifier);
    if (!enable) {
      await notifier.disable();
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activar contador de pasos'),
        content: const Text(
          'El contador usa el sensor de actividad física y trabaja en 2do '
          'plano para no perder pasos.\n\n'
          'Puede consumir más batería y recursos del teléfono, sobre todo si '
          'lo dejas activado todo el día. Puedes apagarlo cuando quieras.\n\n'
          'Además, los pasos se traducirán a kcal y se sumarán a tu gasto '
          'diario en Nutrición.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final activated = await notifier.enable();
    if (!context.mounted) return;
    if (!activated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permiso denegado. Habilita "Actividad física" en los ajustes del sistema.',
          ),
          action: SnackBarAction(
            label: 'Abrir ajustes',
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }

    // Aviso dentro de la app.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contador de pasos activado. Se sumarán a tus kcal del día.'),
      ),
    );
    // Aviso del sistema (best-effort; no bloquea la activación).
    try {
      final granted = await NotificationService.instance.requestPermission();
      if (granted) {
        await NotificationService.instance.showStepCounterActive();
      }
    } catch (_) {
      // Sin permiso de notificaciones: el aviso en la app ya se mostró.
    }
  }

  /// Lee los pasos recibidos por el sensor y los guarda en el día.
  Future<void> _recollect(BuildContext context, WidgetRef ref) async {
    final steps = await ref.read(stepCounterProvider.notifier).recollect();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          steps == null
              ? 'No se pudo leer el sensor de pasos.'
              : 'Listo: $steps pasos guardados en el día.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(stepCounterProvider);
    final weight = ref.watch(userProfileProvider).valueOrNull?.currentWeight ?? 0;
    final kcal = stepCalories(st.steps, weight);

    return Scaffold(
      appBar: AppBar(title: const Text('Contador de pasos')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.directions_walk,
                color: AppDataColors.steps),
            title: const Text('Contar mis pasos'),
            subtitle: Text(st.enabled ? 'Activado' : 'Desactivado'),
            value: st.enabled,
            activeThumbColor: AppDataColors.steps,
            onChanged: (v) => _toggle(context, ref, v),
          ),
          if (st.permissionDenied)
            ListTile(
              leading: Icon(Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('Permiso de actividad física denegado'),
              subtitle: const Text(
                  'Actívalo en los ajustes del sistema para contar pasos.'),
              trailing: const TextButton(
                onPressed: openAppSettings,
                child: Text('Abrir'),
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Hoy',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: accentOf(context),
              ),
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.directions_walk, color: AppDataColors.steps),
            title: Text('${st.steps} pasos'),
            subtitle: Text(
              kcal > 0
                  ? '≈ $kcal kcal quemadas'
                  : 'Aún sin gasto estimado',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () => _recollect(context, ref),
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Recolectar pasos ahora'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Fuerza una lectura del sensor y guarda los pasos de hoy. Útil si '
              'crees que faltan pasos por registrar o acabas de activar el '
              'contador.',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Theme.of(context).hintColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.battery_alert_outlined,
                      size: 18, color: Theme.of(context).hintColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El contador funciona en 2do plano y puede afectar la '
                      'batería o el rendimiento del teléfono. Si notas que '
                      'consume mucho, puedes desactivarlo aquí.',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: Theme.of(context).hintColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
