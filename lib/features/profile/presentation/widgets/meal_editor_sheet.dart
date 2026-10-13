import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../screens/food_search_screen.dart';
import 'saved_food_chips.dart';
import '../../../../core/theme/app_theme.dart';

Future<void> openMealEditor(
    BuildContext context,
    WidgetRef ref, {
      MealEntry? existing,
      MealEntry? prefill,
      bool fromApi = false,
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
  final qtyCtrl = TextEditingController(
    text: base?.grams != null ? '${base!.grams}' : '',
  );
  int unitMode = 0; // 0=g 1=ml 2=ud
  final sl0 = base?.servingLabel ?? '';
  if (sl0.contains('ml')) {
    unitMode = 1;
  } else if (sl0.contains('ud')) {
    unitMode = 2;
  }
  String mealServingLabel() {
    final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.'));
    if (q == null || q <= 0) return base?.servingLabel ?? '';
    final n = q == q.roundToDouble() ? '${q.toInt()}' : '$q';
    switch (unitMode) {
      case 1:
        return '$n ml';
      case 2:
        return '$n ud';
      default:
        return '$n g';
    }
  }
  String mealType = base?.mealType ?? guessMealType();
  bool alsoSaveFood = fromApi; // si viene de API, ofrecer guardar por defecto
  // Desde API: campos bloqueados hasta que el usuario pida editar
  bool macrosLocked = fromApi && existing == null;
  final primary = Theme.of(context).colorScheme.primary;
  final isEdit = existing != null;
  final servingHint = base?.servingLabel;

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
                      color: accentOf(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isEdit)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx); // cierra editor
                          final result = await Navigator.push<FoodSearchResult>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const FoodSearchScreen(),
                            ),
                          );
                          if (result == null || !context.mounted) return;
                          await openMealEditor(
                            context,
                            ref,
                            prefill: MealEntry(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              name: result.name,
                              mealType: mealType,
                              calories: result.calories,
                              proteinGrams: result.proteinGrams,
                              carbsGrams: result.carbsGrams,
                              fatGrams: result.fatGrams,
                            ),
                          );
                        },
                        icon: const Icon(Icons.manage_search, size: 18),
                        label: const Text('Buscar en Open Food Facts'),
                      ),
                    ),
                  // Mis alimentos (desplegable)
                  if (!isEdit)
                    Theme(
                      data: Theme.of(ctx)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        leading: Icon(Icons.bookmark_outline, color: accentOf(context)),
                        title: const Text(
                          'Desde Mis alimentos',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          'Toca para expandir y elegir un frecuente',
                          style: TextStyle(fontSize: 12),
                        ),
                        children: [
                          SavedFoodChips(
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
                                macrosLocked = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),

                  Text(
                    'Momento del día',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: accentOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MealEntry.mealTypes.map((t) {
                      final selected = mealType == t;
                      return FilterChip(
                        label: Text(
                          t,
                          style: TextStyle(
                            fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? Colors.white : primary,
                          ),
                        ),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor: primary,
                        backgroundColor: primary.withValues(alpha: 0.12),
                        side: BorderSide(
                          color: selected
                              ? primary
                              : primary.withValues(alpha: 0.35),
                          width: selected ? 1.5 : 1,
                        ),
                        onSelected: (_) => setModal(() => mealType = t),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  if (servingHint != null && servingHint.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Porción: $servingHint',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),

                  if (macrosLocked) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline, size: 18, color: accentOf(context)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Datos de Open Food Facts. Si hay un error, desbloquea para corregir.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setModal(() => macrosLocked = false),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Editar valores manualmente'),
                      ),
                    ),
                  ] else if (fromApi && !isEdit) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setModal(() => macrosLocked = true),
                        icon: const Icon(Icons.lock_outline, size: 16),
                        label: const Text('Volver a bloquear'),
                      ),
                    ),
                  ],

                  TextField(
                    controller: nameCtrl,
                    readOnly: macrosLocked,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: calCtrl,
                    readOnly: macrosLocked,
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
                          readOnly: macrosLocked,
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
                          readOnly: macrosLocked,
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
                          readOnly: macrosLocked,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Grasa (g)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Cantidad / medida',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: accentOf(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('g')),
                      ButtonSegment(value: 1, label: Text('ml')),
                      ButtonSegment(value: 2, label: Text('ud')),
                    ],
                    selected: {unitMode},
                    onSelectionChanged: (s) =>
                        setModal(() => unitMode = s.first),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: qtyCtrl,
                    readOnly: macrosLocked,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      border: const OutlineInputBorder(),
                      suffixText: unitMode == 0
                          ? 'g'
                          : unitMode == 1
                          ? 'ml'
                          : 'ud',
                    ),
                    onChanged: (_) => setModal(() {}),
                  ),
                  const SizedBox(height: 12),
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
                        grams: () {
                          final q = double.tryParse(
                              qtyCtrl.text.replaceAll(',', '.'));
                          if (q == null || q <= 0) {
                            return existing?.grams ?? base?.grams;
                          }
                          return q.round().clamp(1, 20000);
                        }(),
                        servingLabel: mealServingLabel().isEmpty
                            ? (existing?.servingLabel ?? base?.servingLabel)
                            : mealServingLabel(),
                      );

                      final repo = ref.read(profileRepositoryProvider);
                      if (isEdit) {
                        await repo.updateMeal(user.uid, meal);
                      } else {
                        await repo.addMeal(user.uid, meal);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Comida registrada')),
                          );
                        }
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
                              portionGrams: meal.grams,
                              servingLabel: meal.servingLabel,
                              defaultMealType: meal.mealType,
                            ),
                          );
                          ref.invalidate(savedFoodsProvider);
                        }
                      }

                      invalidateProgressData(ref);
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

String guessMealType() {
  final h = DateTime.now().hour;
  if (h < 11) return 'Desayuno';
  if (h < 16) return 'Almuerzo';
  if (h < 21) return 'Cena';
  return 'Snack';
}
