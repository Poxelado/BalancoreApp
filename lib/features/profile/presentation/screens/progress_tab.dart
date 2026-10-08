import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../training/presentation/screens/workout_session_screen.dart';
import '../../../training/presentation/screens/edit_workout_history_screen.dart';
import 'daily_history_screen.dart';
import '../widgets/weekly_macro_card.dart';

RoutineDay _routineFromSession(WorkoutSession s) {
  return RoutineDay(
    day: s.dayName,
    title: s.title.isEmpty ? s.dayName : s.title,
    exercises: [
      for (final e in s.exercises)
        RoutineExercise(
          exerciseId: e.exerciseId,
          exerciseName: e.exerciseName,
          muscleGroup: e.muscleGroup,
          sets: e.sets.length,
          reps: e.sets.isNotEmpty ? e.sets.first.reps : 10,
          plannedSets: [
            for (final set in e.sets)
              PlannedSet(weight: set.weight, reps: set.reps),
          ],
          restSeconds: e.restSeconds,
          notes: e.notes,
        ),
    ],
  );
}

class ProgressTab extends ConsumerStatefulWidget {
  const ProgressTab({super.key});

  @override
  ConsumerState<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<ProgressTab> {
  int _trainPeriodDays = 30;
  int _summaryPeriodDays = 7;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final section = ref.watch(progressSectionProvider);

    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Entrenos'),
                icon: Icon(Icons.fitness_center, size: 13),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Registros'),
                icon: Icon(Icons.calendar_view_week, size: 13),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Hábitos'),
                icon: Icon(Icons.water_drop_outlined, size: 13),
              ),
            ],
            selected: {section},
            onSelectionChanged: (s) {
              ref.read(progressSectionProvider.notifier).state = s.first;
              invalidateProgressData(ref);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return primary;
                return null;
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: primary,
            onRefresh: () async {
              invalidateProgressData(ref);
              await Future.wait([
                ref.refresh(
                  workoutHistoryProvider(
                    section == 0
                        ? _trainPeriodDays + 14
                        : _summaryPeriodDays + 14,
                  ).future,
                ),
                ref.refresh(
                  dailyLogsHistoryProvider(_summaryPeriodDays + 14).future,
                ),
                ref.refresh(todayLogProvider.future),
              ]);
            },
            child: switch (section) {
              0 => _WorkoutsSection(
                primary: primary,
                periodDays: _trainPeriodDays,
                onPeriodChanged: (d) =>
                    setState(() => _trainPeriodDays = d),
              ),
              1 => _WeekSummarySection(
                primary: primary,
                periodDays: _summaryPeriodDays,
                onPeriodChanged: (d) {
                  setState(() => _summaryPeriodDays = d);
                  invalidateProgressData(ref);
                },
              ),
              _ => _HabitsSection(primary: primary),
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// CONSTANCIA (una sola vista, sin duplicar)
// ═══════════════════════════════════════════════════════════

class _WeekSummarySection extends ConsumerWidget {
  final Color primary;
  final int periodDays;
  final ValueChanged<int> onPeriodChanged;

  const _WeekSummarySection({
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
                      child: _MetricCard(
                        icon: Icons.fitness_center,
                        label: 'Entrenos',
                        value: '$completed',
                        subtitle: 'ok',
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _MetricCard(
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
                      child: _MetricCard(
                        icon: Icons.percent,
                        label: 'Adher.',
                        value: '${(adherenceGlobal * 100).round()}%',
                        subtitle: '${registeredDays.length}/$periodDays',
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: _MetricCard(
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
                  _WeekCircles(
                    start: _rangeStart,
                    end: _rangeEnd,
                    trainDays: trainDays,
                    registeredDays: registeredDays,
                    primary: primary,
                  )
                else
                  _ConsistencyGrid(
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
                      _LegendDot(color: primary, label: 'Entreno'),
                      const SizedBox(width: 12),
                      _LegendDot(
                        color:
                        const Color(0xFF4CAF50).withValues(alpha: 0.7),
                        label: 'Hábitos',
                      ),
                      const SizedBox(width: 12),
                      _LegendDot(
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
                _HabitRow(
                  icon: Icons.restaurant,
                  label: 'Días con comida registrada',
                  value: '${foodDays.length} / $periodDays',
                  color: const Color(0xFFFF9800),
                ),
                _HabitRow(
                  icon: Icons.water_drop,
                  label: 'Días con agua',
                  value: '${waterDays.length} / $periodDays',
                  color: const Color(0xFF2196F3),
                ),
                _HabitRow(
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
class _WeekCircles extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final Set<DateTime> trainDays;
  final Set<DateTime> registeredDays;
  final Color primary;

  const _WeekCircles({
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

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
class _ConsistencyGrid extends StatelessWidget {
  final DateTime start;
  final DateTime end;
  final Set<DateTime> trainDays;
  final Set<DateTime> registeredDays;
  final Color primary;

  const _ConsistencyGrid({
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

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 72;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 2 : 4,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: narrow ? 14 : 16),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: narrow ? 13 : 15,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: narrow ? 9 : 11,
                  ),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: narrow ? 8 : 9,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HabitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _HabitRow({
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

// ═══════════════════════════════════════════════════════════
// ENTRENAMIENTOS
// ═══════════════════════════════════════════════════════════

class _WorkoutsSection extends ConsumerWidget {
  final Color primary;
  final int periodDays;
  final ValueChanged<int> onPeriodChanged;

  const _WorkoutsSection({
    required this.primary,
    required this.periodDays,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _WorkoutsSectionBody(
      primary: primary,
      periodDays: periodDays,
      onPeriodChanged: onPeriodChanged,
    );
  }
}

class _WorkoutsSectionBody extends ConsumerStatefulWidget {
  final Color primary;
  final int periodDays;
  final ValueChanged<int> onPeriodChanged;

  const _WorkoutsSectionBody({
    required this.primary,
    required this.periodDays,
    required this.onPeriodChanged,
  });

  @override
  ConsumerState<_WorkoutsSectionBody> createState() =>
      _WorkoutsSectionBodyState();
}

class _WorkoutsSectionBodyState extends ConsumerState<_WorkoutsSectionBody> {
  String? _selectedMuscle;
  bool _detailExpanded = false;

  static const _periods = <(int, String, String)>[
    (7, '1 semana', 'Última semana'),
    (30, '1 mes', 'Último mes'),
    (90, '3 meses', 'Últimos 3 meses'),
    (180, '6 meses', 'Últimos 6 meses'),
    (365, '1 año', 'Último año'),
  ];

  static const _muscleColors = <String, Color>{
    'pecho': Color(0xFFE91E63),
    'espalda': Color(0xFF2196F3),
    'hombro': Color(0xFFFF9800),
    'hombros': Color(0xFFFF9800),
    'bíceps': Color(0xFF9C27B0),
    'biceps': Color(0xFF9C27B0),
    'brazo': Color(0xFF9C27B0),
    'tríceps': Color(0xFF673AB7),
    'triceps': Color(0xFF673AB7),
    'pierna': Color(0xFF4CAF50),
    'piernas': Color(0xFF4CAF50),
    'glúteo': Color(0xFF8BC34A),
    'gluteo': Color(0xFF8BC34A),
    'core': Color(0xFF00BCD4),
    'abdomen': Color(0xFF00BCD4),
    'cardio': Color(0xFFFF5722),
    'sin grupo': Color(0xFF78909C),
  };

  Color _colorForMuscle(String raw) {
    final k = raw.trim().toLowerCase();
    if (k.isEmpty || k == 'sin grupo') return const Color(0xFF78909C);
    for (final e in _muscleColors.entries) {
      if (k.contains(e.key)) return e.value;
    }
    final palette = _muscleColors.values.toList();
    return palette[k.hashCode.abs() % palette.length];
  }

  String _normMuscle(String raw) {
    final x = raw.trim();
    if (x.isEmpty) return 'Sin grupo';
    return x[0].toUpperCase() + (x.length > 1 ? x.substring(1) : '');
  }

  String get _title {
    for (final p in _periods) {
      if (p.$1 == widget.periodDays) return p.$3;
    }
    return 'Rango';
  }

  String get _periodLabel {
    for (final p in _periods) {
      if (p.$1 == widget.periodDays) return p.$2;
    }
    return '${widget.periodDays} d';
  }

  Future<void> _pickPeriod() async {
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
                  trailing: widget.periodDays == p.$1
                      ? Icon(Icons.check, color: widget.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, p.$1),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (chosen != null) widget.onPeriodChanged(chosen);
  }

  List<DateTime> _bucketStarts() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    final useWeeks = widget.periodDays > 30;
    final starts = <DateTime>[];
    if (useWeeks) {
      var cursor = end.subtract(Duration(days: end.weekday - 1));
      final earliest = end.subtract(Duration(days: widget.periodDays - 1));
      while (!cursor.isBefore(earliest.subtract(const Duration(days: 6)))) {
        starts.add(cursor);
        cursor = cursor.subtract(const Duration(days: 7));
        if (starts.length > 26) break;
      }
      return starts.reversed.toList();
    }
    for (var i = widget.periodDays - 1; i >= 0; i--) {
      starts.add(end.subtract(Duration(days: i)));
    }
    return starts;
  }

  String _bucketKey(DateTime d, {required bool weeks}) {
    if (weeks) {
      final monday = d.subtract(Duration(days: d.weekday - 1));
      return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
    }
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  void _onSelectMuscle(String muscle) {
    setState(() {
      if (_selectedMuscle == muscle) {
        // Deseleccionar → vuelve a vista general
        _selectedMuscle = null;
        _detailExpanded = false;
      } else {
        _selectedMuscle = muscle;
        _detailExpanded = true; // auto-expand al elegir
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;
    final periodDays = widget.periodDays;
    final historyAsync = ref.watch(workoutHistoryProvider(periodDays));
    final cardBg = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.65);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (sessions) {
        final now = DateTime.now();
        final rangeEnd =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
        final rangeStart = rangeEnd.subtract(Duration(days: periodDays));

        bool inRange(DateTime d) {
          final day = DateTime(d.year, d.month, d.day);
          return !day.isBefore(rangeStart) && day.isBefore(rangeEnd);
        }

        final sorted = sessions.where((s) => inRange(s.startedAt)).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        final completed = sorted.where((s) => s.completed).toList();
        final trainDays = <String>{};
        for (final s in completed) {
          final d = s.startedAt;
          trainDays.add(
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
          );
        }
        final perWeek = periodDays >= 7
            ? (completed.length / (periodDays / 7)).toStringAsFixed(1)
            : '${completed.length}';

        final muscleSets = <String, int>{};
        final muscleExercises = <String, Map<String, int>>{};
        var totalSets = 0;
        var totalExercises = 0;
        final byTimeMuscle = <String, Map<String, int>>{};
        final useWeeks = periodDays > 30;

        for (final s in completed) {
          final tk = _bucketKey(s.startedAt, weeks: useWeeks);
          byTimeMuscle.putIfAbsent(tk, () => {});
          for (final e in s.exercises) {
            final muscle = _normMuscle(e.muscleGroup);
            final done = e.completedSets;
            final setsCount = done > 0 ? done : e.sets.length;
            if (setsCount <= 0) continue;
            totalSets += setsCount;
            totalExercises++;
            muscleSets[muscle] = (muscleSets[muscle] ?? 0) + setsCount;
            muscleExercises.putIfAbsent(muscle, () => {});
            final map = muscleExercises[muscle]!;
            final name = e.exerciseName.trim().isEmpty
                ? 'Ejercicio'
                : e.exerciseName.trim();
            map[name] = (map[name] ?? 0) + setsCount;
            final tm = byTimeMuscle[tk]!;
            tm[muscle] = (tm[muscle] ?? 0) + setsCount;
          }
        }

        final muscleOrder = muscleSets.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // Métricas filtradas por sector (o generales)
        int showSessions = completed.length;
        int showSets = totalSets;
        int showExercises = totalExercises;
        var showDays = trainDays.length;
        var showPerWeek = perWeek;
        List<WorkoutSession> listSessions = sorted;

        if (_selectedMuscle != null) {
          final sel = _selectedMuscle!;
          final filtered = <WorkoutSession>[];
          final days = <String>{};
          var sets = 0;
          var exs = 0;
          for (final s in sorted) {
            var has = false;
            for (final e in s.exercises) {
              if (_normMuscle(e.muscleGroup) != sel) continue;
              has = true;
              final done = e.completedSets;
              final sc = done > 0 ? done : e.sets.length;
              if (sc > 0) {
                sets += sc;
                exs++;
              }
            }
            if (has) {
              filtered.add(s);
              if (s.completed) {
                final d = s.startedAt;
                days.add(
                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
                );
              }
            }
          }
          listSessions = filtered;
          showSessions = filtered.where((s) => s.completed).length;
          if (showSessions == 0) showSessions = filtered.length;
          showSets = sets;
          showExercises = exs;
          showDays = days.length;
          showPerWeek = periodDays >= 7
              ? (showSessions / (periodDays / 7)).toStringAsFixed(1)
              : '$showSessions';
        }

        // Chart muscles: selected only, or top 5 if none
        final chartMuscles = _selectedMuscle != null
            ? [_selectedMuscle!]
            : muscleOrder.take(5).map((e) => e.key).toList();

        final buckets = _bucketStarts();

        // Agrupar sesiones por semana o mes
        String sessionGroupKey(DateTime d) {
          if (periodDays <= 14) {
            // por día
            return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          }
          if (periodDays <= 60) {
            // por semana (lunes)
            final mon = d.subtract(Duration(days: d.weekday - 1));
            return 'W${mon.year}-${mon.month.toString().padLeft(2, '0')}-${mon.day.toString().padLeft(2, '0')}';
          }
          // por mes
          return 'M${d.year}-${d.month.toString().padLeft(2, '0')}';
        }

        String sessionGroupTitle(String key, List<WorkoutSession> group) {
          if (key.startsWith('W')) {
            final p = key.substring(1).split('-');
            final mon = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
            final sun = mon.add(const Duration(days: 6));
            String f(DateTime x) =>
                '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}';
            return 'Semana ${f(mon)} – ${f(sun)}';
          }
          if (key.startsWith('M')) {
            final p = key.substring(1).split('-');
            const months = [
              '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
              'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
            ];
            final m = int.parse(p[1]);
            return '${months[m]} ${p[0]}';
          }
          // día
          final p = key.split('-');
          final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
          const wd = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
          return '${wd[d.weekday]} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
        }

        final grouped = <String, List<WorkoutSession>>{};
        for (final s in listSessions) {
          final k = sessionGroupKey(s.startedAt);
          grouped.putIfAbsent(k, () => []).add(s);
        }
        final groupKeys = grouped.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            // Rango
            Row(
              children: [
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Material(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _pickPeriod,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Rango',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _periodLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primary,
                              fontSize: 13,
                            ),
                          ),
                          Icon(Icons.expand_more, size: 18, color: primary),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (completed.isEmpty) ...[
              const SizedBox(height: 40),
              Icon(
                Icons.fitness_center_outlined,
                size: 56,
                color: primary.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sin entrenamientos en este periodo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ] else ...[
              // 1) Sectores arriba
              Text(
                'Sectores musculares',
                style: TextStyle(fontWeight: FontWeight.w600, color: primary),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedMuscle == null
                    ? 'Toca un sector para filtrar métricas, gráfico y sesiones.'
                    : 'Filtro: $_selectedMuscle · toca el mismo sector para quitar el filtro.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              _MuscleSectorChipsRow(
                muscleOrder: muscleOrder,
                colorFor: _colorForMuscle,
                selected: _selectedMuscle,
                cardBg: cardBg,
                onSelect: _onSelectMuscle,
              ),
              const SizedBox(height: 8),

              // 2) Detalle desplegable
              if (_selectedMuscle != null)
                _MuscleDetailPanel(
                  muscle: _selectedMuscle!,
                  sets: muscleSets[_selectedMuscle!] ?? 0,
                  exercises: muscleExercises[_selectedMuscle!] ?? {},
                  color: _colorForMuscle(_selectedMuscle!),
                  cardBg: cardBg,
                  expanded: _detailExpanded,
                  onToggle: () =>
                      setState(() => _detailExpanded = !_detailExpanded),
                ),
              if (_selectedMuscle != null) const SizedBox(height: 12),

              // 3) Métricas (respetan sector seleccionado)
              Text(
                _selectedMuscle == null
                    ? '$showDays/$periodDays días · $showPerWeek/semana'
                    : '$_selectedMuscle · $showDays días · $showPerWeek/semana',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.fitness_center,
                      label: 'Entrenos',
                      value: '$showSessions',
                      subtitle: _selectedMuscle == null ? 'ok' : 'con sector',
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.repeat,
                      label: 'Series',
                      value: '$showSets',
                      subtitle: _selectedMuscle ?? (periodDays <= 7 ? 'semana' : 'rango'),
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.list_alt,
                      label: 'Ejercicios',
                      value: '$showExercises',
                      subtitle: 'logs',
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.calendar_today,
                      label: 'Días',
                      value: '$showDays',
                      subtitle: 'entreno',
                      color: const Color(0xFF2196F3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4) Gráfico (filtrado si hay sector)
              Text(
                _selectedMuscle != null
                    ? 'Series · $_selectedMuscle'
                    : 'Series por grupo muscular',
                style: TextStyle(fontWeight: FontWeight.w600, color: primary),
              ),
              const SizedBox(height: 4),
              Text(
                useWeeks
                    ? 'Por semana en el rango'
                    : 'Por día en el rango',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              Container(
                height: 220,
                padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: chartMuscles.isEmpty || buckets.isEmpty
                    ? const Center(child: Text('Sin datos para graficar'))
                    : _MuscleSeriesChart(
                  buckets: buckets,
                  useWeeks: useWeeks,
                  muscles: chartMuscles,
                  byTimeMuscle: byTimeMuscle,
                  colorFor: _colorForMuscle,
                  bucketKeyFn: (d, {required bool weeks}) => _bucketKey(d, weeks: weeks),
                ),
              ),
              if (chartMuscles.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    for (final m in chartMuscles)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _colorForMuscle(m),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(m, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // 5) Sesiones agrupadas (semana / mes)
              Text(
                _selectedMuscle == null
                    ? 'Sesiones'
                    : 'Sesiones · $_selectedMuscle',
                style: TextStyle(fontWeight: FontWeight.w600, color: primary),
              ),
              const SizedBox(height: 8),
              if (listSessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _selectedMuscle == null
                        ? 'No hay sesiones en este periodo.'
                        : 'No hay sesiones con ejercicios de $_selectedMuscle.',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...groupKeys.map((gk) {
                  final group = grouped[gk]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      child: Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: groupKeys.indexOf(gk) == 0,
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 2,
                          ),
                          title: Text(
                            sessionGroupTitle(gk, group),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${group.length} sesión${group.length == 1 ? '' : 'es'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          children: [
                            for (final s in group)
                              ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: s.completed
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : primary.withValues(alpha: 0.12),
                                  child: Icon(
                                    s.completed
                                        ? Icons.check
                                        : Icons.fitness_center,
                                    color:
                                    s.completed ? Colors.green : primary,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  s.title.isEmpty ? s.dayName : s.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${s.dayName} · ${_fmt(s.startedAt)} · '
                                      '${s.completed ? 'Completado' : 'En curso'} · '
                                      '${s.exercises.fold<int>(0, (a, e) => a + e.completedSets)}/${s.exercises.fold<int>(0, (a, e) => a + e.sets.length)} series',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    final user = ref
                                        .read(authServiceProvider)
                                        .currentUser;
                                    if (user == null) return;
                                    if (v == 'open') {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              WorkoutSessionScreen(
                                                routine:
                                                _routineFromSession(s),
                                                existing:
                                                s.completed ? null : s,
                                              ),
                                        ),
                                      );
                                      ref.invalidate(
                                        workoutHistoryProvider(periodDays),
                                      );
                                    } else if (v == 'edit') {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EditWorkoutHistoryScreen(
                                                session: s,
                                              ),
                                        ),
                                      );
                                      ref.invalidate(
                                        workoutHistoryProvider(periodDays),
                                      );
                                    } else if (v == 'delete') {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title:
                                          const Text('Eliminar sesión'),
                                          content: const Text(
                                            '¿Borrar este entrenamiento?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child:
                                              const Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await ref
                                            .read(
                                          profileRepositoryProvider,
                                        )
                                            .deleteWorkoutSession(
                                          user.uid,
                                          s.id,
                                        );
                                        ref.invalidate(
                                          workoutHistoryProvider(
                                            periodDays,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'open',
                                      child: Text('Abrir / continuar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Eliminar',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WorkoutSessionScreen(
                                        routine: _routineFromSession(s),
                                        existing: s.completed ? null : s,
                                      ),
                                    ),
                                  );
                                  ref.invalidate(
                                    workoutHistoryProvider(periodDays),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ],
        );
      },
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _MuscleSectorChipsRow extends StatelessWidget {
  final List<MapEntry<String, int>> muscleOrder;
  final Color Function(String) colorFor;
  final String? selected;
  final Color cardBg;
  final ValueChanged<String> onSelect;

  const _MuscleSectorChipsRow({
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
              _MuscleChip(
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

class _MuscleDetailPanel extends StatelessWidget {
  final String muscle;
  final int sets;
  final Map<String, int> exercises;
  final Color color;
  final Color cardBg;
  final bool expanded;
  final VoidCallback onToggle;

  const _MuscleDetailPanel({
    required this.muscle,
    required this.sets,
    required this.exercises,
    required this.color,
    required this.cardBg,
    required this.expanded,
    required this.onToggle,
  });

  static const Map<String, List<String>> _subZones = {
    'Pecho': ['General', 'Superior', 'Medio', 'Inferior'],
    'Espalda': ['General', 'Dorsal', 'Trapecio', 'Lumbar'],
    'Hombro': ['General', 'Deltoides ant.', 'Lateral', 'Posterior'],
    'Hombros': ['General', 'Deltoides ant.', 'Lateral', 'Posterior'],
    'Bíceps': ['General', 'Corto', 'Largo'],
    'Biceps': ['General', 'Corto', 'Largo'],
    'Brazo': ['General', 'Bíceps', 'Tríceps'],
    'Tríceps': ['General', 'Largo', 'Lateral', 'Medial'],
    'Triceps': ['General', 'Largo', 'Lateral', 'Medial'],
    'Pierna': ['General', 'Cuádriceps', 'Isquios', 'Pantorrilla'],
    'Piernas': ['General', 'Cuádriceps', 'Isquios', 'Pantorrilla'],
    'Glúteo': ['General', 'Mayor', 'Medio'],
    'Core': ['General', 'Abdomen', 'Oblicuos'],
    'Abdomen': ['General', 'Superior', 'Inferior'],
    'Cardio': ['General'],
    'Sin grupo': ['General'],
  };

  List<String> get _zones {
    if (_subZones.containsKey(muscle)) return _subZones[muscle]!;
    final k = muscle.toLowerCase();
    for (final e in _subZones.entries) {
      if (k.contains(e.key.toLowerCase())) return e.value;
    }
    return const ['General'];
  }

  @override
  Widget build(BuildContext context) {
    final exList = exercises.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
                  Text(
                    'Zona específica',
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
                      for (final z in _zones)
                        Chip(
                          label: Text(z, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: z == 'General'
                              ? color.withValues(alpha: 0.2)
                              : null,
                        ),
                    ],
                  ),
                  Text(
                    'Las subzonas se usarán cuando la biblioteca tenga detalle.',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 10),
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

class _MuscleChip extends StatelessWidget {
  final String label;
  final int sets;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MuscleChip({
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

class _MuscleSeriesChart extends StatelessWidget {
  final List<DateTime> buckets;
  final bool useWeeks;
  final List<String> muscles;
  final Map<String, Map<String, int>> byTimeMuscle;
  final Color Function(String) colorFor;
  final String Function(DateTime d, {required bool weeks}) bucketKeyFn;

  const _MuscleSeriesChart({
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

    return LineChart(
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
    );
  }
}


// ═══════════════════════════════════════════════════════════
// HÁBITOS
// ═══════════════════════════════════════════════════════════

class _HabitsSection extends StatelessWidget {
  final Color primary;
  const _HabitsSection({required this.primary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      children: const [
        WeeklyMacroCard(),
        DailyHistoryScreen(embedded: true),
      ],
    );
  }
}
