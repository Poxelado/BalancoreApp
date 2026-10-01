import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'daily_history_screen.dart';

class NutritionTab extends ConsumerWidget {
  const NutritionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(todayLogProvider);
    final profile = ref.watch(userProfileProvider).value;
    final primary = Theme.of(context).colorScheme.primary;

    return logAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (log) => _NutritionBody(log: log, profile: profile),
    );
  }
}

class _NutritionBody extends ConsumerStatefulWidget {
  final DailyLog log;
  final UserProfile? profile;

  const _NutritionBody({required this.log, required this.profile});

  @override
  ConsumerState<_NutritionBody> createState() => _NutritionBodyState();
}

class _NutritionBodyState extends ConsumerState<_NutritionBody> {
  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final profile = widget.profile;
    final primary = Theme.of(context).colorScheme.primary;
    final targetCal = profile?.targetCalories ?? 2000;
    final targetP = profile?.targetProtein ?? 0;
    final targetC = profile?.targetCarbs ?? 0;
    final targetF = profile?.targetFat ?? 0;

    final consumed = log.consumedCalories;
    final progress =
    targetCal > 0 ? (consumed / targetCal).clamp(0.0, 1.5) : 0.0;
    final remaining = targetCal - consumed;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Text(
              'Hoy',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DailyHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Historial'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ─── Resumen kcal ────────────────────────────────
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                          color: remaining < 0 ? Colors.orange : primary,
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
                          const Text(
                            'kcal',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
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
                      Text(
                        'Meta: $targetCal kcal',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        remaining >= 0
                            ? 'Restan $remaining kcal'
                            : 'Te pasaste ${-remaining} kcal',
                        style: TextStyle(
                          color: remaining < 0 ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (profile?.goal != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile!.goal,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ─── Barras de macros ────────────────────────────
        Text(
          'Macros',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        _MacroBar(
          label: 'Proteína',
          current: log.proteinGrams,
          target: targetP,
          color: Colors.orange,
        ),
        _MacroBar(
          label: 'Carbohidratos',
          current: log.carbsGrams,
          target: targetC,
          color: Colors.blue,
        ),
        _MacroBar(
          label: 'Grasas',
          current: log.fatGrams,
          target: targetF,
          color: Colors.redAccent,
        ),
        const SizedBox(height: 20),

        // ─── Comidas del día ─────────────────────────────
        Row(
          children: [
            Text(
              'Comidas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _showAddMealSheet(context),
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
        const SizedBox(height: 12),

        ...MealEntry.mealTypes.map((type) {
          final items = log.mealsOfType(type);
          final typeCal = log.caloriesOfType(type);
          return _MealSection(
            type: type,
            meals: items,
            totalCal: typeCal,
            onDelete: (id) => _deleteMeal(id),
          );
        }),

        if (log.meals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Aún no registraste comidas hoy.\nToca "Agregar" para empezar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _deleteMeal(String mealId) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    await ref.read(profileRepositoryProvider).removeMeal(user.uid, mealId);
    ref.invalidate(todayLogProvider);
  }

  void _showAddMealSheet(BuildContext context) {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final proteinCtrl = TextEditingController(text: '0');
    final carbsCtrl = TextEditingController(text: '0');
    final fatCtrl = TextEditingController(text: '0');
    String mealType = 'Almuerzo';
    final primary = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Agregar comida',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: MealEntry.mealTypes.map((t) {
                        final selected = mealType == t;
                        return ChoiceChip(
                          label: Text(t),
                          selected: selected,
                          selectedColor: primary.withValues(alpha: 0.2),
                          onSelected: (_) => setModal(() => mealType = t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nombre (ej: Pollo con arroz)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: calCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Calorías (kcal) *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: proteinCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Prot (g)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: carbsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Carb (g)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: fatCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Grasa (g)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final cal = int.tryParse(calCtrl.text);
                        if (name.isEmpty || cal == null || cal <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Nombre y calorías son obligatorios'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final user =
                            ref.read(authServiceProvider).currentUser;
                        if (user == null) return;

                        final meal = MealEntry(
                          id: DateTime.now()
                              .millisecondsSinceEpoch
                              .toString(),
                          name: name,
                          mealType: mealType,
                          calories: cal,
                          proteinGrams:
                          int.tryParse(proteinCtrl.text) ?? 0,
                          carbsGrams: int.tryParse(carbsCtrl.text) ?? 0,
                          fatGrams: int.tryParse(fatCtrl.text) ?? 0,
                        );

                        await ref
                            .read(profileRepositoryProvider)
                            .addMeal(user.uid, meal);
                        ref.invalidate(todayLogProvider);

                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Guardar comida',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final int current;
  final int target;
  final Color color;

  const _MacroBar({
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                target > 0 ? '$current / $target g' : '$current g',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealSection extends StatelessWidget {
  final String type;
  final List<MealEntry> meals;
  final int totalCal;
  final void Function(String id) onDelete;

  const _MealSection({
    required this.type,
    required this.meals,
    required this.totalCal,
    required this.onDelete,
  });

  IconData get _icon => switch (type) {
    'Desayuno' => Icons.wb_sunny_outlined,
    'Almuerzo' => Icons.lunch_dining_outlined,
    'Cena' => Icons.dinner_dining_outlined,
    _ => Icons.cookie_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(_icon, color: primary),
        title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          meals.isEmpty ? 'Sin registros' : '$totalCal kcal · ${meals.length} ítem(s)',
          style: const TextStyle(fontSize: 12),
        ),
        children: meals.isEmpty
            ? [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Nada registrado en esta comida.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ),
        ]
            : meals
            .map(
              (m) => ListTile(
            dense: true,
            title: Text(m.name),
            subtitle: Text(
              '${m.calories} kcal'
                  '${m.proteinGrams > 0 || m.carbsGrams > 0 || m.fatGrams > 0 ? ' · P ${m.proteinGrams} · C ${m.carbsGrams} · G ${m.fatGrams}' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => onDelete(m.id),
            ),
          ),
        )
            .toList(),
      ),
    );
  }
}
