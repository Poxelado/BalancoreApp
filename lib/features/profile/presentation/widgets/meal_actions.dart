import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../screens/food_search_screen.dart';
import '../screens/recipe_editor_screen.dart';
import 'meal_editor_sheet.dart';
part 'meal_recipe_actions.dart';

Future<void> saveMealAsFood(
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
      portionGrams: m.grams,
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



Future<void> openFoodSearch(BuildContext context, WidgetRef ref) async {
  final result = await Navigator.push<FoodSearchResult>(
    context,
    MaterialPageRoute(builder: (_) => const FoodSearchScreen()),
  );
  if (result == null || !context.mounted) return;
  await openMealEditor(
    context,
    ref,
    fromApi: true,
    prefill: MealEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: result.name,
      mealType: guessMealType(),
      calories: result.calories,
      proteinGrams: result.proteinGrams,
      carbsGrams: result.carbsGrams,
      fatGrams: result.fatGrams,
      grams: result.grams,
      servingLabel: result.servingLabel,
    ),
  );
}

Future<void> openCopyDaySheet(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authServiceProvider).currentUser;
  if (user == null) return;
  final primary = Theme.of(context).colorScheme.primary;

  // Cargar últimos 21 días con comidas
  final logs = await ref.read(profileRepositoryProvider).getDailyLogsHistory(
    user.uid,
    days: 21,
  );
  final now = DateTime.now();
  final todayKey =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final candidates = logs
      .where((l) => l.date != todayKey && l.meals.isNotEmpty)
      .toList();

  if (!context.mounted) return;
  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No hay otros días con comidas para copiar'),
      ),
    );
    return;
  }

  String? selectedDate = candidates.first.date;
  bool replace = false;

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          final selected = candidates.firstWhere(
                (l) => l.date == selectedDate,
            orElse: () => candidates.first,
          );
          final totalKcal = selected.meals.fold<int>(0, (s, m) => s + m.calories);
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Copiar comidas de otro día',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Elige un día y añade sus comidas a hoy.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: candidates.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final l = candidates[i];
                      final sel = l.date == selectedDate;
                      final parts = l.date.split('-');
                      final label = parts.length == 3
                          ? '${parts[2]}/${parts[1]}'
                          : l.date;
                      return ChoiceChip(
                        label: Text(
                          '$label · ${l.meals.length}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: sel,
                        onSelected: (_) =>
                            setModal(() => selectedDate = l.date),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      Text(
                        '${selected.meals.length} comidas · $totalKcal kcal',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      for (final m in selected.meals)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• ${m.mealType}: ${m.name} (${m.calories} kcal)',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reemplazar comidas de hoy'),
                  subtitle: const Text(
                    'Si está apagado, se agregan a las ya registradas',
                  ),
                  value: replace,
                  onChanged: (v) => setModal(() => replace = v),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: selectedDate == null
                      ? null
                      : () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copiar a hoy'),
                  style: FilledButton.styleFrom(backgroundColor: primary),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  if (ok != true || selectedDate == null || !context.mounted) return;

  final n = await ref.read(profileRepositoryProvider).copyMealsFromDay(
    user.uid,
    selectedDate!,
    replace: replace,
  );
  invalidateProgressData(ref);
  ref.invalidate(todayLogProvider);
  ref.invalidate(recentMealsProvider);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'No se copió ninguna comida'
              : 'Se copiaron $n comida${n == 1 ? '' : 's'} a hoy',
        ),
      ),
    );
  }
}


Future<void> showAddChooser(BuildContext context, WidgetRef ref) async {
  final primary = Theme.of(context).colorScheme.primary;
  final choice = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '¿Qué quieres agregar?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.restaurant_menu, color: primary),
                title: const Text('Un plato / receta'),
                subtitle:
                const Text('Elegir uno guardado o crear uno nuevo'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: primary.withValues(alpha: 0.3)),
                ),
                onTap: () => Navigator.pop(ctx, 'recipe'),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Icon(Icons.fastfood_outlined, color: primary),
                title: const Text('Un alimento / comida'),
                subtitle: const Text(
                    'Manual, Mis alimentos u Open Food Facts'),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                onTap: () => Navigator.pop(ctx, 'food'),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (!context.mounted || choice == null) return;
  if (choice == 'food') {
    await openMealEditor(context, ref);
  } else {
    await openRecipePicker(context, ref);
  }
}

