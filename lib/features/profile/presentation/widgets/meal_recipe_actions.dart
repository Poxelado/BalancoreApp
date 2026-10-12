part of 'meal_actions.dart';

Future<void> openRecipePicker(BuildContext context, WidgetRef ref) async {
  final primary = Theme.of(context).colorScheme.primary;
  final recipes = await ref.read(savedRecipesProvider.future);
  if (!context.mounted) return;

  final result = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tus platos',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'new'),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nuevo'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: recipes.isEmpty
                    ? Center(
                  child: Text(
                    'Aún no tienes platos.\nCrea uno con "Nuevo".',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
                    : ListView.builder(
                  controller: scrollCtrl,
                  itemCount: recipes.length,
                  itemBuilder: (_, i) {
                    final r = recipes[i];
                    return ListTile(
                      leading: Icon(Icons.restaurant_menu,
                          color: primary),
                      title: Text(r.name),
                      subtitle: Text(
                        '${r.totalCalories} kcal · ${r.ingredients.length} ing.',
                      ),
                      trailing: IconButton(
                        tooltip: 'Editar receta',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => Navigator.pop(ctx, r),
                      ),
                      onTap: () =>
                          Navigator.pop(ctx, <String, dynamic>{'log': r}),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );

  if (!context.mounted || result == null) return;

  if (result == 'new') {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RecipeEditorScreen()),
    );
    ref.invalidate(savedRecipesProvider);
    return;
  }

  if (result is SavedRecipe) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeEditorScreen(existing: result),
      ),
    );
    ref.invalidate(savedRecipesProvider);
    return;
  }

  if (result is Map && result['log'] is SavedRecipe) {
    final recipe = result['log'] as SavedRecipe;
    await logRecipeFromPicker(context, ref, recipe);
  }
}

Future<void> logRecipeFromPicker(
    BuildContext context,
    WidgetRef ref,
    SavedRecipe recipe,
    ) async {
  final primary = Theme.of(context).colorScheme.primary;
  String mealType = guessMealType();
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

Future<void> onEditMealOrRecipe(
    BuildContext context,
    WidgetRef ref,
    MealEntry m,
    ) async {
  if (!m.isRecipe || m.recipeId == null || m.recipeId!.isEmpty) {
    await openMealEditor(context, ref, existing: m);
    return;
  }

  final primary = Theme.of(context).colorScheme.primary;
  final choice = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                m.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: primary,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Editar solo este registro'),
                subtitle:
                const Text('Cambia kcal/macros de hoy, no el plato'),
                onTap: () => Navigator.pop(ctx, 'meal'),
              ),
              ListTile(
                leading: Icon(Icons.restaurant_menu, color: primary),
                title: const Text('Editar la receta'),
                subtitle: const Text('Ingredientes del plato guardado'),
                onTap: () => Navigator.pop(ctx, 'recipe'),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (!context.mounted || choice == null) return;

  if (choice == 'meal') {
    await openMealEditor(context, ref, existing: m);
    return;
  }

  final user = ref.read(authServiceProvider).currentUser;
  if (user == null) return;
  final recipes = await ref.read(savedRecipesProvider.future);
  if (!context.mounted) return;
  SavedRecipe? found;
  for (final r in recipes) {
    if (r.id == m.recipeId) {
      found = r;
      break;
    }
  }
  if (found == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontró la receta (¿la borraste?)'),
        ),
      );
    }
    await openMealEditor(context, ref, existing: m);
    return;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RecipeEditorScreen(existing: found),
    ),
  );
  ref.invalidate(savedRecipesProvider);
}
