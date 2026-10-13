import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/preferences/units_provider.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'weight_history_screen.dart';
import 'edit_profile_screen.dart';
import '../widgets/profile_tab_widgets.dart';
import '../../../training/presentation/screens/edit_workout_history_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../training/presentation/screens/exercise_detail_screen.dart';
import '../../../../core/theme/app_theme.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  int _periodDays = 30;

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
                    child: Text(
                      '${_fmtDate(s.startedAt)} · ${_fmtDuration(s)}'
                          '${s.completed ? ' · completado' : ''}',
                      style: TextStyle(color: Colors.grey.shade600),
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
                      return ListTile(
                        title: Text(e.exerciseName),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Próximamente'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.schedule, size: 18),
                        label: const Text('Próximamente'),
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

            // Historial header + periodos
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
                    PeriodChip(
                      label: '1M',
                      selected: _periodDays == 30,
                      onTap: () => setState(() => _periodDays = 30),
                    ),
                    PeriodChip(
                      label: '3M',
                      selected: _periodDays == 90,
                      onTap: () => setState(() => _periodDays = 90),
                    ),
                    PeriodChip(
                      label: '6M',
                      selected: _periodDays == 180,
                      onTap: () => setState(() => _periodDays = 180),
                    ),
                    PeriodChip(
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
                      return WorkoutCard(
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



