import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../training/presentation/screens/workout_session_screen.dart';
import '../../../training/domain/rest_day_suggestion.dart';

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

        final strong = advice.level == 'strong';
        final bg = strong
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.blueGrey.withValues(alpha: 0.12);
        final fg = strong ? Colors.deepOrange : Colors.blueGrey;

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
                      foregroundColor: primary,
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
                    color: primary,
                  ),
                  onPressed: () => _togglePause(ref, session),
                ),
                IconButton(
                  tooltip: 'Cancelar',
                  icon: const Icon(Icons.close, color: Colors.redAccent),
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
