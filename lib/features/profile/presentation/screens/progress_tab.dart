import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../training/presentation/screens/workout_session_screen.dart';
import '../../../training/presentation/screens/edit_workout_history_screen.dart';
import 'daily_history_screen.dart';

/// 4.ª pestaña: Progreso
/// - Semana: entrenos, kcal media, adherencia
/// - Entrenos: historial de sesiones
/// - Hábitos: atajo al historial de nutrición / agua / sueño

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
  /// 0 = Entrenos, 1 = Semana, 2 = Hábitos
  int _section = 1;
  int _trainPeriodDays = 30;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Entrenos'), icon: Icon(Icons.fitness_center, size: 16)),
              ButtonSegment(value: 1, label: Text('Semana'), icon: Icon(Icons.calendar_view_week, size: 16)),
              ButtonSegment(value: 2, label: Text('Hábitos'), icon: Icon(Icons.water_drop_outlined, size: 16)),
            ],
            selected: {_section},
            onSelectionChanged: (s) => setState(() => _section = s.first),
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
          child: switch (_section) {
            0 => _WorkoutsSection(
              primary: primary,
              periodDays: _trainPeriodDays,
              onPeriodChanged: (d) => setState(() => _trainPeriodDays = d),
            ),
            1 => _WeekSummarySection(primary: primary),
            _ => _HabitsSection(primary: primary),
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SECCIÓN: CONSTANCIA / PERIODO
// ═══════════════════════════════════════════════════════════

class _WeekSummarySection extends ConsumerStatefulWidget {
  final Color primary;
  const _WeekSummarySection({required this.primary});

  @override
  ConsumerState<_WeekSummarySection> createState() =>
      _WeekSummarySectionState();
}

class _WeekSummarySectionState extends ConsumerState<_WeekSummarySection> {
  /// Días del periodo: 7, 30, 90, 180, 365
  int _periodDays = 7;

  static const _periods = <(int, String, String)>[
    (7, '1 semana', 'Última semana'),
    (30, '1 mes', 'Último mes'),
    (90, '3 meses', 'Últimos 3 meses'),
    (180, '6 meses', 'Últimos 6 meses'),
    (365, '1 año', 'Último año'),
  ];

  String get _title {
    for (final p in _periods) {
      if (p.$1 == _periodDays) return p.$3;
    }
    return 'Periodo';
  }

  String get _periodLabel {
    for (final p in _periods) {
      if (p.$1 == _periodDays) return p.$2;
    }
    return '$_periodDays d';
  }

  DateTime get _rangeEnd {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
  }

  DateTime get _rangeStart {
    return _rangeEnd.subtract(Duration(days: _periodDays));
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
                      'Seleccionar periodo',
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
                  trailing: _periodDays == p.$1
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
    if (chosen != null) setState(() => _periodDays = chosen);
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
  Widget build(BuildContext context) {
    final primary = widget.primary;
    // Pedimos un poco más de margen de datos
    final fetchDays = _periodDays + 7;
    final workoutsAsync = ref.watch(workoutHistoryProvider(fetchDays));
    final logsAsync = ref.watch(dailyLogsHistoryProvider(fetchDays));
    final profile = ref.watch(userProfileProvider).value;
    final targetCal = profile?.targetCalories ?? 0;

    return workoutsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (allSessions) {
        return logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error logs: $e')),
          data: (allLogs) {
            final weekSessions = allSessions
                .where((s) => _inRange(s.startedAt))
                .toList();
            final completedSessions =
            weekSessions.where((s) => s.completed).toList();
            final completed = completedSessions.length;

            // Días con al menos un entreno completado
            final trainDays = <DateTime>{};
            for (final s in completedSessions) {
              trainDays.add(DateTime(
                s.startedAt.year,
                s.startedAt.month,
                s.startedAt.day,
              ));
            }

            final weekLogs = <DailyLog>[];
            final logDays = <DateTime>{};
            final foodDays = <DateTime>{};
            final waterDays = <DateTime>{};
            final sleepDays = <DateTime>{};

            for (final l in allLogs) {
              final d = _parseLogDate(l.date);
              if (d == null || !_inRange(d)) continue;
              weekLogs.add(l);
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

            // Días registrados = entreno O cualquier hábito
            final registeredDays = {...trainDays, ...logDays};

            double avgCal = 0;
            if (weekLogs.isNotEmpty) {
              avgCal = weekLogs.fold<int>(
                  0, (a, l) => a + l.consumedCalories) /
                  weekLogs.length;
            }

            // Plan: ~5 entrenos/semana * semanas del periodo
            final weeks = (_periodDays / 7).clamp(1.0, 60.0);
            final planned = (5 * weeks).round().clamp(1, 999);
            final adherenceTrain =
            (completed / planned).clamp(0.0, 1.0);
            final adherenceGlobal =
            (registeredDays.length / _periodDays).clamp(0.0, 1.0);
            final perWeek = registeredDays.length / weeks;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Título + selector de periodo
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
                            '${registeredDays.length}/$_periodDays días · '
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
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _pickPeriod,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Periodo',
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
                                  Icon(
                                    Icons.expand_more,
                                    size: 18,
                                    color: primary,
                                  ),
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

                // 4 métricas
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
                    const SizedBox(width: 6),
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
                    const SizedBox(width: 6),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.percent,
                        label: 'Adher.',
                        value: '${(adherenceGlobal * 100).round()}%',
                        subtitle: '${registeredDays.length}/$_periodDays',
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 6),
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
                _ConsistencyGrid(
                  start: _rangeStart,
                  end: _rangeEnd,
                  trainDays: trainDays,
                  registeredDays: registeredDays,
                  primary: primary,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _LegendDot(color: primary, label: 'Entreno'),
                    const SizedBox(width: 16),
                    _LegendDot(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.7),
                      label: 'Hábitos',
                    ),
                    const SizedBox(width: 16),
                    _LegendDot(
                      color: Colors.grey.withValues(alpha: 0.25),
                      label: 'Vacío',
                    ),
                  ],
                ),

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
                  value: '${foodDays.length} / $_periodDays',
                  color: const Color(0xFFFF9800),
                ),
                _HabitRow(
                  icon: Icons.water_drop,
                  label: 'Días con agua',
                  value: '${waterDays.length} / $_periodDays',
                  color: const Color(0xFF2196F3),
                ),
                _HabitRow(
                  icon: Icons.bedtime,
                  label: 'Días con sueño',
                  value: '${sleepDays.length} / $_periodDays',
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

/// Rejilla estilo constancia: filas = L..D, columnas = semanas del periodo.
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

  static const _dow = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    // Alinear inicio al lunes de esa semana
    final gridStart =
    start.subtract(Duration(days: start.weekday - 1));
    final totalDays = end.difference(gridStart).inDays;
    final weeks = (totalDays / 7).ceil().clamp(1, 60);

    // Celdas: [weekday 0..6][week 0..n]
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var wd = 0; wd < 7; wd++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      _dow[wd],
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...List.generate(weeks, (w) {
                    final day = gridStart.add(Duration(days: w * 7 + wd));
                    final inRange = !day.isBefore(start) && day.isBefore(end);
                    final key = DateTime(day.year, day.month, day.day);
                    final trained = trainDays.contains(key);
                    final registered =
                        registeredDays.contains(key) && !trained;

                    Color bg;
                    if (!inRange) {
                      bg = Colors.transparent;
                    } else if (trained) {
                      bg = primary;
                    } else if (registered) {
                      bg = const Color(0xFF4CAF50).withValues(alpha: 0.65);
                    } else {
                      bg = Colors.grey.withValues(alpha: 0.2);
                    }

                    return Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(1.5),
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(3),
                            ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
          ),
        ],
      ),
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
// SECCIÓN: ENTRENAMIENTOS (historial)
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
    final historyAsync = ref.watch(workoutHistoryProvider(periodDays));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              for (final e in [
                (7, '7D'),
                (30, '1M'),
                (90, '3M'),
                (180, '6M'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(e.$2, style: const TextStyle(fontSize: 12)),
                    selected: periodDays == e.$1,
                    onSelected: (_) => onPeriodChanged(e.$1),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: historyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (sessions) {
              if (sessions.isEmpty) {
                return const Center(
                  child: Text(
                    'Sin entrenamientos en este periodo.\nCompleta una sesión desde Rutina.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              final sorted = List<WorkoutSession>.from(sessions)
                ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final s = sorted[i];
                  final done = s.exercises.fold<int>(
                      0, (a, e) => a + e.completedSets);
                  final total = s.exercises.fold<int>(
                      0, (a, e) => a + e.sets.length);

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: s.completed
                            ? Colors.green.withValues(alpha: 0.15)
                            : primary.withValues(alpha: 0.12),
                        child: Icon(
                          s.completed
                              ? Icons.check
                              : Icons.fitness_center,
                          color: s.completed ? Colors.green : primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        s.title.isEmpty ? s.dayName : s.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${s.dayName} · ${_fmt(s.startedAt)}'
                            '${s.completed ? ' · Completado' : ' · En curso'}'
                            '\n$done/$total series · ${s.exercises.length} ejercicios',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          final user =
                              ref.read(authServiceProvider).currentUser;
                          if (user == null) return;
                          if (v == 'edit') {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditWorkoutHistoryScreen(session: s),
                              ),
                            );
                            ref.invalidate(
                                workoutHistoryProvider(periodDays));
                          } else if (v == 'open') {
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
                                workoutHistoryProvider(periodDays));
                          } else if (v == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (d) => AlertDialog(
                                title: const Text('Eliminar sesión'),
                                content: const Text(
                                  '¿Borrar este entrenamiento del historial?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(d, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(d, true),
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              await ref
                                  .read(profileRepositoryProvider)
                                  .deleteWorkoutSession(user.uid, s.id);
                              ref.invalidate(
                                  workoutHistoryProvider(periodDays));
                            }
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'open', child: Text('Abrir / continuar')),
                          const PopupMenuItem(
                              value: 'edit', child: Text('Editar')),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar',
                                  style: TextStyle(color: Colors.red))),
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
                        ref.invalidate(workoutHistoryProvider(periodDays));
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ═══════════════════════════════════════════════════════════
// SECCIÓN: HÁBITOS (nutrición / agua / sueño)
// ═══════════════════════════════════════════════════════════

class _HabitsSection extends StatelessWidget {
  final Color primary;
  const _HabitsSection({required this.primary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Historial de hábitos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Calorías, macros, agua y sueño por día. '
              'Antes estaba en el botón Historial del perfil.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: primary.withValues(alpha: 0.12),
              child: Icon(Icons.insights, color: primary),
            ),
            title: const Text('Ver historial diario'),
            subtitle: const Text('Gráficos y detalle por día'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DailyHistoryScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF2196F3).withValues(alpha: 0.12),
              child: const Icon(Icons.water_drop, color: Color(0xFF2196F3)),
            ),
            title: const Text('Agua y sueño'),
            subtitle: const Text('Incluidos en el historial diario'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DailyHistoryScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
