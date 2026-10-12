import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../training/presentation/screens/weekly_routine_screen.dart';
import '../../../training/presentation/screens/exercise_library_screen.dart';
import '../../../training/presentation/screens/edit_routine_day_screen.dart';
import '../../../training/presentation/screens/workout_session_screen.dart';
import '../widgets/home_widgets.dart';
import '../widgets/routine_tab_widgets.dart';

class RoutineTab extends ConsumerStatefulWidget {
  const RoutineTab({super.key});

  @override
  ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  Future<void> _startWorkout(RoutineDay day) async {
    if (day.isRestDay) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este día es de descanso')),
      );
      return;
    }
    if (day.exercises.isEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(day.day),
          content: const Text(
            'Este día no tiene ejercicios.\n¿Quieres editarlo ahora?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Editar'),
            ),
          ],
        ),
      );
      if (go == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditRoutineDayScreen(day: day)),
        );
        ref.invalidate(routinesProvider);
      }
      return;
    }

    final sessionDate = WorkoutSession.dateOfWeekday(day.day);
    final user = ref.read(authServiceProvider).currentUser;
    WorkoutSession? existing;
    if (user != null) {
      // Solo reanuda si hay una sesión INCOMPLETA de esta misma rutina
      existing = await ref
          .read(profileRepositoryProvider)
          .findIncompleteSessionForRoutine(
        user.uid,
        dayName: day.day,
        title: day.title,
      );
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          routine: day,
          existing: existing,
          sessionDate: sessionDate,
        ),
      ),
    );
    ref.invalidate(todayWorkoutSessionProvider);
    ref.invalidate(activeWorkoutSessionProvider);
    ref.invalidate(workoutHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(routinesProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final todayName = WorkoutSession.weekdayName();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ─── Sesión en curso (mini player) ────────────────
        const ActiveSessionBanner(),
        const RestDayBanner(),
        // ═══ 1) RUTINA SEMANAL (arriba de todo) ═══════════
        Row(
          children: [
            Expanded(
              child: Text(
                'Tu rutina semanal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Editar semana',
              icon: Icon(Icons.edit, color: primary),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WeeklyRoutineScreen(),
                  ),
                ).then((_) => ref.invalidate(routinesProvider));
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 250,
          child: routinesAsync.when(
            loading: () => Center(child: CircularProgressIndicator(color: primary)),
            error: (e, _) => Text('Error: $e'),
            data: (routines) {
              if (routines.isEmpty) {
                return const Center(child: Text('No hay rutinas'));
              }
              // Empezar en el día de hoy si existe
              final todayIndex = routines.indexWhere((r) => r.day == todayName);
              return PageView.builder(
                controller: PageController(
                  viewportFraction: 0.88,
                  initialPage: todayIndex >= 0 ? todayIndex : 0,
                ),
                itemCount: routines.length,
                itemBuilder: (context, index) {
                  final r = routines[index];
                  final isToday = r.day == todayName;
                  return RoutineCard(
                    routine: r,
                    isToday: isToday,
                    onTap: () => _showDayPreview(context, ref, r),
                    onStart: r.isRestDay ? null : () => _startWorkout(r),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // ═══ 2) Agua (sync con Inicio) ════════════════
        const CompactWaterControl(),
        const SizedBox(height: 16),

        // ═══ 3) Biblioteca ════════════════════════════════
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(Icons.menu_book_outlined, color: primary),
            title: const Text(
              'Biblioteca de ejercicios',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Catálogo, favoritos y ejercicios propios'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExerciseLibraryScreen(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  void _showDayPreview(BuildContext context, WidgetRef ref, RoutineDay day) {
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
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day.day,
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              day.isRestDay ? 'Descanso' : day.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar día',
                        icon: Icon(Icons.edit, color: primary),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditRoutineDayScreen(day: day),
                            ),
                          );
                          ref.invalidate(routinesProvider);
                        },
                      ),
                    ],
                  ),
                ),
                if (!day.isRestDay)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        if (day.duration.isNotEmpty) ...[
                          Icon(Icons.schedule,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text(day.duration,
                              style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(width: 16),
                        ],
                        if (day.calories > 0) ...[
                          Icon(Icons.local_fire_department,
                              size: 16, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Text('${day.calories} kcal',
                              style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(width: 16),
                        ],
                        Icon(Icons.fitness_center,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '${day.exercises.length} ejercicios',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                Expanded(
                  child: day.isRestDay
                      ? const Center(
                    child: Text(
                      'Día de recuperación.\nToca el lápiz para cambiarlo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                      : day.exercises.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Sin ejercicios en este día.',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      EditRoutineDayScreen(day: day),
                                ),
                              );
                              ref.invalidate(routinesProvider);
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Agregar ejercicios'),
                            style: FilledButton.styleFrom(
                              backgroundColor: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: day.exercises.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = day.exercises[i];
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color:
                            Colors.grey.withValues(alpha: 0.25),
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                          primary.withValues(alpha: 0.15),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          e.exerciseName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${e.muscleGroup.isEmpty ? 'Ejercicio' : e.muscleGroup} · ${e.sets} × ${e.reps}',
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditRoutineDayScreen(day: day),
                            ),
                          );
                          ref.invalidate(routinesProvider);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar este día'),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

}

