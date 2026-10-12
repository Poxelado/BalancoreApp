part of 'food_search_screen.dart';

Future<FoodSearchResult?> _quantitySheet(
    BuildContext context, {
  required String title,
  String? subtitle,
  required String per100,
  int? unitGramsHint,
  required int initialUnitMode,
  required String initialQty,
  required ({int kcal, int protein, int carbs, int fat}) Function(double grams)
      onMacros,
  required bool saveLibDefault,
  required String Function(int mode, double qty, double grams) labelFrom,
  required double unitGramsForUd,
}) async {
  final qtyCtrl = TextEditingController(text: initialQty);
  int unitMode = initialUnitMode;
  bool saveLib = saveLibDefault;

  double qtyValue() =>
      double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1;

  double gramsFromUi() {
    final q = qtyValue().clamp(0.1, 20000).toDouble();
    switch (unitMode) {
      case 1:
        return q;
      case 2:
        return (q * unitGramsForUd).toDouble();
      default:
        return q;
    }
  }

  return showModalBottomSheet<FoodSearchResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModal) {
          final grams = gramsFromUi();
          final m = onMacros(grams.clamp(1, 20000));
          final primary = Theme.of(ctx).colorScheme.primary;

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
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  per100,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                if (unitGramsHint != null)
                  Text(
                    '1 unidad ≈ $unitGramsHint g',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                const SizedBox(height: 12),
                Text(
                  'Cantidad',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                        value: 0,
                        label: Text('g'),
                        icon: Icon(Icons.scale, size: 16)),
                    ButtonSegment(
                        value: 1,
                        label: Text('ml'),
                        icon: Icon(Icons.water_drop, size: 16)),
                    ButtonSegment(
                        value: 2,
                        label: Text('ud'),
                        icon: Icon(Icons.looks_one, size: 16)),
                  ],
                  selected: {unitMode},
                  onSelectionChanged: (s) {
                    setModal(() {
                      unitMode = s.first;
                      if (unitMode == 2) {
                        qtyCtrl.text = '1';
                      } else if (qtyCtrl.text == '1' ||
                          qtyCtrl.text.isEmpty) {
                        qtyCtrl.text = unitMode == 1 ? '200' : '100';
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: qtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: unitMode == 0
                        ? 'Gramos'
                        : unitMode == 1
                            ? 'Mililitros (líquidos ≈ g)'
                            : 'Unidades',
                    border: const OutlineInputBorder(),
                    suffixText: unitMode == 0
                        ? 'g'
                        : unitMode == 1
                            ? 'ml'
                            : 'ud',
                    helperText: unitMode == 2
                        ? '1 ud = ${unitGramsForUd.round()} g'
                        : unitMode == 1
                            ? 'Para leche/jugo; 1 ml ≈ 1 g'
                            : null,
                  ),
                  onChanged: (_) => setModal(() {}),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        labelFrom(unitMode, qtyValue(), grams),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${m.kcal} kcal  ·  P ${m.protein} g  ·  '
                        'C ${m.carbs} g  ·  G ${m.fat} g',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: saveLib,
                  onChanged: (v) => setModal(() => saveLib = v ?? true),
                  title: const Text('Guardar en Mis alimentos'),
                  subtitle: const Text(
                    'Aparecerá en frecuentes para el próximo registro',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      ctx,
                      FoodSearchResult(
                        name: title,
                        calories: m.kcal,
                        proteinGrams: m.protein,
                        carbsGrams: m.carbs,
                        fatGrams: m.fat,
                        grams: grams.round().clamp(1, 20000),
                        servingLabel:
                            labelFrom(unitMode, qtyValue(), grams),
                        saveToLibrary: saveLib,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(backgroundColor: primary),
                  child: const Text('Usar este alimento'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

