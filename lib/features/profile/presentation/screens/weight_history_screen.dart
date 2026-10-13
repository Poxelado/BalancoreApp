import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/preferences/units_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class WeightHistoryScreen extends ConsumerStatefulWidget {
  const WeightHistoryScreen({super.key});

  @override
  ConsumerState<WeightHistoryScreen> createState() => _WeightHistoryScreenState();
}

class _WeightHistoryScreenState extends ConsumerState<WeightHistoryScreen> {
  final _weightController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _addWeight() async {
    final units = ref.read(unitsProvider);
    final text = _weightController.text.trim();
    final value = double.tryParse(text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Ingresa un peso válido'), backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }
    final weight = units.weightToKg(value);

    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authServiceProvider).currentUser!.uid;
      await ref.read(profileRepositoryProvider).addWeightEntry(uid, weight, DateTime.now());
      ref.invalidate(weightHistoryProvider);
      ref.invalidate(userProfileProvider);
      _weightController.clear();
      if (mounted) {
        Navigator.pop(context); // cierra el bottom sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Peso guardado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddWeightSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final unit = ref.read(unitsProvider).weightUnit;
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Registrar nuevo peso',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Peso ($unit)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.monitor_weight_outlined),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isSaving ? null : _addWeight,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSaving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text('Guardar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(weightHistoryProvider);
    final units = ref.watch(unitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de peso'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWeightSheet,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: historyAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.monitor_weight_outlined,
              title: 'Sin registros de peso',
              subtitle: 'Agrega tu primer peso para ver el historial y la tendencia.',
              actionLabel: 'Registrar peso',
              onAction: _showAddWeightSheet,
            );
          }

          // Orden cronológico para el gráfico (más antiguo → más reciente)
          final chronological = entries.reversed.toList();
          final minKg = entries.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
          final maxKg = entries.map((e) => e.weight).reduce((a, b) => a > b ? a : b);
          final displayWeights =
              chronological.map((e) => units.weightToDisplay(e.weight)).toList();
          final minD = displayWeights.reduce((a, b) => a < b ? a : b);
          final maxD = displayWeights.reduce((a, b) => a > b ? a : b);
          final pad = (maxD - minD) * 0.2 + 1;

          return Column(
            children: [
              // ─── Gráfico ─────────────────────────────────
              Container(
                height: 200,
                padding: const EdgeInsets.fromLTRB(16, 24, 24, 8),
                child: Semantics(
                  label: 'Evolución del peso corporal',
                  child: LineChart(
                    LineChartData(
                    minY: minD - pad,
                    maxY: maxD + pad,
                    gridData:
                        const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          getTitlesWidget: (v, _) => Text(
                            v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ),
                      bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: chronological
                            .asMap()
                            .entries
                            .map((e) =>
                                FlSpot(e.key.toDouble(), units.weightToDisplay(e.value.weight)))
                            .toList(),
                        isCurved: true,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),

              // ─── Min / Max ───────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Mínimo',
                        value: units.formatWeight(minKg, decimals: 1),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Máximo',
                        value: units.formatWeight(maxKg, decimals: 1),
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // ─── Lista de registros ──────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final dateStr =
                        '${entry.date.day.toString().padLeft(2, '0')}/${entry.date.month.toString().padLeft(2, '0')}/${entry.date.year}';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        child: Icon(Icons.monitor_weight, color: Theme.of(context).colorScheme.primary, size: 20),
                      ),
                      title: Text(
                        units.formatWeight(entry.weight, decimals: 1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(dateStr),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color  color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}