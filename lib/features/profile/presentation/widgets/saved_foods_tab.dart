import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../../core/theme/app_theme.dart';

class SavedFoodsTab extends ConsumerWidget {
  const SavedFoodsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(savedFoodsProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return foodsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: accentOf(context))),
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
                        '${f.calories} kcal'
                            '${f.servingLabel != null && f.servingLabel!.isNotEmpty ? ' · ${f.servingLabel}' : (f.portionGrams != null ? ' · ${f.portionGrams} g' : '')}'
                            ' · P ${f.proteinGrams} · C ${f.carbsGrams} · G ${f.fatGrams}',
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
    final qtyCtrl = TextEditingController(
      text: food?.portionGrams != null ? '${food!.portionGrams}' : '100',
    );
    int unitMode = 0;
    final existingLabel = food?.servingLabel ?? '';
    if (existingLabel.contains('ml')) {
      unitMode = 1;
    } else if (existingLabel.contains('ud')) {
      unitMode = 2;
    }
    final primary = Theme.of(context).colorScheme.primary;

    String buildLabel() {
      final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
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
                      food == null ? 'Nuevo alimento' : 'Editar alimento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: accentOf(context),
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
                        helperText:
                        'Los macros de abajo corresponden a esta cantidad',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Calorias y Macros',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: accentOf(context),
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
                        final qty = double.tryParse(
                            qtyCtrl.text.replaceAll(',', '.')) ??
                            0;
                        final grams = qty.round().clamp(0, 20000);
                        await ref.read(profileRepositoryProvider).saveFood(
                          user.uid,
                          SavedFood(
                            id: food?.id ?? '',
                            name: name,
                            calories: cal,
                            proteinGrams: int.tryParse(pCtrl.text) ?? 0,
                            carbsGrams: int.tryParse(cCtrl.text) ?? 0,
                            fatGrams: int.tryParse(fCtrl.text) ?? 0,
                            portionGrams: grams > 0 ? grams : null,
                            servingLabel: buildLabel(),
                            useCount: food?.useCount ?? 0,
                          ),
                        );
                        ref.invalidate(savedFoodsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Guardar',
                        style: TextStyle(color: Colors.white),
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
