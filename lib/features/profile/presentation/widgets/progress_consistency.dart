import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'metric_card.dart';

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

/// Vista semanal: 7 círculos L–D (como el diseño original).
class WeekCircles extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final Set<DateTime> trainDays;
  final Set<DateTime> registeredDays;
  final Color primary;

  const WeekCircles({super.key, 
    required this.start,
    required this.end,
    required this.trainDays,
    required this.registeredDays,
    required this.primary,
  });

  static const _labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Semana calendario actual (Lun–Dom que contiene "hoy"),
    // no la semana del rangeStart (eso dejaba días vacíos).
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = monday.add(Duration(days: i));
        final key = DateTime(day.year, day.month, day.day);
        final inRange = !key.isBefore(
          DateTime(start.year, start.month, start.day),
        ) &&
            key.isBefore(DateTime(end.year, end.month, end.day));
        final trained = inRange && trainDays.contains(key);
        final registered =
            inRange && registeredDays.contains(key) && !trained;
        final isToday = key == today;
        final isFuture = key.isAfter(today);

        Color fill;
        if (!inRange || isFuture) {
          fill = Colors.grey.withValues(alpha: 0.12);
        } else if (trained) {
          fill = primary;
        } else if (registered) {
          fill = const Color(0xFF4CAF50).withValues(alpha: 0.75);
        } else {
          fill = primary.withValues(alpha: 0.08);
        }

        return Column(
          children: [
            Text(
              _labels[i],
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? primary : Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: isToday ? Border.all(color: primary, width: 2) : null,
              ),
              child: trained
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : (registered
                  ? Icon(Icons.circle,
                  color: Colors.white.withValues(alpha: 0.9), size: 10)
                  : null),
            ),
          ],
        );
      }),
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
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// Rejilla de constancia: llena el ancho; en 6m/1a gaps mínimos.
class ConsistencyGrid extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final Set<DateTime> trainDays;
  final Set<DateTime> registeredDays;
  final Color primary;

  const ConsistencyGrid({super.key, 
    required this.start,
    required this.end,
    required this.trainDays,
    required this.registeredDays,
    required this.primary,
  });

  static const _monthShort = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static const _dayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final gridStart = start.subtract(Duration(days: start.weekday - 1));
    final totalDays = end.difference(gridStart).inDays;
    final weeks = (totalDays / 7).ceil().clamp(1, 53);

    final isYearView = weeks >= 40;
    final isHalfYear = weeks >= 20 && weeks < 40; // ~6 meses

    final monthAtWeek = <int, String>{};
    for (var w = 0; w < weeks; w++) {
      final mid = gridStart.add(Duration(days: w * 7 + 3));
      final prevMid =
      w == 0 ? null : gridStart.add(Duration(days: (w - 1) * 7 + 3));
      if (w == 0 || prevMid!.month != mid.month) {
        final weekBegin = gridStart.add(Duration(days: w * 7));
        final weekEnd = weekBegin.add(const Duration(days: 6));
        if (!weekEnd.isBefore(start) && weekBegin.isBefore(end)) {
          monthAtWeek[w] = _monthShort[mid.month - 1];
        }
      }
    }
    final monthKeys = monthAtWeek.keys.toList()..sort();
    final spans = <({int start, int count, String label})>[];
    for (var i = 0; i < monthKeys.length; i++) {
      final ws = monthKeys[i];
      final we = i + 1 < monthKeys.length ? monthKeys[i + 1] : weeks;
      spans.add((
      start: ws,
      count: (we - ws).clamp(1, 12),
      label: monthAtWeek[ws]!,
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const padH = 6.0;
        final maxW = (constraints.maxWidth - padH * 2).clamp(40.0, 4000.0);
        final dayLabelW = isYearView ? 0.0 : 11.0;

        // Gaps muy chicos en 6 meses / año → celdas más grandes y juntas
        final double gap;
        if (isYearView) {
          gap = 1.0;
        } else if (isHalfYear) {
          gap = 1.2;
        } else if (weeks > 14) {
          gap = 2.0;
        } else {
          gap = 2.5;
        }

        // Usar TODO el ancho: sin tope superior de celda
        final gapsTotal = weeks > 1 ? (weeks - 1) * gap : 0.0;
        final usable = maxW - dayLabelW - gapsTotal;
        var cell = weeks > 0 ? usable / weeks : 8.0;
        // Solo mínimo legible; el máximo es el que quepa
        if (isYearView) {
          cell = cell.clamp(3.5, 100.0);
        } else if (isHalfYear) {
          cell = cell.clamp(5.0, 100.0);
        } else {
          cell = cell.clamp(8.0, 14.0);
        }

        double spanWidth(int count) =>
            count * cell + (count > 1 ? (count - 1) * gap : 0);

        final labelFont = isYearView ? 8.0 : (isHalfYear ? 9.0 : 10.0);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(padH, 10, padH, 8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 14,
                child: Row(
                  children: [
                    SizedBox(width: dayLabelW),
                    ...List.generate(spans.length, (i) {
                      final sp = spans[i];
                      final isLast = i == spans.length - 1;
                      return SizedBox(
                        width: spanWidth(sp.count) + (isLast ? 0 : gap),
                        child: Text(
                          sp.label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: labelFont,
                            height: 1.1,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              for (var wd = 0; wd < 7; wd++)
                Padding(
                  padding: EdgeInsets.only(bottom: wd == 6 ? 0 : gap),
                  child: Row(
                    children: [
                      if (!isYearView)
                        SizedBox(
                          width: dayLabelW,
                          child: Text(
                            (wd == 0 || wd == 2 || wd == 4)
                                ? _dayLetters[wd]
                                : '',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ...List.generate(weeks, (w) {
                        final day =
                        gridStart.add(Duration(days: w * 7 + wd));
                        final inRange =
                            !day.isBefore(start) && day.isBefore(end);
                        final key = DateTime(day.year, day.month, day.day);
                        final trained = trainDays.contains(key);
                        final registered =
                            registeredDays.contains(key) && !trained;

                        final Color bg;
                        if (!inRange) {
                          bg = Colors.transparent;
                        } else if (trained) {
                          bg = primary;
                        } else if (registered) {
                          bg = const Color(0xFF4CAF50)
                              .withValues(alpha: 0.65);
                        } else {
                          bg = Colors.grey
                              .withValues(alpha: isYearView ? 0.18 : 0.22);
                        }

                        return Padding(
                          padding: EdgeInsets.only(
                            right: w == weeks - 1 ? 0 : gap,
                          ),
                          child: Container(
                            width: cell,
                            height: cell,
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(
                                cell < 7 ? 1.5 : 2.0,
                              ),
                            ),
                          ),
                        );
                      }),
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


class HabitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const HabitRow({super.key, 
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

