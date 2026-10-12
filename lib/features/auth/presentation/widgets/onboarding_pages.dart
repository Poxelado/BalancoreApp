import 'package:flutter/material.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../../core/notifications/notification_preferences.dart';

String _hhmm(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// Página 1: identidad (nombre opcional y sexo).
class IdentityPage extends StatelessWidget {
  final TextEditingController nameController;
  final String sex;
  final Color primary;
  final ValueChanged<String> onSexChanged;

  const IdentityPage({
    super.key,
    required this.nameController,
    required this.sex,
    required this.primary,
    required this.onSexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Cómo te llamamos?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu usuario ya quedó definido al crear la cuenta. Aquí solo el nombre (opcional) y el sexo.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre (opcional)',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Sexo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _sexChip('Masculino')),
              const SizedBox(width: 12),
              Expanded(child: _sexChip('Femenino')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sexChip(String value) {
    final selected = sex == value;
    return InkWell(
      onTap: () => onSexChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.15) : null,
          border: Border.all(color: selected ? primary : Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? primary : null,
          ),
        ),
      ),
    );
  }
}

/// Página 2: datos corporales (edad, peso, altura, actividad y agua).
class BodyPage extends StatelessWidget {
  final TextEditingController ageController;
  final TextEditingController weightController;
  final TextEditingController heightController;
  final String activityLevel;
  final Color primary;
  final ValueChanged<String> onActivityChanged;
  final VoidCallback onFieldChanged;

  const BodyPage({
    super.key,
    required this.ageController,
    required this.weightController,
    required this.heightController,
    required this.activityLevel,
    required this.primary,
    required this.onActivityChanged,
    required this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tus datos corporales',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Los usamos para calcular tus calorías y macros objetivo.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Edad',
              prefixIcon: Icon(Icons.cake_outlined),
              border: OutlineInputBorder(),
              suffixText: 'años',
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 12 || n > 100) return 'Edad entre 12 y 100';
              return null;
            },
            onChanged: (_) => onFieldChanged(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Peso actual',
              prefixIcon: Icon(Icons.monitor_weight_outlined),
              border: OutlineInputBorder(),
              suffixText: 'kg',
            ),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n < 30 || n > 300) return 'Peso no válido';
              return null;
            },
            onChanged: (_) => onFieldChanged(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Altura',
              prefixIcon: Icon(Icons.height),
              border: OutlineInputBorder(),
              suffixText: 'cm',
            ),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n < 100 || n > 250) return 'Altura no válida';
              return null;
            },
            onChanged: (_) => onFieldChanged(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nivel de actividad',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Úsalo para estimar tus calorías. Luego se puede refinar con tus entrenos.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ..._activityOptions(),
          const SizedBox(height: 24),
          // Agua recomendada según peso
          Builder(
            builder: (context) {
              final w = double.tryParse(weightController.text) ?? 70;
              final ml = UserProfile.calculateWaterMl(weightKg: w);
              final glasses = UserProfile.waterGlassesFromMl(ml);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.water_drop, color: primary, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agua recomendada',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$ml ml/día  ·  ~$glasses vasos',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Se calcula con tu peso (~35 ml/kg). Se ajustará solo.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _activityOptions() {
    const items = <(String, String)>[
      ('Sedentario', 'Poco o nada de ejercicio'),
      ('Ligero', '1–3 días / semana'),
      ('Moderado', '3–5 días / semana'),
      ('Activo', '6–7 días / semana'),
      ('Muy activo', 'Entrenamiento intenso diario'),
    ];
    return [
      for (final (value, subtitle) in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: activityLevel == value
                ? primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onActivityChanged(value),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activityLevel == value
                        ? primary
                        : Colors.grey.shade400,
                    width: activityLevel == value ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: activityLevel == value ? primary : null,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (activityLevel == value)
                      Icon(Icons.check_circle, color: primary, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

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
