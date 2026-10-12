import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../screens/recipe_editor_screen.dart';

class RecipesTab extends ConsumerWidget {
  const RecipesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final recipesAsync = ref.watch(savedRecipesProvider);

    return recipesAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (recipes) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Platos compuestos',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: primary,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecipeEditorScreen(),
                        ),
                      );
                      ref.invalidate(savedRecipesProvider);
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Nuevo plato'),
                    style: FilledButton.styleFrom(backgroundColor: primary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Ej: "Arroz con pollo" con varios ingredientes. '
                    'Al registrar, cuenta como 1 ítem en el día.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: recipes.isEmpty
                  ? Center(
                child: Text(
                  'Sin platos aún.\nCrea "Arroz con pollo" u otro plato.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                itemCount: recipes.length,
                itemBuilder: (_, i) {
                  final r = recipes[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      leading: Icon(Icons.restaurant_menu, color: primary),
                      title: Text(
                        r.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${r.totalCalories} kcal · ${r.ingredients.length} ing. · '
                            'P ${r.totalProtein} · C ${r.totalCarbs} · G ${r.totalFat}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      children: [
                        for (final ing in r.ingredients)
                          ListTile(
                            dense: true,
                            title: Text(ing.name),
                            subtitle: Text(
                              '${ing.calories} kcal'
                                  '${ing.grams != null ? ' · ${ing.grams} g' : ''}',
                            ),
                          ),
                        ButtonBar(
                          children: [
                            TextButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RecipeEditorScreen(existing: r),
                                  ),
                                );
                                ref.invalidate(savedRecipesProvider);
                              },
                              child: const Text('Editar'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  _logRecipe(context, ref, r),
                              child: const Text('Registrar hoy'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                final user = ref
                                    .read(authServiceProvider)
                                    .currentUser;
                                if (user == null) return;
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Eliminar plato'),
                                    content: Text(
                                      '¿Borrar "${r.name}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Eliminar'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  await ref
                                      .read(profileRepositoryProvider)
                                      .deleteRecipe(user.uid, r.id);
                                  ref.invalidate(savedRecipesProvider);
                                }
                              },
                              child: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      ],
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

  Future<void> _logRecipe(
      BuildContext context,
      WidgetRef ref,
      SavedRecipe recipe,
      ) async {
    final primary = Theme.of(context).colorScheme.primary;
    String mealType = 'Almuerzo';
    double scale = 1.0;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final kcal = (recipe.totalCalories * scale).round();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Registrar "${recipe.name}"',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Momento del día',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: primary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: MealEntry.mealTypes.map((t) {
                      final sel = mealType == t;
                      return FilterChip(
                        label: Text(t),
                        selected: sel,
                        selectedColor: primary,
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : primary,
                          fontWeight: FontWeight.w600,
                        ),
                        showCheckmark: false,
                        onSelected: (_) => setModal(() => mealType = t),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Porción',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: primary)),
                  const SizedBox(height: 8),
                  SegmentedButton<double>(
                    segments: const [
                      ButtonSegment(value: 0.5, label: Text('½')),
                      ButtonSegment(value: 1.0, label: Text('1')),
                      ButtonSegment(value: 1.5, label: Text('1½')),
                      ButtonSegment(value: 2.0, label: Text('2')),
                    ],
                    selected: {scale},
                    onSelectionChanged: (s) =>
                        setModal(() => scale = s.first),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '≈ $kcal kcal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: primary),
                    child: const Text('Añadir al día'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (ok != true) return;
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    await ref.read(profileRepositoryProvider).addRecipeMeal(
      user.uid,
      recipe,
      mealType: mealType,
      scale: scale,
    );
    invalidateProgressData(ref);
    ref.invalidate(todayLogProvider);
    ref.invalidate(savedRecipesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${recipe.name}" añadido a $mealType')),
      );
    }
  }
}
