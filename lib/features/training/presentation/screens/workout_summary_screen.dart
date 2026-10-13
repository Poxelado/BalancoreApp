import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../domain/personal_records.dart';
import '../../domain/session_stats.dart';

/// Resumen de una sesión recién terminada: qué se hizo, cómo se comparó con
/// la sesión anterior y qué récords se batieron.
class WorkoutSummaryScreen extends StatelessWidget {
  final SessionStats stats;
  final List<PersonalRecord> records;
  final String title;

  const WorkoutSummaryScreen({
    super.key,
    required this.stats,
    this.records = const [],
    this.title = 'Entrenamiento completado',
  });

  static const _palette = [
    Color(0xFF7C4DFF),
    Color(0xFF00ACC1),
    Color(0xFFFF7043),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFEC407A),
    Color(0xFF42A5F5),
    Color(0xFF8D6E63),
  ];

  Color _colorFor(int i) => _palette[i % _palette.length];

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
    final primary = theme.colorScheme.primary;

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
                color: primary,
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
                    primary: primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _stat(
                    icon: Icons.check_circle_outline,
                    label: 'Series',
                    value: '${stats.completedSets}/${stats.totalSets}',
                    primary: primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _stat(
                    icon: Icons.fitness_center,
                    label: 'Volumen',
                    value: '${_fmtKg(stats.totalVolume)} kg',
                    primary: primary,
                  ),
                ),
              ],
            ),
            if (stats.hasPrevious) ...[
              const SizedBox(height: 10),
              _comparison(primary),
            ],
            if (records.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle('Récords personales', Icons.emoji_events, primary),
              const SizedBox(height: 8),
              for (final r in records)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events,
                          color: Colors.amber, size: 18),
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
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (stats.volumeByMuscle.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle(
                  'Distribución por músculo', Icons.donut_large, primary),
              const SizedBox(height: 8),
              _muscleDonut(),
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

  Widget _comparison(Color primary) {
    final delta = stats.volumeDelta ?? 0;
    final up = stats.volumeImproved;
    final pct = stats.volumeDeltaPercent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (up ? Colors.green : Colors.orange).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            up ? Icons.trending_up : Icons.trending_down,
            color: up ? Colors.green : Colors.orange,
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
              color: up ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _muscleDonut() {
    final entries = stats.volumeByMuscle.entries.toList();
    // Con muchos grupos, el donut se vuelve ilegible: se agrupa la cola.
    final shown = entries.take(5).toList();
    final restTotal = entries.length > 5
        ? entries.skip(5).fold<double>(0, (s, e) => s + e.value)
        : 0.0;
    final slices = <({String label, double value, Color color})>[
      for (var i = 0; i < shown.length; i++)
        (label: shown[i].key, value: shown[i].value, color: _colorFor(i)),
      if (restTotal > 0)
        (label: 'Otros', value: restTotal, color: _colorFor(shown.length)),
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