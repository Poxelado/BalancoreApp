import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../training/presentation/screens/workout_session_screen.dart';
import '../../../training/presentation/widgets/exercise_list_widgets.dart';
import '../../../training/domain/rest_day_suggestion.dart';
import '../../../../core/theme/app_theme.dart';

class RestDayBanner extends ConsumerWidget {
  const RestDayBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(workoutHistoryProvider(14));
    return historyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (history) {
        final advice = RestDayRules.evaluate(history);
        if (!advice.suggestRest) return const SizedBox.shrink();

        final sem = AppSemanticColors.of(context);
        final strong = advice.level == 'strong';
        final tone = strong ? sem.warning : sem.rest;
        final bg = tone.withValues(alpha: 0.15);
        final fg = tone;

        return Card(
          color: bg,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              strong ? Icons.hotel : Icons.self_improvement,
              color: fg,
            ),
            title: Text(
              strong ? 'Sugerencia: descanso' : 'Recuperación recomendada',
              style: TextStyle(fontWeight: FontWeight.bold, color: fg),
            ),
            subtitle: Text(advice.message),
          ),
        );
      },
    );
  }
}

class RoutineCard extends StatelessWidget {
  final RoutineDay routine;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final bool isToday;

  const RoutineCard({super.key,
    required this.routine,
    this.onTap,
    this.onStart,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isToday
            ? BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: routine.isRestDay
                  ? [Colors.blueGrey.shade400, Colors.blueGrey.shade600]
                  : [primary, primary],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    routine.day,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'HOY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.touch_app,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                routine.isRestDay ? 'Descanso' : routine.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!routine.isRestDay) ...[
                Text(
                  routine.duration.isEmpty
                      ? '${routine.exercises.length} ejercicios'
                      : '${routine.duration} · ${routine.exercises.length} ej.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: accentOf(context),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text(
                      'Empezar entrenamiento',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else
                const Text(
                  'Día de recuperación',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Tarjeta de una rutina guardada (extra) que se puede contraer para no
/// ocupar espacio: al tocar el encabezado se muestran sus entrenamientos y,
/// dentro de cada uno, sus ejercicios.
class CustomRoutineCard extends StatefulWidget {
  final CustomRoutine routine;
  final void Function(CustomWorkout workout) onStartWorkout;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CustomRoutineCard({
    super.key,
    required this.routine,
    required this.onStartWorkout,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<CustomRoutineCard> createState() => _CustomRoutineCardState();
}

class _CustomRoutineCardState extends State<CustomRoutineCard> {
  bool _expanded = false;
  final Set<int> _expandedWorkouts = {};

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final routine = widget.routine;
    final nWorkouts = routine.workoutCount;
    final nExercises = routine.exerciseCount;
    final duration = routine.estimatedDuration;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
              child: Row(
                children: [
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: accentOf(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          nWorkouts == 0
                              ? 'Sin entrenamientos'
                              : '$nWorkouts entrenamiento'
                                  '${nWorkouts == 1 ? '' : 's'} · '
                                  '$nExercises ejercicios'
                                  '${duration.isEmpty ? '' : ' · $duration'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 4),
                  if (routine.workouts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Sin entrenamientos todavía',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    for (var i = 0; i < routine.workouts.length; i++)
                      _workoutTile(primary, i, routine.workouts[i]),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Editar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: widget.onDelete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Icon(Icons.delete_outline, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _workoutTile(Color primary, int index, CustomWorkout workout) {
    final open = _expandedWorkouts.contains(index);
    final n = workout.exercises.length;
    final duration = workout.estimatedDuration;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() {
                      if (open) {
                        _expandedWorkouts.remove(index);
                      } else {
                        _expandedWorkouts.add(index);
                      }
                    }),
                    child: Row(
                      children: [
                        Icon(
                          open ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                workout.name.isEmpty
                                    ? 'Entrenamiento ${index + 1}'
                                    : workout.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                n == 0
                                    ? 'Sin ejercicios'
                                    : '$n ejercicios'
                                        '${duration.isEmpty ? '' : ' · $duration'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Empezar',
                  icon: Icon(Icons.play_arrow, color: accentOf(context)),
                  onPressed: () => widget.onStartWorkout(workout),
                ),
              ],
            ),
          ),
          if (open && workout.exercises.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                children: [
                  for (final e in workout.exercises)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          ExerciseThumb(exerciseId: e.exerciseId, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.exerciseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${e.sets} × ${e.reps}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


class ActiveSessionBanner extends ConsumerWidget {
  const ActiveSessionBanner({super.key});

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _resume(BuildContext context, WidgetRef ref, WorkoutSession session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          existing: session,
          allowAddExercises: true,
        ),
      ),
    );
    ref.invalidate(activeWorkoutSessionProvider);
    ref.invalidate(routinesProvider);
  }

  Future<void> _togglePause(
      WidgetRef ref, WorkoutSession session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    final updated = session.copyWith(isPaused: !session.isPaused);
    await ref.read(profileRepositoryProvider).saveWorkoutSession(user.uid, updated);
    ref.invalidate(activeWorkoutSessionProvider);
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, WorkoutSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar entrenamiento'),
        content: const Text(
          'Se eliminará esta sesión en curso. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    await ref
        .read(profileRepositoryProvider)
        .deleteWorkoutSession(user.uid, session.id);
    ref.invalidate(activeWorkoutSessionProvider);
    for (final d in [30, 90, 180, 365]) {
      ref.invalidate(workoutHistoryProvider(d));
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión cancelada')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeWorkoutSessionProvider);
    final session = async.valueOrNull;
    if (session == null || session.completed) {
      return const SizedBox.shrink();
    }
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _resume(context, ref, session),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: primary,
                  child: Icon(
                    session.isPaused ? Icons.pause : Icons.fitness_center,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.isPaused
                            ? 'Sesión en pausa'
                            : 'Entrenamiento en curso',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${session.title.isEmpty ? session.dayName : session.title}'
                            ' · ${_fmt(session.elapsedSeconds)}'
                            ' · ${session.completedSets}/${session.totalSets} series',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Text(
                        'Toca para volver',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: session.isPaused ? 'Reanudar' : 'Pausar',
                  icon: Icon(
                    session.isPaused ? Icons.play_arrow : Icons.pause,
                    color: accentOf(context),
                  ),
                  onPressed: () => _togglePause(ref, session),
                ),
                IconButton(
                  tooltip: 'Cancelar',
                  icon: Icon(Icons.close,
                      color: Theme.of(context).colorScheme.error),
                  onPressed: () => _cancel(context, ref, session),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
