import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/preferences/units_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'weight_history_screen.dart';
import 'edit_profile_screen.dart';
import '../widgets/profile_tab_widgets.dart';
import '../../../training/domain/workout_share_metrics.dart';
import '../../../training/presentation/screens/edit_workout_history_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../training/presentation/screens/exercise_detail_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/achievements/achievements_screen.dart';

/// Sección del historial: puede ser una hoja (con sus sesiones) o una rama
/// que agrupa subsecciones (p. ej. un mes con sus semanas).
class _HistoryGroup {
  final String title;
  final List<WorkoutSession> sessions;
  final List<_HistoryGroup> children;

  const _HistoryGroup.leaf(this.title, this.sessions) : children = const [];
  const _HistoryGroup.branch(this.title, this.children) : sessions = const [];

  bool get isLeaf => children.isEmpty;

  int get count =>
      isLeaf ? sessions.length : children.fold(0, (a, c) => a + c.count);
}

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  int _periodDays = 30;

  static const _periods = <(int, String)>[
    (7, '1 semana'),
    (30, '1 mes'),
    (90, '3 meses'),
    (180, '6 meses'),
    (365, '1 año'),
  ];

  static const _weekdays = [
    '', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];
  static const _monthFull = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  String _initials(UserProfile profile) {
    final name =
        profile.displayName ?? profile.username ?? profile.email ?? 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  String _fmtDuration(WorkoutSession s) {
    if (s.finishedAt == null) {
      if (!s.completed) return 'en curso';
      return '—';
    }
    final d = s.finishedAt!.difference(s.startedAt);
    if (d.inHours >= 1) {
      final m = d.inMinutes.remainder(60);
      return '${d.inHours}h ${m}m';
    }
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    return '${d.inMinutes}m';
  }

  /// Peso máximo levantado en series efectivas (sin calentamiento).
  double _maxWeight(WorkoutExerciseLog e) {
    var max = 0.0;
    for (final s in e.sets) {
      if (s.completed && !s.isWarmup && s.weight > max) max = s.weight;
    }
    return max;
  }

  // --- Agrupación -----------------------------------------------------------

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day)
          .subtract(Duration(days: d.weekday - 1));

  String _weekTitle(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    return 'Semana ${monday.day}/${monday.month} – ${sunday.day}/${sunday.month}';
  }

  List<_HistoryGroup> _weekGroups(List<WorkoutSession> sessions) {
    final map = <String, List<WorkoutSession>>{};
    for (final s in sessions) {
      map.putIfAbsent(_dayKey(_mondayOf(s.startedAt)), () => []).add(s);
    }
    final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final k in keys)
        _HistoryGroup.leaf(_weekTitle(DateTime.parse(k)), map[k]!),
    ];
  }

  List<_HistoryGroup> _buildGroups(List<WorkoutSession> sessions) {
    final sorted = [...sessions]
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    if (_periodDays <= 7) {
      final map = <String, List<WorkoutSession>>{};
      for (final s in sorted) {
        map.putIfAbsent(_dayKey(s.startedAt), () => []).add(s);
      }
      final keys = map.keys.toList()..sort((a, b) => b.compareTo(a));
      return [
        for (final k in keys)
          _HistoryGroup.leaf(
            '${_weekdays[map[k]!.first.startedAt.weekday]} '
            '${map[k]!.first.startedAt.day}/${map[k]!.first.startedAt.month}',
            map[k]!,
          ),
      ];
    }

    if (_periodDays <= 30) return _weekGroups(sorted);

    final byMonth = <String, List<WorkoutSession>>{};
    for (final s in sorted) {
      byMonth.putIfAbsent(
        '${s.startedAt.year}-${s.startedAt.month.toString().padLeft(2, '0')}',
        () => [],
      ).add(s);
    }
    final keys = byMonth.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final k in keys)
        _HistoryGroup.branch(
          '${_monthFull[int.parse(k.split('-')[1])]} ${k.split('-')[0]}',
          _weekGroups(byMonth[k]!),
        ),
    ];
  }

  // --- Detalle --------------------------------------------------------------

  void _showSessionDetail(WorkoutSession s) {
    final primary = Theme.of(context).colorScheme.primary;
    final units = ref.read(unitsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.title.isEmpty ? s.dayName : s.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditWorkoutHistoryScreen(session: s),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              title: const Text('Eliminar sesión'),
                              content: const Text(
                                '¿Borrar este entrenamiento del historial?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.error,
                                  ),
                                  child: const Text('Eliminar'),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                          final user =
                              ref.read(authServiceProvider).currentUser;
                          if (user == null) return;
                          await ref
                              .read(profileRepositoryProvider)
                              .deleteWorkoutSession(user.uid, s.id);
                          ref.invalidate(
                            workoutHistoryProvider(_periodDays),
                          );
                          ref.invalidate(activeWorkoutSessionProvider);
                          if (context.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _DetailChip(
                          icon: Icons.event,
                          text: _fmtDate(s.startedAt),
                        ),
                        _DetailChip(
                          icon: Icons.timer_outlined,
                          text: _fmtDuration(s),
                        ),
                        _DetailChip(
                          icon: s.completed
                              ? Icons.check_circle
                              : Icons.hourglass_empty,
                          text: s.completed ? 'Completado' : 'En curso',
                          color: s.completed
                              ? AppSemanticColors.of(context).success
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: s.exercises.length,
                    itemBuilder: (_, i) {
                      final e = s.exercises[i];
                      final done =
                          e.sets.where((set) => set.completed).length;
                      final max = _maxWeight(e);
                      final parts = <String>[
                        e.muscleGroup.isEmpty ? 'Sin sector' : e.muscleGroup,
                        '$done/${e.sets.length} series',
                        if (max > 0)
                          'Máx ${units.formatWeight(max, decimals: max == max.roundToDouble() ? 0 : 1)}',
                      ];
                      return ListTile(
                        title: Text(e.exerciseName),
                        subtitle: Text(
                          e.notes.isNotEmpty
                              ? '${parts.join(' · ')}\n📝 ${e.notes}'
                              : parts.join(' · '),
                        ),
                        isThreeLine: e.notes.isNotEmpty,
                        trailing: Icon(
                          done == e.sets.length && e.sets.isNotEmpty
                              ? Icons.check_circle
                              : Icons.fitness_center,
                          color: done == e.sets.length && e.sets.isNotEmpty
                              ? AppSemanticColors.of(context).success
                              : primary,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExerciseDetailScreen(
                                exerciseId: e.exerciseId,
                                exerciseName: e.exerciseName,
                                muscleGroup: e.muscleGroup,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final historyAsync = ref.watch(workoutHistoryProvider(_periodDays));
    final units = ref.watch(unitsProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return profileAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: accentOf(context))),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('No hay perfil'));
        }

        final sessions = historyAsync.valueOrNull ?? [];
        final completedCount = sessions.where((s) => s.completed).length;
        final groups = _buildGroups(sessions);

        return CustomScrollView(
          slivers: [
            // Avatar + stats
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditProfileScreen(profile: profile),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: primary.withValues(alpha: 0.15),
                        child: Text(
                          _initials(profile),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: accentOf(context),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          StatColumn(
                            value: historyAsync.isLoading
                                ? '…'
                                : '$completedCount',
                            label: 'Entrenos',
                          ),
                          StatColumn(
                            value: units
                                .weightToDisplay(profile.currentWeight)
                                .toStringAsFixed(0),
                            label: units.weightUnit,
                          ),
                          StatColumn(
                            value: '${profile.targetCalories}',
                            label: 'kcal meta',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Nombre + bio + datos
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile.displayName != null &&
                        profile.displayName!.isNotEmpty)
                      Text(
                        profile.displayName!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile.bio!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${profile.sex} · ${units.formatHeight(profile.height)} · ${profile.activityLevel}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Botones
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AchievementsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.emoji_events_outlined, size: 18),
                        label: const Text('Logros'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WeightHistoryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                        label: const Text('Peso'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Historial header + rango
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Historial de entrenamientos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: accentOf(context),
                      ),
                    ),
                    const Spacer(),
                    _RangeSelector(
                      label: _periods
                          .firstWhere((p) => p.$1 == _periodDays)
                          .$2,
                      periods: _periods,
                      selected: _periodDays,
                      onSelected: (v) => setState(() => _periodDays = v),
                    ),
                  ],
                ),
              ),
            ),

            if (historyAsync.isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator(color: accentOf(context))),
                ),
              )
            else if (sessions.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.fitness_center_outlined,
                  title: 'Sin entrenamientos',
                  subtitle:
                  'Completa una sesión desde Rutina para verla aquí.',
                  actionLabel: 'Ir a Rutina',
                  onAction: () {
                    try {
                      ref.read(shellTabProvider.notifier).state = 3;
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Abre la pestaña Rutina para entrenar'),
                        ),
                      );
                    }
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HistoryGroupTile(
                        group: groups[i],
                        initiallyExpanded: i == 0,
                        fmtDate: _fmtDate,
                        fmtDuration: _fmtDuration,
                        onTapSession: _showSessionDetail,
                      ),
                    ),
                    childCount: groups.length,
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

/// Chip pequeño con icono + texto para la cabecera del detalle.
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _DetailChip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}

