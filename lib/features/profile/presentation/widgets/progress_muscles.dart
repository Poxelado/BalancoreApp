import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MuscleSectorChipsRow extends StatelessWidget {
  final List<MapEntry<String, int>> muscleOrder;
  final Color Function(String) colorFor;
  final String? selected;
  final Color cardBg;
  final ValueChanged<String> onSelect;

  const MuscleSectorChipsRow({super.key, 
    required this.muscleOrder,
    required this.colorFor,
    required this.selected,
    required this.cardBg,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (muscleOrder.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Sin grupos musculares en este periodo.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final entry in muscleOrder) ...[
              MuscleChip(
                label: entry.key,
                sets: entry.value,
                color: colorFor(entry.key),
                selected: entry.key == selected,
                onTap: () => onSelect(entry.key),
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class MuscleDetailPanel extends StatelessWidget {
  final String muscle;
  final int sets;
  final Map<String, int> exercises;
  final Map<String, Map<String, int>> subZones;
  final Color color;
  final Color cardBg;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelectZone;

  const MuscleDetailPanel({super.key,
    required this.muscle,
    required this.sets,
    required this.exercises,
    this.subZones = const {},
    required this.color,
    required this.cardBg,
    required this.expanded,
    required this.onToggle,
    required this.onSelectZone,
  });

  @override
  Widget build(BuildContext context) {
    final exList = exercises.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final zoneEntries = subZones.entries.toList()
      ..sort((a, b) {
        final sa = a.value.values.fold(0, (s, v) => s + v);
        final sb = b.value.values.fold(0, (s, v) => s + v);
        return sb.compareTo(sa);
      });

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(
                    muscle,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$sets series',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: color,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (zoneEntries.isNotEmpty) ...[
                    Text(
                      'Zonas específicas',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final z in zoneEntries)
                          ActionChip(
                            label: Text(
                              '${z.key} · ${z.value.values.fold(0, (s, v) => s + v)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: color.withValues(alpha: 0.12),
                            side: BorderSide(color: color.withValues(alpha: 0.4)),
                            onPressed: () => onSelectZone(z.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  const Text(
                    'Ejercicios',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (exList.isEmpty)
                    Text(
                      'Sin ejercicios en este sector.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    )
                  else
                    ...exList.map(
                          (ex) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.fitness_center, size: 16, color: color),
                            const SizedBox(width: 8),
                            Expanded(child: Text(ex.key)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${ex.value}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MuscleChip extends StatelessWidget {
  final String label;
  final int sets;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const MuscleChip({super.key, 
    required this.label,
    required this.sets,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final short = label.length > 8 ? '${label.substring(0, 7)}…' : label;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? color.withValues(alpha: 0.28)
                    : color.withValues(alpha: 0.12),
                border: Border.all(
                  color: selected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(Icons.accessibility_new, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              short,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? color : Colors.grey.shade600,
              ),
            ),
            Text(
              '$sets',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MuscleSeriesChart extends StatelessWidget {
  final List<DateTime> buckets;
  final bool useWeeks;
  final List<String> muscles;
  final Map<String, Map<String, int>> byTimeMuscle;
  final Color Function(String) colorFor;
  final String Function(DateTime d, {required bool weeks}) bucketKeyFn;

  const MuscleSeriesChart({super.key, 
    required this.buckets,
    required this.useWeeks,
    required this.muscles,
    required this.byTimeMuscle,
    required this.colorFor,
    required this.bucketKeyFn,
  });

  @override
  Widget build(BuildContext context) {
    double maxY = 1;
    final bars = <LineChartBarData>[];

    for (final muscle in muscles) {
      final spots = <FlSpot>[];
      for (var i = 0; i < buckets.length; i++) {
        final key = bucketKeyFn(buckets[i], weeks: useWeeks);
        final v = (byTimeMuscle[key]?[muscle] ?? 0).toDouble();
        if (v > maxY) maxY = v;
        spots.add(FlSpot(i.toDouble(), v));
      }
      final c = colorFor(muscle);
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          color: c,
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: buckets.length <= 14,
            getDotPainter: (s, p, bar, i) => FlDotCirclePainter(
              radius: 3,
              color: c,
              strokeWidth: 0,
            ),
          ),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    final labelEvery = buckets.length <= 7
        ? 1
        : (buckets.length <= 14 ? 2 : (buckets.length / 5).ceil());

    return Semantics(
      label: 'Series por grupo muscular en el tiempo',
      child: LineChart(
        LineChartData(
        minX: 0,
        maxX: (buckets.length - 1).toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: maxY * 1.15,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? (maxY / 4).clamp(1, 999) : 1,
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
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, m) {
                if (v == 0) return const SizedBox.shrink();
                return Text(
                  v.toInt().toString(),
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (v, m) {
                final i = v.round();
                if (i < 0 || i >= buckets.length) {
                  return const SizedBox.shrink();
                }
                if (i % labelEvery != 0 && i != buckets.length - 1) {
                  return const SizedBox.shrink();
                }
                final d = buckets[i];
                final label =
                    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label,
                    style:
                    TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) {
              return touched.map((s) {
                final muscle = muscles[s.barIndex];
                return LineTooltipItem(
                  '$muscle: ${s.y.toInt()} series',
                  TextStyle(
                    color: colorFor(muscle),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: bars,
      ),
      ),
    );
  }
}


