import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/user_profile.dart';

enum HistoryMetric { calories, water, sleep, macros }

const historyCalColor = AppDataColors.calories;
const historyWaterColor = AppDataColors.water;
const historySleepColor = AppDataColors.sleep;
const historyProteinColor = AppDataColors.protein;
const historyCarbsColor = AppDataColors.carbs;
const historyFatColor = AppDataColors.fat;

class MetricSelector extends StatelessWidget {
  final HistoryMetric? selected;
  final void Function(HistoryMetric m) onSelect;

  const MetricSelector({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          MetricIcon(
            icon: Icons.local_fire_department,
            label: 'Calorías',
            color: historyCalColor,
            selected: selected == HistoryMetric.calories,
            dimmed: selected != null && selected != HistoryMetric.calories,
            onTap: () => onSelect(HistoryMetric.calories),
          ),
          MetricIcon(
            icon: Icons.water_drop,
            label: 'Agua',
            color: historyWaterColor,
            selected: selected == HistoryMetric.water,
            dimmed: selected != null && selected != HistoryMetric.water,
            onTap: () => onSelect(HistoryMetric.water),
          ),
          MetricIcon(
            icon: Icons.bedtime,
            label: 'Sueño',
            color: historySleepColor,
            selected: selected == HistoryMetric.sleep,
            dimmed: selected != null && selected != HistoryMetric.sleep,
            onTap: () => onSelect(HistoryMetric.sleep),
          ),
          MetricIcon(
            icon: Icons.pie_chart_outline,
            label: 'Macros',
            color: historyProteinColor,
            selected: selected == HistoryMetric.macros,
            dimmed: selected != null && selected != HistoryMetric.macros,
            onTap: () => onSelect(HistoryMetric.macros),
          ),
        ],
      ),
    );
  }
}

class MetricIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const MetricIcon({super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: dimmed ? 0.35 : 1,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.25 : 0.12),
                  shape: BoxShape.circle,
                  border:
                  selected ? Border.all(color: color, width: 2) : null,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const LegendDot({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

// ─── Chart ─────────────────────────────────────────────────

class HistoryChart extends StatelessWidget {
  final List<DailyLog> logs;
  final HistoryMetric? selected;

  const HistoryChart({super.key, required this.logs, required this.selected});

  double _scalar(DailyLog log, HistoryMetric m) {
    return switch (m) {
      HistoryMetric.calories => log.consumedCalories.toDouble(),
      HistoryMetric.water => log.waterGlasses.toDouble(),
      HistoryMetric.sleep => log.sleepHours,
      HistoryMetric.macros => (log.proteinGrams + log.carbsGrams + log.fatGrams)
          .toDouble(), // solo para normalizar vista conjunta
    };
  }

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }

    // Vista macros: 3 series P/C/G
    if (selected == HistoryMetric.macros) {
      return _buildMulti(
        series: [
          Series(
            'P',
            historyProteinColor,
            [for (var i = 0; i < logs.length; i++) FlSpot(i.toDouble(), logs[i].proteinGrams.toDouble())],
          ),
          Series(
            'C',
            historyCarbsColor,
            [for (var i = 0; i < logs.length; i++) FlSpot(i.toDouble(), logs[i].carbsGrams.toDouble())],
          ),
          Series(
            'G',
            historyFatColor,
            [for (var i = 0; i < logs.length; i++) FlSpot(i.toDouble(), logs[i].fatGrams.toDouble())],
          ),
        ],
        normalize: false,
        logs: logs,
      );
    }

    // Una métrica
    if (selected != null) {
      final m = selected!;
      final color = switch (m) {
        HistoryMetric.calories => historyCalColor,
        HistoryMetric.water => historyWaterColor,
        HistoryMetric.sleep => historySleepColor,
        HistoryMetric.macros => historyProteinColor,
      };
      return _buildMulti(
        series: [
          Series(
            '',
            color,
            [
              for (var i = 0; i < logs.length; i++)
                FlSpot(i.toDouble(), _scalar(logs[i], m)),
            ],
          ),
        ],
        normalize: false,
        logs: logs,
      );
    }

    // Conjunto: kcal, agua, sueño + macros totales (normalizado)
    return _buildMulti(
      series: [
        for (final m in [HistoryMetric.calories, HistoryMetric.water, HistoryMetric.sleep, HistoryMetric.macros])
          Series(
            '',
            switch (m) {
              HistoryMetric.calories => historyCalColor,
              HistoryMetric.water => historyWaterColor,
              HistoryMetric.sleep => historySleepColor,
              HistoryMetric.macros => historyProteinColor,
            },
            _normalizedSpots(m),
          ),
      ],
      normalize: true,
      logs: logs,
    );
  }

  List<FlSpot> _normalizedSpots(HistoryMetric m) {
    final values = logs.map((l) => _scalar(l, m)).toList();
    final maxV = values.fold<double>(1, (a, b) => b > a ? b : a);
    return [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), maxV == 0 ? 0 : values[i] / maxV),
    ];
  }

  Widget _buildMulti({
    required List<Series> series,
    required bool normalize,
    required List<DailyLog> logs,
  }) {
    double maxY = 1.05;
    if (!normalize) {
      maxY = 1;
      for (final s in series) {
        for (final spot in s.spots) {
          if (spot.y > maxY) maxY = spot.y;
        }
      }
      maxY *= 1.15;
      if (maxY < 1) maxY = 1;
    }

    return Semantics(
      label: 'Evolución del progreso en el tiempo',
      child: LineChart(
        LineChartData(
        minX: 0,
        maxX: (logs.length - 1).clamp(0, 9999).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.grey.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !normalize,
              reservedSize: 36,
              getTitlesWidget: (v, meta) {
                if (v == 0 || (v - meta.max).abs() < 0.01) {
                  return Text(
                    v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: logs.length <= 7
                  ? 1
                  : (logs.length / 4).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= logs.length) return const SizedBox.shrink();
                final parts = logs[i].date.split('-');
                final label = parts.length == 3
                    ? '${parts[2]}/${parts[1]}'
                    : logs[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style:
                      const TextStyle(fontSize: 9, color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) {
              return touched.map((s) {
                final i = s.x.round().clamp(0, logs.length - 1);
                final log = logs[i];
                String text;
                if (selected == HistoryMetric.macros) {
                  final names = ['P', 'C', 'G'];
                  final vals = [
                    log.proteinGrams,
                    log.carbsGrams,
                    log.fatGrams
                  ];
                  final idx = s.barIndex.clamp(0, 2);
                  text = '${names[idx]} ${vals[idx]} g';
                } else if (selected == HistoryMetric.calories) {
                  text = '${log.consumedCalories} kcal';
                } else if (selected == HistoryMetric.water) {
                  text = '${log.waterGlasses} vasos';
                } else if (selected == HistoryMetric.sleep) {
                  text = '${log.sleepHours.toStringAsFixed(1)} h';
                } else {
                  text = log.date;
                }
                return LineTooltipItem(
                  text,
                  TextStyle(
                    color: series[s.barIndex.clamp(0, series.length - 1)].color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          for (final s in series)
            LineChartBarData(
              spots: s.spots,
              isCurved: true,
              color: s.color,
              barWidth: selected == null ? 2.2 : 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: logs.length <= 14),
              belowBarData: BarAreaData(
                show: selected != null && selected != HistoryMetric.macros,
                color: s.color.withValues(alpha: 0.12),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class Series {
  final String name;
  final Color color;
  final List<FlSpot> spots;
  Series(this.name, this.color, this.spots);
}

// ─── Row ───────────────────────────────────────────────────

class HistoryRow extends StatelessWidget {
  final DailyLog log;
  final HistoryMetric? filter;
  final VoidCallback onEdit;
  final VoidCallback? onEditMeals;

  const HistoryRow({super.key,
    required this.log,
    required this.filter,
    required this.onEdit,
    this.onEditMeals,
  });

  String get _dateLabel {
    final parts = log.date.split('-');
    if (parts.length != 3) return log.date;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, Color color, String value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 3),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onEdit,
        onLongPress: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _dateLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  Icon(Icons.edit_outlined,
                      size: 16, color: Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 8),
              if (filter == null || filter == HistoryMetric.calories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: chip(
                    Icons.local_fire_department,
                    historyCalColor,
                    '${log.consumedCalories} kcal',
                  ),
                ),
              if (filter == null || filter == HistoryMetric.water)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: chip(
                    Icons.water_drop,
                    historyWaterColor,
                    '${log.waterGlasses} vasos',
                  ),
                ),
              if (filter == null || filter == HistoryMetric.sleep)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: chip(
                    Icons.bedtime,
                    historySleepColor,
                    '${log.sleepHours.toStringAsFixed(1)} h',
                  ),
                ),
              if (filter == null || filter == HistoryMetric.macros)
                Row(
                  children: [
                    chip(
                      Icons.egg_alt,
                      historyProteinColor,
                      'Prote ${log.proteinGrams}g',
                    ),
                    const SizedBox(width: 10),
                    chip(
                      Icons.grain,
                      historyCarbsColor,
                      'Carbos ${log.carbsGrams}g',
                    ),
                    const SizedBox(width: 10),
                    chip(
                      Icons.water,
                      historyFatColor,
                      'Grasas ${log.fatGrams}g',
                    ),
                  ],
                ),
              if (onEditMeals != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onEditMeals,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.restaurant_menu, size: 16),
                    label: Text(
                      log.meals.isEmpty
                          ? 'Añadir comidas'
                          : 'Ver/editar comidas (${log.meals.length})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
