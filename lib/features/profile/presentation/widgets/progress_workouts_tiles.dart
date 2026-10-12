import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../training/presentation/screens/workout_session_screen.dart';
import '../../../training/presentation/screens/edit_workout_history_screen.dart';

/// Reconstruye una rutina efímera a partir de una sesión guardada,
/// para poder reabrirla en la pantalla de entrenamiento.
RoutineDay routineFromSession(WorkoutSession s) {
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

String fmtDayDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Cabecera de la sección de entrenamientos: título y selector de rango.
class WorkoutRangeHeader extends StatelessWidget {
  final String title;
  final String periodLabel;
  final Color primary;
  final Color cardBg;
  final VoidCallback onPickPeriod;

  const WorkoutRangeHeader({
    super.key,
    required this.title,
    required this.periodLabel,
    required this.primary,
    required this.cardBg,
    required this.onPickPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
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
            onTap: onPickPeriod,
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
                    periodLabel,
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
    );
  }
}

/// Grupo de sesiones (semana/mes) con su lista de entrenamientos.
class WorkoutSessionGroupTile extends ConsumerWidget {
  final String title;
  final List<WorkoutSession> group;
  final Color primary;
  final Color cardBg;
  final int periodDays;
  final bool initiallyExpanded;

  const WorkoutSessionGroupTile({
    super.key,
    required this.title,
    required this.group,
    required this.primary,
    required this.cardBg,
    required this.periodDays,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 2,
            ),
            title: Text(
              title,
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
                      s.completed ? Icons.check : Icons.fitness_center,
                      color: s.completed ? Colors.green : primary,
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
                    '${s.dayName} · ${fmtDayDate(s.startedAt)} · '
                        '${s.completed ? 'Completado' : 'En curso'} · '
                        '${s.exercises.fold<int>(0, (a, e) => a + e.completedSets)}/${s.exercises.fold<int>(0, (a, e) => a + e.sets.length)} series',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      final user = ref.read(authServiceProvider).currentUser;
                      if (user == null) return;
                      if (v == 'open') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkoutSessionScreen(
                              routine: routineFromSession(s),
                              existing: s.completed ? null : s,
                            ),
                          ),
                        );
                        ref.invalidate(workoutHistoryProvider(periodDays));
                      } else if (v == 'edit') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditWorkoutHistoryScreen(
                              session: s,
                            ),
                          ),
                        );
                        ref.invalidate(workoutHistoryProvider(periodDays));
                      } else if (v == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar sesión'),
                            content: const Text(
                              '¿Borrar este entrenamiento?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref
                              .read(profileRepositoryProvider)
                              .deleteWorkoutSession(user.uid, s.id);
                          ref.invalidate(workoutHistoryProvider(periodDays));
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
                          routine: routineFromSession(s),
                          existing: s.completed ? null : s,
                        ),
                      ),
                    );
                    ref.invalidate(workoutHistoryProvider(periodDays));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
