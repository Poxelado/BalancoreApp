import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/steps/step_counter.dart';
import '../../../training/domain/workout_calories.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'macro_bar.dart';
import 'meal_actions.dart';
import 'meal_editor_sheet.dart';
import 'meal_section.dart';
import 'quick_foods_bar.dart';
import 'water_row.dart';
import '../../../../core/theme/app_theme.dart';

class TodayTab extends ConsumerWidget {
  final DailyLog log;
  final UserProfile? profile;

  const TodayTab({super.key, required this.log, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final targets = profile?.effectiveTargets;
    final targetCal = targets?.calories ?? 2000;
    final targetP = targets?.protein ?? 0;
    final targetC = targets?.carbs ?? 0;
    final targetF = targets?.fat ?? 0;

    final consumed = log.consumedCalories;
    final progress =
    targetCal > 0 ? (consumed / targetCal).clamp(0.0, 1.5) : 0.0;
    final pct = targetCal > 0 ? ((consumed / targetCal) * 100).round() : 0;

    // Gasto del día: kcal de entrenos + kcal por pasos. Es informativo: la meta
    // ya incluye tu nivel de actividad, así que NO se suma al presupuesto.
    final weightKg = profile?.currentWeight ?? 0;
    final stepCount = ref.watch(stepCounterProvider).steps;
    final stepKcal = stepCalories(stepCount, weightKg);
    final exerciseKcal = log.exerciseCalories;
    final extraBurned = exerciseKcal + stepKcal;
    final remaining = targetCal - consumed;

    final session = ref.watch(todayWorkoutSessionProvider).valueOrNull;
    final workoutMinutes =
        session == null ? 0 : (session.elapsedSeconds / 60).round();
    final workoutMet = session == null ? null : estimateWorkoutMet(session);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Text(
              'Resumen del día',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: accentOf(context),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                ref.read(habitsMetricProvider.notifier).state = 3; // macros
                ref.read(progressSectionProvider.notifier).state = 2; // hábitos
                ref.read(shellTabProvider.notifier).state = 0; // progreso
              },
              icon: const Icon(Icons.show_chart, size: 18),
              label: const Text('Ver progreso'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: progress > 1 ? 1 : progress,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey.withValues(alpha: 0.2),
                          color: remaining < 0
                              ? AppSemanticColors.of(context).warning
                              : primary,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$consumed',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('kcal',
                              style:
                              TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ledgerRow(context, 'Meta', targetCal),
                      _ledgerRow(context, 'Comido', -consumed),
                      const Divider(height: 14),
                      Text(
                        remaining >= 0
                            ? 'Restan $remaining kcal'
                            : 'Te pasaste ${-remaining} kcal',
                        style: TextStyle(
                          color: remaining < 0
                              ? AppSemanticColors.of(context).warning
                              : AppSemanticColors.of(context).success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (profile != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${profile!.goal} · $pct% de la meta',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Gasto del día: informativo (no afecta la meta).
        if (extraBurned > 0) ...[
          _BurnedCard(
            exerciseKcal: exerciseKcal,
            stepKcal: stepKcal,
            stepCount: stepCount,
            weightKg: weightKg,
            workoutMinutes: workoutMinutes,
            workoutMet: workoutMet,
          ),
          const SizedBox(height: 12),
        ],

        // Agua rápida
        WaterRow(glasses: log.waterGlasses),
        const SizedBox(height: 16),

        Text('Macros',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: accentOf(context))),
        const SizedBox(height: 8),
        MacroBar(
            label: 'Proteína',
            current: log.proteinGrams,
            target: targetP,
            color: AppDataColors.protein),
        MacroBar(
            label: 'Carbohidratos',
            current: log.carbsGrams,
            target: targetC,
            color: AppDataColors.carbs),
        MacroBar(
            label: 'Grasas',
            current: log.fatGrams,
            target: targetF,
            color: AppDataColors.fat),
        const SizedBox(height: 16),

        Row(
          children: [
            Text('Comidas',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: accentOf(context))),
            const Spacer(),
            IconButton(
              tooltip: 'Buscar alimento (Open Food Facts)',
              onPressed: () => openFoodSearch(context, ref),
              icon: const Icon(Icons.manage_search),
            ),
            OutlinedButton.icon(
              onPressed: () => openCopyDaySheet(context, ref),
              icon: const Icon(Icons.copy_all_outlined, size: 16),
              label: const Text('Copiar'),
              style: OutlinedButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () => showAddChooser(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Atajos: frecuentes + recientes (1 toque)
        QuickFoodsBar(
          onQuickAdd: (msg) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
            );
          },
          onEditTemplate: (meal) => openMealEditor(
            context,
            ref,
            prefill: meal,
          ),
        ),
        const SizedBox(height: 8),

        ...MealEntry.mealTypes.map((type) {
          final items = log.mealsOfType(type);
          return MealSection(
            type: type,
            meals: items,
            totalCal: log.caloriesOfType(type),
            onEdit: (m) => onEditMealOrRecipe(context, ref, m),
            onDelete: (id) async {
              final user = ref.read(authServiceProvider).currentUser;
              if (user == null) return;
              await ref
                  .read(profileRepositoryProvider)
                  .removeMeal(user.uid, id);
              invalidateProgressData(ref);
              ref.invalidate(recentMealsProvider);
            },
            onSaveAsFood: (m) => saveMealAsFood(context, ref, m),
          );
        }),

        if (log.meals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: EmptyState(
              icon: Icons.restaurant_outlined,
              title: 'Sin comidas hoy',
              subtitle: 'Registra algo para macros, racha y progreso.',
              actionLabel: 'Agregar comida',
              onAction: () {
                // el botón Agregar del tab ya está arriba; scroll hint
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Usa "Agregar" arriba o un alimento reciente'),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _ledgerRow(BuildContext context, String label, int value) {
    final text = value < 0 ? '−${-value}' : '$value';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const Spacer(),
          Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Gasto calórico del día (entrenos + pasos). Es informativo: no se descuenta
/// de la meta, así que se muestra aparte y se expande para explicar el cálculo.
class _BurnedCard extends StatefulWidget {
  final int exerciseKcal;
  final int stepKcal;
  final int stepCount;
  final double weightKg;
  final int workoutMinutes;
  final double? workoutMet;

  const _BurnedCard({
    required this.exerciseKcal,
    required this.stepKcal,
    required this.stepCount,
    required this.weightKg,
    required this.workoutMinutes,
    required this.workoutMet,
  });

  @override
  State<_BurnedCard> createState() => _BurnedCardState();
}

class _BurnedCardState extends State<_BurnedCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final total = widget.exerciseKcal + widget.stepKcal;
    final divider = Theme.of(context).dividerColor.withValues(alpha: 0.5);
    return Container(
      decoration: BoxDecoration(
        color: AppDataColors.calories.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppDataColors.calories.withValues(alpha: 0.30)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0x22FF9800),
                      child: Icon(Icons.local_fire_department,
                          size: 18, color: AppDataColors.calories),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gasto del día · $total kcal',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          Text('Informativo: no se descuenta de tu meta',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    Icon(_open ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade600),
                  ],
                ),
                if (_open) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: divider),
                  const SizedBox(height: 12),
                  if (widget.exerciseKcal > 0)
                    _detailRow(
                      Icons.fitness_center,
                      AppDataColors.training,
                      'Entreno',
                      _workoutDetail(),
                      widget.exerciseKcal,
                    ),
                  if (widget.exerciseKcal > 0 && widget.stepKcal > 0)
                    const SizedBox(height: 10),
                  if (widget.stepKcal > 0)
                    _detailRow(
                      Icons.directions_walk,
                      AppDataColors.steps,
                      'Pasos',
                      '${widget.stepCount} pasos',
                      widget.stepKcal,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Estimación aproximada según tu peso, la duración y el tipo '
                    'de actividad. No es un valor médico exacto.',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _workoutDetail() {
    final parts = <String>[];
    if (widget.workoutMet != null) {
      parts.add('MET ${widget.workoutMet!.toStringAsFixed(1)}');
    }
    if (widget.workoutMinutes > 0) parts.add('${widget.workoutMinutes} min');
    if (widget.weightKg > 0) parts.add('${widget.weightKg.round()} kg');
    return parts.isEmpty ? 'Según duración y peso' : parts.join(' · ');
  }

  Widget _detailRow(IconData icon, Color color, String label, String detail,
      int kcal) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text(detail,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
        Text('$kcal kcal',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}
