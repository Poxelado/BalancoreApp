import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../domain/personal_records.dart';
import '../../domain/session_stats.dart';
import '../../../../core/theme/app_theme.dart';

/// Resumen de una sesión recién terminada: qué se hizo, cómo se comparó con
/// la sesión anterior y qué récords se batieron.
class WorkoutSummaryScreen extends StatelessWidget {
  final SessionStats stats;
  final List<PersonalRecord> records;
  final String title;
  final int calories;

  const WorkoutSummaryScreen({
    super.key,
    required this.stats,
    this.records = const [],
    this.title = 'Entrenamiento completado',
    this.calories = 0,
  });

  Color _colorFor(BuildContext context, int i) {
    final s = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    final palette = [
      s.primary,
      sem.info,
      sem.success,
      sem.warning,
      s.secondary,
      sem.rest,
      s.tertiary,
      s.primaryContainer,
    ];
    return palette[i % palette.length];
  }

  static String _fmtDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  static String _fmtKg(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} t';
    if (v == v.roundToDouble()) return '${v.toInt()}';
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              '¡$title! 🎉',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: accentOf(context),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _stat(
                    icon: Icons.timer_outlined,
                    label: 'Duración',
                    value: _fmtDuration(stats.durationSeconds),
                    primary: accentOf(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _stat(
                    icon: Icons.check_circle_outline,
                    label: 'Series',
                    value: '${stats.completedSets}/${stats.totalSets}',
                    primary: accentOf(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _stat(
                    icon: Icons.fitness_center,
                    label: 'Volumen',
                    value: '${_fmtKg(stats.totalVolume)} kg',
                    primary: accentOf(context),
                  ),
                ),
              ],
            ),
            if (stats.hasPrevious) ...[
              const SizedBox(height: 10),
              _comparison(context, accentOf(context)),
            ],
            if (calories > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppDataColors.calories.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppDataColors.calories.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0x22FF9800),
                      child: Icon(
                        Icons.local_fire_department,
                        color: AppDataColors.calories,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Gasto estimado',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppDataColors.calories,
                            ),
                          ),
                          Text(
                            '≈ $calories kcal',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Sumado a tu gasto de hoy',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (records.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle('Récords personales', Icons.emoji_events, accentOf(context)),
              const SizedBox(height: 8),
              for (final r in records)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppDataColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppDataColors.gold.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events,
                          color: AppDataColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${r.exerciseName} · ${r.label}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        _fmtKg(r.value),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppDataColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (stats.volumeByMuscle.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle(
                  'Distribución por músculo', Icons.donut_large, accentOf(context)),
              const SizedBox(height: 8),
              _muscleDonut(context),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, IconData icon, Color primary) => Row(
        children: [
          Icon(icon, size: 18, color: primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      );

  Widget _stat({
    required IconData icon,
    required String label,
    required String value,
    required Color primary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: primary),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _comparison(BuildContext context, Color primary) {
    final delta = stats.volumeDelta ?? 0;
    final up = stats.volumeImproved;
    final pct = stats.volumeDeltaPercent;
    final sem = AppSemanticColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (up ? sem.success : sem.warning).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            up ? Icons.trending_up : Icons.trending_down,
            color: up ? sem.success : sem.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              up
                  ? 'Mejor que la sesión anterior'
                  : 'Por debajo de la sesión anterior',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${up ? '+' : ''}${_fmtKg(delta.abs())} kg'
            '${pct == null ? '' : ' (${pct.abs().toStringAsFixed(0)}%)'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: up ? sem.success : sem.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _muscleDonut(BuildContext context) {
    final entries = stats.volumeByMuscle.entries.toList();
    // Con muchos grupos, el donut se vuelve ilegible: se agrupa la cola.
    final shown = entries.take(5).toList();
    final restTotal = entries.length > 5
        ? entries.skip(5).fold<double>(0, (s, e) => s + e.value)
        : 0.0;
    final slices = <({String label, double value, Color color})>[
      for (var i = 0; i < shown.length; i++)
        (label: shown[i].key, value: shown[i].value, color: _colorFor(context, i)),
      if (restTotal > 0)
        (label: 'Otros', value: restTotal, color: _colorFor(context, shown.length)),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Semantics(
              label: 'Distribución de series por grupo muscular',
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                  sections: [
                    for (final s in slices)
                      PieChartSectionData(
                        value: s.value,
                        color: s.color,
                        radius: 34,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in slices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(s.label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                        ),
                        Text('${_fmtKg(s.value)} kg',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}