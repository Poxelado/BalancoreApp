import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/preferences/units_provider.dart';

/// Preferencia de unidades para peso y altura (métrico / imperial).
class UnitsSettingsScreen extends ConsumerWidget {
  const UnitsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Unidades')),
      body: ListView(
        children: [
          RadioGroup<UnitSystem>(
            groupValue: units,
            onChanged: (v) =>
                v == null ? null : ref.read(unitsProvider.notifier).set(v),
            child: const Column(
              children: [
                RadioListTile<UnitSystem>(
                  value: UnitSystem.metric,
                  title: Text('Métrico'),
                  subtitle: Text(
                      'Peso en kilogramos (kg) · altura en centímetros (cm)'),
                ),
                RadioListTile<UnitSystem>(
                  value: UnitSystem.imperial,
                  title: Text('Imperial'),
                  subtitle: Text('Peso en libras (lb) · altura en pulgadas (in)'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Los cálculos internos siguen usando kg y cm; solo cambia cómo '
              'ves e ingresas el peso y la altura.',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
