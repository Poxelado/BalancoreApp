import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Discos disponibles por lado (kg), de mayor a menor.
const List<double> kAvailablePlates = [25, 20, 15, 10, 5, 2.5, 1.25];

/// Barras habituales (kg).
const List<double> kBarWeights = [20, 15, 10];

/// Desglose de discos por lado para acercarse a un peso objetivo.
class PlateBreakdown {
  /// Discos por lado, en orden descendente.
  final List<double> perSide;

  /// Peso realmente alcanzable con esos discos.
  final double achieved;

  /// Sobrante que no se puede cubrir con los discos disponibles.
  final double remainder;

  const PlateBreakdown({
    required this.perSide,
    required this.achieved,
    required this.remainder,
  });

  bool get exact => remainder.abs() < 0.001;
  bool get isEmpty => perSide.isEmpty;
}

/// Calcula el desglose de discos por lado (algoritmo voraz) para [target].
PlateBreakdown computePlates(
  double target, {
  double bar = 20,
  List<double> plates = kAvailablePlates,
}) {
  if (target <= 0) {
    return PlateBreakdown(perSide: const [], achieved: 0, remainder: target);
  }
  final perSideTarget = (target - bar) / 2;
  final result = <double>[];
  if (perSideTarget > 0) {
    var remaining = perSideTarget;
    for (final p in plates) {
      var count = 0;
      while (remaining >= p - 1e-9) {
        result.add(p);
        remaining -= p;
        count++;
        if (count > 100) break;
      }
    }
  }
  final total = bar + result.fold<double>(0, (s, p) => s + p) * 2;
  return PlateBreakdown(
    perSide: result,
    achieved: total,
    remainder: (target - total).abs() < 0.001 ? 0 : target - total,
  );
}

Color _plateColor(double plate) {
  if (plate >= 25) return const Color(0xFFE53935);
  if (plate >= 20) return const Color(0xFF1E88E5);
  if (plate >= 15) return const Color(0xFFFDD835);
  if (plate >= 10) return const Color(0xFF43A047);
  if (plate >= 5) return const Color(0xFFE0E0E0);
  if (plate >= 2.5) return const Color(0xFF616161);
  return const Color(0xFF9E9E9E);
}

String _fmtKg(double v) {
  if (v == v.roundToDouble()) return '${v.toInt()}';
  return v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(
        RegExp(r'\.$'),
        '',
      );
}

/// Hoja de calculadora de discos: devuelve el peso elegido en kg.
class PlateCalculatorSheet extends StatefulWidget {
  final double initialWeight;

  const PlateCalculatorSheet({super.key, this.initialWeight = 0});

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  late final TextEditingController _ctrl;
  double _bar = 20;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.initialWeight > 0 ? _fmtKg(widget.initialWeight) : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _target =>
      double.tryParse(_ctrl.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bd = computePlates(_target, bar: _bar);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calculate_outlined, color: accentOf(context)),
                const SizedBox(width: 8),
                const Text(
                  'Calculadora de discos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Peso total (kg)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Barra',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final b in kBarWeights)
                          ChoiceChip(
                            label: Text('${b.toInt()}'),
                            selected: _bar == b,
                            onSelected: (_) => setState(() => _bar = b),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_target <= 0)
              Text(
                'Escribe un peso para ver los discos.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else ...[
              Text(
                'Por lado',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accentOf(context),
                ),
              ),
              const SizedBox(height: 8),
              if (bd.perSide.isEmpty)
                Text(
                  'Solo la barra (${_fmtKg(_bar)} kg).',
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in bd.perSide) _plateChip(p, isDark),
                  ],
                ),
              const SizedBox(height: 12),
              Text(
                'Total a cargar: ${_fmtKg(bd.achieved)} kg'
                '${bd.perSide.isEmpty ? '' : ' (barra ${_fmtKg(_bar)} + ${_fmtKg((bd.achieved - _bar) / 2)} kg/lado)'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (!bd.exact)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Faltan ${_fmtKg(bd.remainder.abs())} kg (no alcanzable con estos discos)',
                    style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _target > 0
                  ? () => Navigator.pop(context, bd.achieved)
                  : null,
              child: const Text('Usar este peso'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plateChip(double p, bool isDark) {
    final color = _plateColor(p);
    final textColor =
        color.computeLuminance() > 0.6 ? Colors.black87 : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.15)),
      ),
      child: Text(
        _fmtKg(p),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
