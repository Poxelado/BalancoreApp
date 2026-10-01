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

class _NutritionBodyState extends ConsumerState<_NutritionBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primary,
          tabs: const [
            Tab(text: 'Hoy'),
            Tab(text: 'Mis alimentos'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _TodayTab(log: widget.log, profile: widget.profile),
              const _SavedFoodsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// HOY
// ═══════════════════════════════════════════════════════════

class _TodayTab extends ConsumerWidget {
  final DailyLog log;
  final UserProfile? profile;

  const _TodayTab({required this.log, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final targetCal = profile?.targetCalories ?? 2000;
    final targetP = profile?.targetProtein ?? 0;
    final targetC = profile?.targetCarbs ?? 0;
    final targetF = profile?.targetFat ?? 0;

    final consumed = log.consumedCalories;
    final progress =
    targetCal > 0 ? (consumed / targetCal).clamp(0.0, 1.5) : 0.0;
    final remaining = targetCal - consumed;
    final pct = targetCal > 0 ? ((consumed / targetCal) * 100).round() : 0;

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
                      Text('Meta: $targetCal kcal ($pct%)',
                          style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text(
                        remaining >= 0
                            ? 'Restan $remaining kcal'
                            : 'Te pasaste ${-remaining} kcal',
                        style: TextStyle(
                          color:
                          remaining < 0 ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (profile != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile!.goal,
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

        // Agua rápida
        _WaterRow(glasses: log.waterGlasses),
        const SizedBox(height: 16),

        Text('Macros',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: primary)),
        const SizedBox(height: 8),
        _MacroBar(
            label: 'Proteína',
            current: log.proteinGrams,
            target: targetP,
            color: Colors.orange),
        _MacroBar(
            label: 'Carbohidratos',
            current: log.carbsGrams,
            target: targetC,
            color: Colors.blue),
        _MacroBar(
            label: 'Grasas',
            current: log.fatGrams,
            target: targetF,
            color: Colors.redAccent),
        const SizedBox(height: 16),

        Row(
          children: [
            Text('Comidas',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primary)),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _openMealEditor(context, ref),
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

        // Atajos: recientes
        _RecentQuickAdd(onPick: (meal) async {
          await _openMealEditor(
            context,
            ref,
            prefill: meal,
          );
        }),
        const SizedBox(height: 8),

        ...MealEntry.mealTypes.map((type) {
          final items = log.mealsOfType(type);
          return _MealSection(
            type: type,
            meals: items,
            totalCal: log.caloriesOfType(type),
            onEdit: (m) => _openMealEditor(context, ref, existing: m),
            onDelete: (id) async {
              final user = ref.read(authServiceProvider).currentUser;
              if (user == null) return;
              await ref
                  .read(profileRepositoryProvider)
                  .removeMeal(user.uid, id);
              ref.invalidate(todayLogProvider);
              ref.invalidate(recentMealsProvider);
            },
            onSaveAsFood: (m) => _saveMealAsFood(context, ref, m),
          );
        }),

        if (log.meals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Sin comidas hoy.\nUsa "Agregar" o un alimento reciente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _saveMealAsFood(
      BuildContext context,
      WidgetRef ref,
      MealEntry m,
      ) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    await ref.read(profileRepositoryProvider).saveFood(
      user.uid,
      SavedFood(
        id: '',
        name: m.name,
        calories: m.calories,
        proteinGrams: m.proteinGrams,
        carbsGrams: m.carbsGrams,
        fatGrams: m.fatGrams,
        defaultMealType: m.mealType,
      ),
    );
    ref.invalidate(savedFoodsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${m.name}" guardado en Mis alimentos')),
      );
    }
  }

  Future<void> _openMealEditor(
      BuildContext context,
      WidgetRef ref, {
        MealEntry? existing,
        MealEntry? prefill,
      }) async {
    final base = existing ?? prefill;
    final nameCtrl = TextEditingController(text: base?.name ?? '');
    final calCtrl =
    TextEditingController(text: base != null ? '${base.calories}' : '');
    final proteinCtrl = TextEditingController(
        text: base != null ? '${base.proteinGrams}' : '0');
    final carbsCtrl =
    TextEditingController(text: base != null ? '${base.carbsGrams}' : '0');
    final fatCtrl =
    TextEditingController(text: base != null ? '${base.fatGrams}' : '0');
    String mealType = base?.mealType ?? _guessMealType();
    bool alsoSaveFood = false;
    final primary = Theme.of(context).colorScheme.primary;
    final isEdit = existing != null;

    await showModalBottomSheet(
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
                      isEdit ? 'Editar comida' : 'Agregar comida',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Rápidos desde guardados
                    if (!isEdit) _SavedFoodChips(
                      onPick: (food) {
                        setModal(() {
                          nameCtrl.text = food.name;
                          calCtrl.text = '${food.calories}';
                          proteinCtrl.text = '${food.proteinGrams}';
                          carbsCtrl.text = '${food.carbsGrams}';
                          fatCtrl.text = '${food.fatGrams}';
                          if (food.defaultMealType != null) {
                            mealType = food.defaultMealType!;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: MealEntry.mealTypes.map((t) {
                        return ChoiceChip(
                          label: Text(t),
                          selected: mealType == t,
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
                        labelText: 'Nombre',
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
                    if (!isEdit) ...[
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Guardar en Mis alimentos'),
                        value: alsoSaveFood,
                        onChanged: (v) =>
                            setModal(() => alsoSaveFood = v ?? false),
                      ),
                    ],
                    const SizedBox(height: 12),
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
                              content:
                              Text('Nombre y calorías son obligatorios'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        final user =
                            ref.read(authServiceProvider).currentUser;
                        if (user == null) return;

                        final meal = MealEntry(
                          id: existing?.id ??
                              DateTime.now()
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

                        final repo = ref.read(profileRepositoryProvider);
                        if (isEdit) {
                          await repo.updateMeal(user.uid, meal);
                        } else {
                          await repo.addMeal(user.uid, meal);
                          if (alsoSaveFood) {
                            await repo.saveFood(
                              user.uid,
                              SavedFood(
                                id: '',
                                name: meal.name,
                                calories: meal.calories,
                                proteinGrams: meal.proteinGrams,
                                carbsGrams: meal.carbsGrams,
                                fatGrams: meal.fatGrams,
                                defaultMealType: meal.mealType,
                              ),
                            );
                            ref.invalidate(savedFoodsProvider);
                          }
                        }

                        ref.invalidate(todayLogProvider);
                        ref.invalidate(recentMealsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Text(
                        isEdit ? 'Guardar cambios' : 'Guardar comida',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
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

  String _guessMealType() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Desayuno';
    if (h < 16) return 'Almuerzo';
    if (h < 21) return 'Cena';
    return 'Snack';
  }
}

// ═══════════════════════════════════════════════════════════
// MIS ALIMENTOS
// ═══════════════════════════════════════════════════════════

class _SavedFoodsTab extends ConsumerWidget {
  const _SavedFoodsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(savedFoodsProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return foodsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (foods) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Alimentos que usas seguido.\nTócalos al agregar una comida.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _showFoodEditor(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo'),
                    style: FilledButton.styleFrom(backgroundColor: primary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: foods.isEmpty
                  ? const Center(
                child: Text(
                  'Aún no tienes alimentos guardados.\n'
                      'Crea uno o marca "Guardar en Mis alimentos"\n'
                      'al registrar una comida.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: foods.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final f = foods[i];
                  return Card(
                    child: ListTile(
                      title: Text(f.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        '${f.calories} kcal · P ${f.proteinGrams} · C ${f.carbsGrams} · G ${f.fatGrams}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _showFoodEditor(context, ref, food: f),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final user = ref
                                  .read(authServiceProvider)
                                  .currentUser;
                              if (user == null) return;
                              await ref
                                  .read(profileRepositoryProvider)
                                  .deleteSavedFood(user.uid, f.id);
                              ref.invalidate(savedFoodsProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showFoodEditor(
      BuildContext context,
      WidgetRef ref, {
        SavedFood? food,
      }) async {
    final nameCtrl = TextEditingController(text: food?.name ?? '');
    final calCtrl =
    TextEditingController(text: food != null ? '${food.calories}' : '');
    final pCtrl = TextEditingController(
        text: food != null ? '${food.proteinGrams}' : '0');
    final cCtrl = TextEditingController(
        text: food != null ? '${food.carbsGrams}' : '0');
    final fCtrl =
    TextEditingController(text: food != null ? '${food.fatGrams}' : '0');
    final primary = Theme.of(context).colorScheme.primary;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                food == null ? 'Nuevo alimento' : 'Editar alimento',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calorías (kcal)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Prot',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: cCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Carb',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Grasa',
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
                  if (name.isEmpty || cal == null || cal <= 0) return;
                  final user = ref.read(authServiceProvider).currentUser;
                  if (user == null) return;
                  await ref.read(profileRepositoryProvider).saveFood(
                    user.uid,
                    SavedFood(
                      id: food?.id ?? '',
                      name: name,
                      calories: cal,
                      proteinGrams: int.tryParse(pCtrl.text) ?? 0,
                      carbsGrams: int.tryParse(cCtrl.text) ?? 0,
                      fatGrams: int.tryParse(fCtrl.text) ?? 0,
                      useCount: food?.useCount ?? 0,
                    ),
                  );
                  ref.invalidate(savedFoodsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Guardar',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════

class _WaterRow extends ConsumerWidget {
  final int glasses;

  const _WaterRow({required this.glasses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.water_drop, color: Colors.blue.shade400),
            const SizedBox(width: 8),
            Text('Agua: $glasses vasos',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              onPressed: glasses <= 0
                  ? null
                  : () async {
                final user =
                    ref.read(authServiceProvider).currentUser;
                if (user == null) return;
                await ref
                    .read(profileRepositoryProvider)
                    .updateTodayLog(user.uid,
                    waterGlasses: glasses - 1);
                ref.invalidate(todayLogProvider);
              },
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              onPressed: () async {
                final user = ref.read(authServiceProvider).currentUser;
                if (user == null) return;
                await ref
                    .read(profileRepositoryProvider)
                    .updateTodayLog(user.uid, waterGlasses: glasses + 1);
                ref.invalidate(todayLogProvider);
              },
              icon: Icon(Icons.add_circle, color: primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentQuickAdd extends ConsumerWidget {
  final void Function(MealEntry meal) onPick;

  const _RecentQuickAdd({required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentMealsProvider);
    return recentAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recientes',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: list.length.clamp(0, 12),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final m = list[i];
                  return ActionChip(
                    label: Text(
                      '${m.name} (${m.calories})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => onPick(m),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SavedFoodChips extends ConsumerWidget {
  final void Function(SavedFood food) onPick;

  const _SavedFoodChips({required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(savedFoodsProvider);
    return foodsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (foods) {
        if (foods.isEmpty) {
          return const Text(
            'Tip: guarda alimentos en la pestaña "Mis alimentos"',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Desde Mis alimentos',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: foods.take(10).map((f) {
                return ActionChip(
                  label: Text(f.name, style: const TextStyle(fontSize: 12)),
                  onPressed: () => onPick(f),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
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
  final void Function(MealEntry meal) onEdit;
  final void Function(String id) onDelete;
  final void Function(MealEntry meal) onSaveAsFood;

  const _MealSection({
    required this.type,
    required this.meals,
    required this.totalCal,
    required this.onEdit,
    required this.onDelete,
    required this.onSaveAsFood,
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
          meals.isEmpty
              ? 'Sin registros'
              : '$totalCal kcal · ${meals.length} ítem(s)',
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
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit(m);
                if (v == 'save') onSaveAsFood(m);
                if (v == 'delete') onDelete(m.id);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(
                    value: 'save',
                    child: Text('Guardar en Mis alimentos')),
                PopupMenuItem(
                    value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ),
        )
            .toList(),
      ),
    );
  }
}