/// Selector de rango desplegable (1 semana … 1 año).
class _RangeSelector extends StatelessWidget {
  final String label;
  final List<(int, String)> periods;
  final int selected;
  final ValueChanged<int> onSelected;

  const _RangeSelector({
    required this.label,
    required this.periods,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return PopupMenuButton<int>(
      tooltip: 'Rango',
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        for (final p in periods)
          PopupMenuItem(
            value: p.$1,
            child: Row(
              children: [
                Icon(
                  p.$1 == selected ? Icons.check : null,
                  size: 18,
                  color: primary,
                ),
                const SizedBox(width: 8),
                Text(p.$2),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
            Icon(Icons.expand_more, size: 16, color: primary),
          ],
        ),
      ),
    );
  }
}

/// Sección desplegable del historial con su rejilla de tarjetas o, si es una
/// rama, con sus subsecciones (semanas dentro de un mes).
class _HistoryGroupTile extends StatelessWidget {
  final _HistoryGroup group;
  final bool initiallyExpanded;
  final String Function(DateTime) fmtDate;
  final String Function(WorkoutSession) fmtDuration;
  final void Function(WorkoutSession) onTapSession;

  const _HistoryGroupTile({
    required this.group,
    required this.initiallyExpanded,
    required this.fmtDate,
    required this.fmtDuration,
    required this.onTapSession,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: Text(
            group.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            group.count == 1 ? '1 sesión' : '${group.count} sesiones',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          children: [
            if (group.isLeaf)
              _sessionGrid(group.sessions)
            else
              for (final child in group.children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _HistoryGroupTile(
                    group: child,
                    initiallyExpanded: false,
                    fmtDate: fmtDate,
                    fmtDuration: fmtDuration,
                    onTapSession: onTapSession,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _sessionGrid(List<WorkoutSession> sessions) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.72,
      children: [
        for (final s in sessions)
          WorkoutCard(
            date: fmtDate(s.startedAt),
            duration: fmtDuration(s),
            completed: s.completed,
            title: s.title.isEmpty ? s.dayName : s.title,
            intensity: buildWorkoutShareData(s).bodyIntensity,
            onTap: () => onTapSession(s),
          ),
      ],
    );
  }
}
