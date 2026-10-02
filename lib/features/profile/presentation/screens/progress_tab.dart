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
  /// 0 = Semana, 1 = Entrenos, 2 = Hábitos
  int _section = 0;
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
              ButtonSegment(value: 0, label: Text('Semana'), icon: Icon(Icons.calendar_view_week, size: 16)),
              ButtonSegment(value: 1, label: Text('Entrenos'), icon: Icon(Icons.fitness_center, size: 16)),
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
            0 => _WeekSummarySection(primary: primary),
            1 => _WorkoutsSection(
              primary: primary,
              periodDays: _trainPeriodDays,
              onPeriodChanged: (d) => setState(() => _trainPeriodDays = d),
            ),
            _ => _HabitsSection(primary: primary),
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SECCIÓN: ESTA SEMANA
// ═══════════════════════════════════════════════════════════

class _WeekSummarySection extends ConsumerWidget {
  final Color primary;
  const _WeekSummarySection({required this.primary});

  static DateTime _startOfWeek(DateTime d) {
    // Lunes = inicio
    final weekday = d.weekday; // 1=lun ... 7=dom
    return DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: weekday - 1));
  }

  static String _dayLabel(DateTime d) {
    const names = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return names[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutHistoryProvider(14));
    final logsAsync = ref.watch(dailyLogsHistoryProvider(14));
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
            final now = DateTime.now();
            final weekStart = _startOfWeek(now);
            final weekEnd = weekStart.add(const Duration(days: 7));

            final weekSessions = allSessions.where((s) {
              final d = s.startedAt;
              return !d.isBefore(weekStart) && d.isBefore(weekEnd);
            }).toList();

            final completed = weekSessions.where((s) => s.completed).length;
            final plannedDays = 5; // heurística; más adelante con rutina real
            final adherenceTrain = plannedDays > 0
                ? (completed / plannedDays).clamp(0.0, 1.0)
                : 0.0;

            final weekLogs = allLogs.where((l) {
              final parts = l.date.split('-');
              if (parts.length < 3) return false;
              final d = DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
              return !d.isBefore(weekStart) && d.isBefore(weekEnd);
            }).toList();

            final daysWithFood = weekLogs
                .where((l) => l.consumedCalories > 0 || l.meals.isNotEmpty)
                .length;
            final daysWithWater =
                weekLogs.where((l) => l.waterGlasses > 0).length;
            final daysWithSleep =
                weekLogs.where((l) => l.sleepHours > 0).length;

            double avgCal = 0;
            if (weekLogs.isNotEmpty) {
              avgCal = weekLogs.fold<int>(0, (a, l) => a + l.consumedCalories) /
                  weekLogs.length;
            }

            // Adherencia global: media de entrenar + registrar comida (sobre 7 días)
            final dayHits = <int>{};
            for (final s in weekSessions.where((s) => s.completed)) {
              dayHits.add(DateTime(s.startedAt.year, s.startedAt.month,
                  s.startedAt.day)
                  .difference(weekStart)
                  .inDays);
            }
            for (final l in weekLogs) {
              if (l.consumedCalories > 0 ||
                  l.meals.isNotEmpty ||
                  l.waterGlasses > 0) {
                final parts = l.date.split('-');
                if (parts.length >= 3) {
                  final d = DateTime(
                    int.parse(parts[0]),
                    int.parse(parts[1]),
                    int.parse(parts[2]),
                  );
                  dayHits.add(d.difference(weekStart).inDays);
                }
              }
            }
            final adherenceGlobal = (dayHits.length / 7).clamp(0.0, 1.0);

            // Mapa día → hizo entreno
            final trainByDay = <int, bool>{};
            for (var i = 0; i < 7; i++) {
              trainByDay[i] = false;
            }
            for (final s in weekSessions.where((s) => s.completed)) {
              final idx = DateTime(s.startedAt.year, s.startedAt.month,
                  s.startedAt.day)
                  .difference(weekStart)
                  .inDays;
              if (idx >= 0 && idx < 7) trainByDay[idx] = true;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Esta semana',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                Text(
                  '${_fmtDate(weekStart)} – ${_fmtDate(weekEnd.subtract(const Duration(days: 1)))}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Cards métricas
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.fitness_center,
                        label: 'Entrenos',
                        value: '$completed',
                        subtitle: 'completados',
                        color: primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.local_fire_department,
                        label: 'Kcal media',
                        value: avgCal > 0 ? avgCal.round().toString() : '—',
                        subtitle: targetCal > 0 ? 'meta $targetCal' : 'registradas',
                        color: const Color(0xFFFF9800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.percent,
                        label: 'Adherencia',
                        value: '${(adherenceGlobal * 100).round()}%',
                        subtitle: '${dayHits.length}/7 días activos',
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        icon: Icons.sports_gymnastics,
                        label: 'Entrenos',
                        value: '${(adherenceTrain * 100).round()}%',
                        subtitle: 'vs $plannedDays planificados',
                        color: const Color(0xFF2196F3),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Text(
                  'Días con entrenamiento',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (i) {
                    final day = weekStart.add(Duration(days: i));
                    final done = trainByDay[i] == true;
                    final isToday = day.year == now.year &&
                        day.month == now.month &&
                        day.day == now.day;
                    return Column(
                      children: [
                        Text(
                          _dayLabel(day),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday ? primary : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: done
                                ? primary
                                : primary.withValues(alpha: 0.08),
                            border: isToday
                                ? Border.all(color: primary, width: 2)
                                : null,
                          ),
                          child: done
                              ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                              : null,
                        ),
                      ],
                    );
                  }),
                ),

                const SizedBox(height: 24),
                Text(
                  'Hábitos de la semana',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 10),
                _HabitRow(
                  icon: Icons.restaurant,
                  label: 'Días con comida registrada',
                  value: '$daysWithFood / 7',
                  color: const Color(0xFFFF9800),
                ),
                _HabitRow(
                  icon: Icons.water_drop,
                  label: 'Días con agua',
                  value: '$daysWithWater / 7',
                  color: const Color(0xFF2196F3),
                ),
                _HabitRow(
                  icon: Icons.bedtime,
                  label: 'Días con sueño',
                  value: '$daysWithSleep / 7',
                  color: const Color(0xFF9E9E9E),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
