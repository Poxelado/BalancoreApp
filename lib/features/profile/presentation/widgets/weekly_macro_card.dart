import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/macro_week_analysis.dart';
import '../providers/profile_provider.dart';

/// Card desplegable de análisis semanal de macros (Progreso → Hábitos).
class WeeklyMacroCard extends ConsumerStatefulWidget {
  const WeeklyMacroCard({super.key});

  @override
  ConsumerState<WeeklyMacroCard> createState() => _WeeklyMacroCardState();
}

class _WeeklyMacroCardState extends ConsumerState<WeeklyMacroCard> {
  bool _expanded = false;

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static String _delta(double? d, {String suffix = ''}) {
    if (d == null) return '—';
    final sign = d >= 0 ? '+' : '';
    return '$sign${d.round()}$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final profile = ref.watch(userProfileProvider).value;
    final logsAsync = ref.watch(dailyLogsHistoryProvider(14));

    return logsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (logs) {
        final report = MacroWeekAnalysis.build(
          logs: logs,
          profile: profile,
        );

        final subtitle = report.daysWithData == 0
            ? 'Registra comidas en Nutrición para ver el análisis'
            : '${_fmtDate(report.weekStart)} – ${_fmtDate(report.weekEnd)}'
            ' · ${report.daysWithData} días con datos';

        return Card(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.insights, color: primary),
                title: Text(
                  'Macros · esta semana',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                subtitle: Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: primary,
                ),
                onTap: () => setState(() => _expanded = !_expanded),
              ),
              if (_expanded && report.daysWithData == 0)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    'Cuando registres kcal o macros en Nutrición, aquí verás '
                        'promedios, cumplimiento de proteína y comparación con la semana pasada.',
                  ),
                ),
              if (_expanded && report.daysWithData > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _HitChip(
                              label: 'Proteína OK',
                              value:
                              '${report.daysHitProtein}/${report.daysWithData}',
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HitChip(
                              label: 'Kcal en rango',
                              value:
                              '${report.daysHitCalories}/${report.daysWithData}',
                              color: const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _MacroBar(
                        label: 'Kcal',
                        avg: report.avgCalories,
                        target: report.targetCalories.toDouble(),
                        delta: report.deltaCalories,
                        color: const Color(0xFFFF9800),
                        unit: '',
                      ),
                      _MacroBar(
                        label: 'Proteína',
                        avg: report.avgProtein,
                        target: report.targetProtein.toDouble(),
                        delta: report.deltaProtein,
                        color: const Color(0xFF4CAF50),
                        unit: 'g',
                      ),
                      _MacroBar(
                        label: 'Carbos',
                        avg: report.avgCarbs,
                        target: report.targetCarbs.toDouble(),
                        delta: report.deltaCarbs,
                        color: const Color(0xFFFFC107),
                        unit: 'g',
                      ),
                      _MacroBar(
                        label: 'Grasas',
                        avg: report.avgFat,
                        target: report.targetFat.toDouble(),
                        delta: report.deltaFat,
                        color: const Color(0xFFE91E63),
                        unit: 'g',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Distribución calórica media',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          height: 10,
                          child: Row(
                            children: [
                              if (report.proteinCalPct > 0)
                                Expanded(
                                  flex:
                                  report.proteinCalPct.round().clamp(1, 100),
                                  child: Container(
                                      color: const Color(0xFF4CAF50)),
                                ),
                              if (report.carbsCalPct > 0)
                                Expanded(
                                  flex:
                                  report.carbsCalPct.round().clamp(1, 100),
                                  child: Container(
                                      color: const Color(0xFFFFC107)),
                                ),
                              if (report.fatCalPct > 0)
                                Expanded(
                                  flex: report.fatCalPct.round().clamp(1, 100),
                                  child: Container(
                                      color: const Color(0xFFE91E63)),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'P ${report.proteinCalPct.round()}% · '
                            'C ${report.carbsCalPct.round()}% · '
                            'G ${report.fatCalPct.round()}%',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                      if (report.prevAvgCalories != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Vs semana pasada: kcal ${_delta(report.deltaCalories)} · '
                              'prot ${_delta(report.deltaProtein, suffix: 'g')}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HitChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HitChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double avg;
  final double target;
  final double? delta;
  final Color color;
  final String unit;

  const _MacroBar({
    required this.label,
    required this.avg,
    required this.target,
    required this.delta,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final pct = target > 0 ? (avg / target).clamp(0.0, 1.5) : 0.0;
    final barPct = pct.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${avg.round()}$unit'
                      '${target > 0 ? ' / ${target.round()}$unit' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (delta != null)
                Text(
                  '${delta! >= 0 ? '↑' : '↓'} ${delta!.abs().round()}$unit',
                  style: TextStyle(
                    fontSize: 11,
                    color: delta! >= 0
                        ? const Color(0xFF4CAF50)
                        : Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barPct,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
