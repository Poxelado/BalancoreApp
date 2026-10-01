import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'weight_history_screen.dart';
import 'edit_profile_screen.dart';
import 'daily_history_screen.dart';
import '../../../training/presentation/screens/workout_session_screen.dart';
import '../../../training/presentation/screens/edit_workout_history_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../training/presentation/screens/exercise_detail_screen.dart';


class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  int _periodDays = 30; // 1M default

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

  void _showSessionDetail(WorkoutSession s) {
    final primary = Theme.of(context).colorScheme.primary;
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title.isEmpty ? s.dayName : s.title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primary,
                              ),
                            ),
                            Text(
                              '${s.dayName} · ${_fmtDate(s.startedAt)}'
                                  '${s.completed ? ' · Completado' : ' · Incompleto'}',
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _fmtDuration(s),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            if (!s.completed) {
                              final day = RoutineDay(
                                day: s.dayName,
                                title: s.title,
                                exercises: s.exercises
                                    .map(
                                      (e) => RoutineExercise(
                                    exerciseId: e.exerciseId,
                                    exerciseName: e.exerciseName,
                                    muscleGroup: e.muscleGroup,
                                    sets: e.sets.length,
                                    reps: e.sets.isNotEmpty
                                        ? e.sets.first.reps
                                        : 10,
                                  ),
                                )
                                    .toList(),
                              );
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WorkoutSessionScreen(
                                    routine: day,
                                    existing: s,
                                  ),
                                ),
                              );
                            } else {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditWorkoutHistoryScreen(session: s),
                                ),
                              );
                            }
                            ref.invalidate(
                                workoutHistoryProvider(_periodDays));
                            ref.invalidate(activeWorkoutSessionProvider);
                          },
                          icon: Icon(
                              !s.completed ? Icons.play_arrow : Icons.edit),
                          label:
                          Text(!s.completed ? 'Continuar' : 'Editar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              title: const Text('Eliminar sesión'),
                              content: Text(
                                s.completed
                                    ? '¿Borrar este entrenamiento del historial?'
                                    : '¿Borrar esta sesión en curso?',
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(d, false),
                                    child: const Text('No')),
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(d, true),
                                    child: const Text('Eliminar',
                                        style: TextStyle(
                                            color: Colors.red))),
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
                          if (ctx.mounted) Navigator.pop(ctx);
                          ref.invalidate(
                              workoutHistoryProvider(_periodDays));
                          ref.invalidate(activeWorkoutSessionProvider);
                        },
                        child: const Icon(Icons.delete_outline,
                            color: Colors.red),
                      ),
                    ],
                  ),
                ),
                if (s.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      '📝 ${s.notes}',
                      style: const TextStyle(
                          fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${s.completedSets}/${s.totalSets} series',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${s.exercises.length} ejercicios',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    itemCount: s.exercises.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = s.exercises[i];
                      final done = e.completedSets;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.25),
                          ),
                        ),
                        title: Text(
                          e.exerciseName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          e.notes.isNotEmpty
                              ? '📝 ${e.notes}'
                              : '${e.muscleGroup.isEmpty ? 'Ejercicio' : e.muscleGroup} · $done/${e.sets.length} series',
                        ),
                        trailing: Icon(
                          done == e.sets.length && e.sets.isNotEmpty
                              ? Icons.check_circle
                              : Icons.fitness_center,
                          color: done == e.sets.length && e.sets.isNotEmpty
                              ? Colors.green
                              : primary,
                        ),
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
    final primary = Theme.of(context).colorScheme.primary;

    return profileAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('No hay perfil'));
        }

        final sessions = historyAsync.valueOrNull ?? [];
        final completedCount =
            sessions.where((s) => s.completed).length;

        return CustomScrollView(
          slivers: [
            // ─── Avatar + stats ────────────────────────────
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
                            color: primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatColumn(
                            value: historyAsync.isLoading
                                ? '…'
                                : '$completedCount',
                            label: 'Entrenos',
                          ),
                          _StatColumn(
                            value: profile.currentWeight.toStringAsFixed(0),
                            label: 'kg',
                          ),
                          _StatColumn(
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

            // ─── Nombre + bio ─────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile.displayName != null &&
                        profile.displayName!.isNotEmpty)
                      Text(
                        profile.displayName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(profile.bio!, style: const TextStyle(fontSize: 13)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${profile.sex} · ${profile.height.toStringAsFixed(0)} cm · ${profile.activityLevel}',
                      style:
                      const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Botones Historial | Peso ──────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DailyHistoryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('Historial'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(color: primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                        icon: const Icon(Icons.monitor_weight_outlined,
                            size: 18),
                        label: const Text('Peso'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(color: primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Historial entrenamientos ─────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Historial de entrenamientos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const Spacer(),
                    _PeriodChip(
                      label: '1M',
                      selected: _periodDays == 30,
                      onTap: () => setState(() => _periodDays = 30),
                    ),
                    _PeriodChip(
                      label: '3M',
                      selected: _periodDays == 90,
                      onTap: () => setState(() => _periodDays = 90),
                    ),
                    _PeriodChip(
                      label: '6M',
                      selected: _periodDays == 180,
                      onTap: () => setState(() => _periodDays = 180),
                    ),
                    _PeriodChip(
                      label: '1A',
                      selected: _periodDays == 365,
                      onTap: () => setState(() => _periodDays = 365),
                    ),
                  ],
                ),
              ),
            ),

            if (historyAsync.isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(color: primary),
                  ),
                ),
              )
            else if (sessions.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
                  child: Center(
                    child: Text(
                      'Aún no hay entrenamientos en este periodo.\n'
                          'Completa una sesión desde la pestaña Rutina.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                sliver: SliverGrid(
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final s = sessions[index];
                      return _WorkoutCard(
                        date: _fmtDate(s.startedAt),
                        duration: _fmtDuration(s),
                        completed: s.completed,
                        title: s.title.isEmpty ? s.dayName : s.title,
                        onTap: () => _showSessionDetail(s),
                      );
                    },
                    childCount: sessions.length,
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

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? primary
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final String date;
  final String duration;
  final bool completed;
  final String title;
  final VoidCallback onTap;

  const _WorkoutCard({
    required this.date,
    required this.duration,
    required this.completed,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: isDark ? const Color(0xFF1A1A2E) : primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                date,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white70 : primary.withValues(alpha: 0.8),
                ),
              ),
            ),
            Expanded(
              child: Icon(
                completed ? Icons.accessibility_new : Icons.hourglass_empty,
                size: 48,
                color: completed
                    ? primary.withValues(alpha: 0.85)
                    : Colors.grey,
              ),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white54 : primary.withValues(alpha: 0.7),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                duration,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
