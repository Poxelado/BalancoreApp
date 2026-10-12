part of 'onboarding_pages.dart';

/// Página 3: objetivo y plan diario estimado.
class GoalPage extends StatelessWidget {
  final String goal;
  final Color primary;
  final ValueChanged<String> onGoalChanged;
  final int previewCalories;
  final String previewWater;
  final ({int protein, int carbs, int fat}) previewMacros;

  const GoalPage({
    super.key,
    required this.goal,
    required this.primary,
    required this.onGoalChanged,
    required this.previewCalories,
    required this.previewWater,
    required this.previewMacros,
  });

  @override
  Widget build(BuildContext context) {
    final macros = previewMacros;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tu objetivo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajusta las calorías según lo que quieras lograr.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ...UserProfile.goals.map((g) {
            final selected = goal == g;
            final subtitle = switch (g) {
              'Perder grasa' => 'Déficit ~15 % sobre tu gasto',
              'Ganar músculo' => 'Superávit ~10 % sobre tu gasto',
              _ => 'Mantener peso actual',
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected ? primary : Colors.grey.shade300,
                  ),
                ),
                selected: selected,
                selectedTileColor: primary.withValues(alpha: 0.08),
                title: Text(g),
                subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
                trailing:
                    selected ? Icon(Icons.check_circle, color: primary) : null,
                onTap: () => onGoalChanged(g),
              ),
            );
          }),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Tu plan diario estimado',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$previewCalories',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  const Text('kcal / día',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop, size: 18, color: primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Agua: $previewWater',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _macroPreview(
                          'Prot', '${macros.protein} g', Colors.orange),
                      _macroPreview('Carb', '${macros.carbs} g', Colors.blue),
                      _macroPreview(
                          'Grasa', '${macros.fat} g', Colors.redAccent),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Podrás ajustar todo en tu perfil.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroPreview(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

/// Página 4: recordatorios y horarios.
class RemindersPage extends StatelessWidget {
  final bool? wantNotifs;
  final int workoutMin;
  final int mealMin;
  final int weightMin;
  final int weightWeekday;
  final int streakInterval;
  final Color primary;
  final ValueChanged<bool> onWantNotifs;
  final ValueChanged<int> onWorkoutMin;
  final ValueChanged<int> onMealMin;
  final ValueChanged<int> onWeightMin;
  final ValueChanged<int> onWeightWeekday;
  final ValueChanged<int> onStreakInterval;
  final Future<bool> Function() requestPermission;

  const RemindersPage({
    super.key,
    required this.wantNotifs,
    required this.workoutMin,
    required this.mealMin,
    required this.weightMin,
    required this.weightWeekday,
    required this.streakInterval,
    required this.primary,
    required this.onWantNotifs,
    required this.onWorkoutMin,
    required this.onMealMin,
    required this.onWeightMin,
    required this.onWeightWeekday,
    required this.onStreakInterval,
    required this.requestPermission,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = wantNotifs == true;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      children: [
        Text(
          '¿Quieres recibir recordatorios?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Te avisamos de entrenar, comer, peso y racha. Puedes cambiarlo después en Ajustes.',
          style: TextStyle(color: onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: primary,
                  side: BorderSide(
                    color: primary,
                    width: wantNotifs == false ? 2.5 : 1.5,
                  ),
                  backgroundColor: wantNotifs == false
                      ? primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                ),
                onPressed: () => onWantNotifs(false),
                child: Text(
                  'No',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  onWantNotifs(true);
                  final ok = await requestPermission();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Permiso de notificaciones concedido'
                              : 'Activa las notificaciones en Ajustes del sistema',
                        ),
                      ),
                    );
                  }
                },
                child: const Text(
                  'Sí',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (wantNotifs == null) ...[
          const SizedBox(height: 24),
          Text(
            'Elige Sí o No para continuar.',
            style: TextStyle(
                fontSize: 13, color: onSurface.withValues(alpha: 0.6)),
          ),
        ],
        if (enabled) ...[
          const SizedBox(height: 28),
          Text(
            'Horarios',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: primary,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.fitness_center, color: primary),
            title: Text('Entrenamiento', style: TextStyle(color: onSurface)),
            subtitle: Text(_hhmm(workoutMin)),
            trailing: Icon(Icons.edit_outlined, color: onSurface),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                    hour: workoutMin ~/ 60, minute: workoutMin % 60),
              );
              if (picked != null) {
                onWorkoutMin(picked.hour * 60 + picked.minute);
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.restaurant, color: primary),
            title: Text('Comida', style: TextStyle(color: onSurface)),
            subtitle: Text(_hhmm(mealMin)),
            trailing: Icon(Icons.edit_outlined, color: onSurface),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay(hour: mealMin ~/ 60, minute: mealMin % 60),
              );
              if (picked != null) {
                onMealMin(picked.hour * 60 + picked.minute);
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.monitor_weight_outlined, color: primary),
            title: Text('Peso (semanal)', style: TextStyle(color: onSurface)),
            subtitle: Text(
              '${NotificationPreferences.weekdayNames[weightWeekday]} · ${_hhmm(weightMin)}',
            ),
            trailing: Icon(Icons.edit_outlined, color: onSurface),
            onTap: () async {
              final day = await showModalBottomSheet<int>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        ListTile(
                          title:
                              Text(NotificationPreferences.weekdayNames[d]!),
                          onTap: () => Navigator.pop(ctx, d),
                        ),
                    ],
                  ),
                ),
              );
              if (day != null) onWeightWeekday(day);
              if (!context.mounted) return;
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                    hour: weightMin ~/ 60, minute: weightMin % 60),
              );
              if (picked != null) {
                onWeightMin(picked.hour * 60 + picked.minute);
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Avisos de racha (después de las 12:00)',
            style: TextStyle(fontWeight: FontWeight.w600, color: primary),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return primary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return primary;
                }
                return Colors.transparent;
              }),
              side: WidgetStatePropertyAll(BorderSide(color: primary)),
            ),
            segments: const [
              ButtonSegment(value: 4, label: Text('Cada 4 h')),
              ButtonSegment(value: 6, label: Text('Cada 6 h')),
            ],
            selected: {streakInterval},
            onSelectionChanged: (s) => onStreakInterval(s.first),
          ),
          const SizedBox(height: 8),
          Text(
            streakInterval == 4
                ? '12:00 · 16:00 · 20:00 — no perder la racha (3 de 4)'
                : '12:00 · 18:00 — no perder la racha (3 de 4)',
            style: TextStyle(
                fontSize: 12, color: onSurface.withValues(alpha: 0.65)),
          ),
        ],
      ],
    );
  }
}
