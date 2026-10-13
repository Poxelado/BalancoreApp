import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'metric_card.dart';
import 'progress_muscles.dart';
import 'progress_workouts_tiles.dart';
import '../../../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════
// ENTRENAMIENTOS
// ═══════════════════════════════════════════════════════════

class WorkoutsSection extends ConsumerWidget {
  final Color primary;
  final int periodDays;
  final ValueChanged<int> onPeriodChanged;

  const WorkoutsSection({super.key, 
    required this.primary,
    required this.periodDays,
    required this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WorkoutsSectionBody(
      primary: primary,
      periodDays: periodDays,
      onPeriodChanged: onPeriodChanged,
    );
  }
}

class WorkoutsSectionBody extends ConsumerStatefulWidget {
  final Color primary;
  final int periodDays;
  final ValueChanged<int> onPeriodChanged;

  const WorkoutsSectionBody({super.key, 
    required this.primary,
    required this.periodDays,
    required this.onPeriodChanged,
  });

  @override
  ConsumerState<WorkoutsSectionBody> createState() =>
      WorkoutsSectionBodyState();
}

class WorkoutsSectionBodyState extends ConsumerState<WorkoutsSectionBody> {
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
            WorkoutRangeHeader(
              title: _title,
              periodLabel: _periodLabel,
              primary: primary,
              cardBg: cardBg,
              onPickPeriod: _pickPeriod,
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
                style: TextStyle(fontWeight: FontWeight.w600, color: accentOf(context)),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedMuscle == null
                    ? 'Toca un sector para filtrar métricas, gráfico y sesiones.'
                    : 'Filtro: $_selectedMuscle · toca el mismo sector para quitar el filtro.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              MuscleSectorChipsRow(
                muscleOrder: muscleOrder,
                colorFor: _colorForMuscle,
                selected: _selectedMuscle,
                cardBg: cardBg,
                onSelect: _onSelectMuscle,
              ),
              const SizedBox(height: 8),

              // 2) Detalle desplegable
              if (_selectedMuscle != null)
                MuscleDetailPanel(
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
                    child: MetricCard(
                      icon: Icons.fitness_center,
                      label: 'Entrenos',
                      value: '$showSessions',
                      subtitle: _selectedMuscle == null ? 'ok' : 'con sector',
                      color: accentOf(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: MetricCard(
                      icon: Icons.repeat,
                      label: 'Series',
                      value: '$showSets',
                      subtitle: _selectedMuscle ?? (periodDays <= 7 ? 'semana' : 'rango'),
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: MetricCard(
                      icon: Icons.list_alt,
                      label: 'Ejercicios',
                      value: '$showExercises',
                      subtitle: 'logs',
                      color: const Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: MetricCard(
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
                style: TextStyle(fontWeight: FontWeight.w600, color: accentOf(context)),
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
                    : MuscleSeriesChart(
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
                style: TextStyle(fontWeight: FontWeight.w600, color: accentOf(context)),
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
                  return WorkoutSessionGroupTile(
                    title: sessionGroupTitle(gk, group),
                    group: group,
                    primary: primary,
                    cardBg: cardBg,
                    periodDays: periodDays,
                    initiallyExpanded: groupKeys.indexOf(gk) == 0,
                  );
                }),
            ],
          ],
        );
      },
    );
  }
}
