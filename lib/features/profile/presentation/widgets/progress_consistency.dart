import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'metric_card.dart';
import 'consistency_widgets.dart';

// ═══════════════════════════════════════════════════════════
// CONSTANCIA (una sola vista, sin duplicar)
// ═══════════════════════════════════════════════════════════

class WeekSummarySection extends ConsumerWidget {
  final Color primary;
  final int periodDays;
  final ValueChanged<int> onPeriodChanged;

  const WeekSummarySection({super.key, 
    required this.primary,
    required this.periodDays,
    required this.onPeriodChanged,
  });

  static const _periods = <(int, String, String)>[
    (7, '1 semana', 'Última semana'),
    (30, '1 mes', 'Último mes'),
    (90, '3 meses', 'Últimos 3 meses'),
    (180, '6 meses', 'Últimos 6 meses'),
    (365, '1 año', 'Último año'),
  ];

  String get _title {
    for (final p in _periods) {
      if (p.$1 == periodDays) return p.$3;
    }
    return 'Rango';
  }

  String get _periodLabel {
    for (final p in _periods) {
      if (p.$1 == periodDays) return p.$2;
    }
    return '$periodDays d';
  }

  DateTime get _rangeEnd {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
  }

  DateTime get _rangeStart =>
      _rangeEnd.subtract(Duration(days: periodDays));

  Future<void> _pickPeriod(BuildContext context) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Seleccionar rango',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              for (final p in _periods)
                ListTile(
                  title: Text(p.$2),
                  trailing: periodDays == p.$1
                      ? Icon(Icons.check, color: primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, p.$1),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (chosen != null) onPeriodChanged(chosen);
  }

  bool _inRange(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(_rangeStart) && day.isBefore(_rangeEnd);
  }

  DateTime? _parseLogDate(String date) {
    final parts = date.split('-');
    if (parts.length < 3) return null;
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fetchDays = periodDays + 7;
    final workoutsAsync = ref.watch(workoutHistoryProvider(fetchDays));
    final logsAsync = ref.watch(dailyLogsHistoryProvider(fetchDays));
    final profile = ref.watch(userProfileProvider).value;
    final targetCal = profile?.targetCalories ?? 0;
    final isWeekView = periodDays <= 7;

    return workoutsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allSessions) {
        return logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error logs: $e')),
          data: (allLogs) {
            final rangeSessions =
            allSessions.where((s) => _inRange(s.startedAt)).toList();
            final completedSessions =
            rangeSessions.where((s) => s.completed).toList();
            final completed = completedSessions.length;

            final trainDays = <DateTime>{};
            for (final s in completedSessions) {
              final local = s.startedAt.toLocal();
              trainDays.add(DateTime(local.year, local.month, local.day));
            }

            final rangeLogs = <DailyLog>[];
            final logDays = <DateTime>{};
            final foodDays = <DateTime>{};
            final waterDays = <DateTime>{};
            final sleepDays = <DateTime>{};

            for (final l in allLogs) {
              final d = _parseLogDate(l.date);
              if (d == null || !_inRange(d)) continue;
              rangeLogs.add(l);
              final hasAny = l.consumedCalories > 0 ||
                  l.meals.isNotEmpty ||
                  l.waterGlasses > 0 ||
                  l.sleepHours > 0;
              if (hasAny) logDays.add(d);
              if (l.consumedCalories > 0 || l.meals.isNotEmpty) {
                foodDays.add(d);
              }
              if (l.waterGlasses > 0) waterDays.add(d);
              if (l.sleepHours > 0) sleepDays.add(d);
            }

            final registeredDays = {...trainDays, ...logDays};

            double avgCal = 0;
            if (rangeLogs.isNotEmpty) {
              avgCal = rangeLogs.fold<int>(
                  0, (a, l) => a + l.consumedCalories) /
                  rangeLogs.length;
            }

            final weeks = (periodDays / 7).clamp(1.0, 60.0);
            final planned = (5 * weeks).round().clamp(1, 999);
            final adherenceTrain = (completed / planned).clamp(0.0, 1.0);
            final adherenceGlobal =
            (registeredDays.length / periodDays).clamp(0.0, 1.0);
            final perWeek = registeredDays.length / weeks;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Cabecera + periodo (una sola vez)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${registeredDays.length}/$periodDays días · '
                                '${perWeek.toStringAsFixed(1)}/semana',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _pickPeriod(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rango',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _periodLabel,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primary,
                                    ),
                                  ),
                                  Icon(Icons.expand_more,
                                      size: 18, color: primary),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Métricas (una sola fila, una sola vez)
                Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        icon: Icons.fitness_center,
                        label: 'Entrenos',
                        value: '$completed',
                        subtitle: 'ok',
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.local_fire_department,
                        label: 'Kcal',
                        value: avgCal > 0 ? avgCal.round().toString() : '—',
                        subtitle:
                        targetCal > 0 ? 'meta $targetCal' : 'media',
                        color: const Color(0xFFFF9800),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.percent,
                        label: 'Adher.',
                        value: '${(adherenceGlobal * 100).round()}%',
                        subtitle: '${registeredDays.length}/$periodDays',
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: MetricCard(
                        icon: Icons.sports_gymnastics,
                        label: 'Plan',
                        value: '${(adherenceTrain * 100).round()}%',
                        subtitle: 'vs $planned',
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Text(
                  'Días registrados',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 10),

                // Vista semana = círculos | mes+ = rejilla compacta
                if (isWeekView)
                  WeekCircles(
                    start: _rangeStart,
                    end: _rangeEnd,
                    trainDays: trainDays,
                    registeredDays: registeredDays,
                    primary: primary,
                  )
                else
                  ConsistencyGrid(
                    start: _rangeStart,
                    end: _rangeEnd,
                    trainDays: trainDays,
                    registeredDays: registeredDays,
                    primary: primary,
                  ),

                if (!isWeekView) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      LegendDot(color: primary, label: 'Entreno'),
                      const SizedBox(width: 12),
                      LegendDot(
                        color:
                        const Color(0xFF4CAF50).withValues(alpha: 0.7),
                        label: 'Hábitos',
                      ),
                      const SizedBox(width: 12),
                      LegendDot(
                        color: Colors.grey.withValues(alpha: 0.25),
                        label: 'Vacío',
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
                Text(
                  'Hábitos del periodo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 10),
                HabitRow(
                  icon: Icons.restaurant,
                  label: 'Días con comida registrada',
                  value: '${foodDays.length} / $periodDays',
                  color: const Color(0xFFFF9800),
                ),
                HabitRow(
                  icon: Icons.water_drop,
                  label: 'Días con agua',
                  value: '${waterDays.length} / $periodDays',
                  color: const Color(0xFF2196F3),
                ),
                HabitRow(
                  icon: Icons.bedtime,
                  label: 'Días con sueño',
                  value: '${sleepDays.length} / $periodDays',
                  color: const Color(0xFF9E9E9E),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

