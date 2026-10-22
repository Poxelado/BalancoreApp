import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../training/domain/exercise.dart';
import '../../../training/domain/workout_share_metrics.dart';
import '../../../training/presentation/widgets/muscle_body_map.dart';
import '../../../training/presentation/screens/weekly_routine_screen.dart';
import '../../../training/presentation/screens/exercise_library_screen.dart';
import '../../../training/presentation/screens/edit_routine_day_screen.dart';
import '../../../training/presentation/screens/edit_custom_routine_screen.dart';
import '../../../training/presentation/screens/explore_routines_screen.dart';
import '../../../training/presentation/screens/pick_exercise_screen.dart';
import '../../../training/presentation/screens/workout_session_screen.dart';
import '../../../training/presentation/providers/exercise_provider.dart';
import '../../../training/presentation/workout_builders.dart';
import '../../../training/presentation/widgets/exercise_list_widgets.dart';
import '../widgets/home_widgets.dart';
import '../widgets/routine_tab_widgets.dart';
import '../../../../core/theme/app_theme.dart';

class RoutineTab extends ConsumerStatefulWidget {
  const RoutineTab({super.key});

  @override
  ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  /// Evita abrir varias sesiones si se toca "empezar" dos veces seguidas
  /// (p. ej. cuando no hay conexión y el toque tarda en responder).
  bool _starting = false;

  /// Carrusel de días: el controlador vive en el State para no perder el día
  /// seleccionado cuando el widget se reconstruye (p. ej. al invalidar rutinas).
  PageController? _routinePageController;
  int _routinePageIndex = 0;

  @override
  void initState() {
    super.initState();
    // Prefetch del catálogo para que byId/plantillas resuelvan aunque el
    // usuario no pase primero por la Biblioteca.
    ref.read(exerciseRepositoryProvider).loadCatalog();
  }

  @override
  void dispose() {
    _routinePageController?.dispose();
    super.dispose();
  }

  Future<void> _startWorkout(RoutineDay day) async {
    if (_starting) return;
    _starting = true;
    try {
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
    } finally {
      _starting = false;
    }
  }

  /// Entrenamiento libre: pregunta si empezar vacío o eligiendo ejercicios.
  Future<void> _startFreeWorkout() async {
    if (_starting) return;
    _starting = true;
    try {
      final primary = Theme.of(context).colorScheme.primary;
      final choice = await showModalBottomSheet<String>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  'Entrenamiento libre',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: accentOf(context),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Elige cómo quieres empezar tu sesión.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.12),
                  child:
                      Icon(Icons.play_circle_outline, color: accentOf(context)),
                ),
                title: const Text('Empezar vacío'),
                subtitle: const Text(
                  'Arranca sin ejercicios y añádelos a medida que entrenas.',
                ),
                onTap: () => Navigator.pop(ctx, 'empty'),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.12),
                  child: Icon(Icons.checklist_rtl, color: accentOf(context)),
                ),
                title: const Text('Elegir ejercicios antes de empezar'),
                subtitle: const Text(
                  'Selecciona los ejercicios ahora y la sesión arranca con ellos.',
                ),
                onTap: () => Navigator.pop(ctx, 'pick'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (choice == null || !mounted) return;

      if (choice == 'empty') {
        await _pushFreeSession(initialExercises: const []);
        return;
      }

      final picked = await Navigator.push<List<Exercise>>(
        context,
        MaterialPageRoute(builder: (_) => const PickExerciseScreen()),
      );
      if (picked == null || picked.isEmpty || !mounted) return;

      final user = ref.read(authServiceProvider).currentUser;
      final repo = ref.read(profileRepositoryProvider);
      final logs = <WorkoutExerciseLog>[];
      for (final exercise in picked) {
        logs.add(
          await buildWorkoutExerciseLog(
            repo: repo,
            exercise: exercise,
            uid: user?.uid,
          ),
        );
      }
      if (!mounted) return;
      await _pushFreeSession(initialExercises: logs);
    } finally {
      _starting = false;
    }
  }

  Future<void> _pushFreeSession({
    required List<WorkoutExerciseLog> initialExercises,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          initialExercises: initialExercises,
          title: 'Entrenamiento libre',
          allowAddExercises: true,
        ),
      ),
    );
    ref.invalidate(todayWorkoutSessionProvider);
    ref.invalidate(activeWorkoutSessionProvider);
    ref.invalidate(workoutHistoryProvider);
  }

  Future<void> _startCustomWorkout(
    CustomRoutine routine,
    CustomWorkout workout,
  ) async {
    if (_starting) return;
    _starting = true;
    try {
      if (workout.exercises.isEmpty) {
        final edit = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(workout.name.isEmpty ? routine.name : workout.name),
            content: const Text(
              'Este entrenamiento todavía no tiene ejercicios.\n¿Quieres editarlo ahora?',
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
        if (edit == true && mounted) {
          await _editCustomRoutine(routine);
        }
        return;
      }

      final title = workout.name.isEmpty ? routine.name : workout.name;
      final day = RoutineDay(
        day: WorkoutSession.weekdayName(),
        title: title,
        exercises: workout.exercises,
      );
      final user = ref.read(authServiceProvider).currentUser;
      WorkoutSession? existing;
      if (user != null) {
        existing = await ref
            .read(profileRepositoryProvider)
            .findIncompleteSessionForRoutine(
          user.uid,
          dayName: day.day,
          title: title,
        );
      }
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSessionScreen(
            routine: day,
            existing: existing,
            allowAddExercises: true,
          ),
        ),
      );
      ref.invalidate(todayWorkoutSessionProvider);
      ref.invalidate(activeWorkoutSessionProvider);
      ref.invalidate(workoutHistoryProvider);
    } finally {
      _starting = false;
    }
  }

  Future<void> _createCustomRoutine() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditCustomRoutineScreen(),
      ),
    );
    ref.invalidate(customRoutinesProvider);
  }

  Future<void> _exploreRoutines() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ExploreRoutinesScreen(),
      ),
    );
    ref.invalidate(customRoutinesProvider);
  }

  Future<void> _editCustomRoutine(CustomRoutine routine) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditCustomRoutineScreen(routine: routine),
      ),
    );
    ref.invalidate(customRoutinesProvider);
  }

  Future<void> _deleteCustomRoutine(CustomRoutine routine) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar rutina'),
        content: Text(
          '¿Eliminar "${routine.name}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    await ref
        .read(profileRepositoryProvider)
        .deleteCustomRoutine(user.uid, routine.id);
    ref.invalidate(customRoutinesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rutina eliminada')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(routinesProvider);
    final customRoutinesAsync = ref.watch(customRoutinesProvider);
    final todayName = WorkoutSession.weekdayName();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ─── Entrenamiento libre (acceso rápido) ──
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _startFreeWorkout,
            icon: const Icon(Icons.bolt, size: 22),
            label: const Text(
              'Entrenamiento libre',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ─── Sesión en curso: ahora es el mini player flotante del shell ────
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
                  color: accentOf(context),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Editar semana',
              icon: Icon(Icons.edit, color: accentOf(context)),
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
            loading: () => Center(child: CircularProgressIndicator(color: accentOf(context))),
            error: (e, _) => Text('Error: $e'),
            data: (routines) {
              if (routines.isEmpty) {
                return const Center(child: Text('No hay rutinas'));
              }
              // Empezar en el día de hoy si existe, pero respetando el día
              // que el usuario ya tenía seleccionado.
              final todayIndex = routines.indexWhere((r) => r.day == todayName);
              final initial = todayIndex >= 0 ? todayIndex : 0;
              if (_routinePageController == null ||
                  _routinePageIndex >= routines.length) {
                // Mantiene el mismo día si sigue existiendo.
                _routinePageController?.dispose();
                _routinePageController = PageController(
                  viewportFraction: 0.88,
                  initialPage: initial,
                );
                _routinePageIndex = initial;
              }
              return PageView.builder(
                controller: _routinePageController,
                onPageChanged: (i) => _routinePageIndex = i,
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

        // ═══ 2) Rutinas (extras reutilizables) ═══════════
        Text(
          'Rutinas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: accentOf(context),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _createCustomRoutine,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const FittedBox(
                  child: Text('Crear nueva rutina'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _exploreRoutines,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const FittedBox(child: Text('Explorar')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        customRoutinesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e'),
          data: (routines) {
            if (routines.isEmpty) {
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Aún no tienes rutinas. Crea una o explora rutinas listas '
                    'para reutilizarlas cuando quieras, sin ocupar un día de '
                    'la semana.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final r in routines)
                  CustomRoutineCard(
                    routine: r,
                    onStartWorkout: (w) => _startCustomWorkout(r, w),
                    onEdit: () => _editCustomRoutine(r),
                    onDelete: () => _deleteCustomRoutine(r),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // ═══ 2) Agua (sync con Inicio) ════════════════
        const CompactWaterControl(),
        const SizedBox(height: 16),

        // ═══ 3) Biblioteca ════════════════════════════════
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(Icons.menu_book_outlined, color: accentOf(context)),
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
                                color: accentOf(context),
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
                        icon: Icon(Icons.edit, color: accentOf(context)),
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
                if (!day.isRestDay && day.exercises.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _RoutineSummary(day: day, primary: primary),
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
                        leading: SizedBox(
                          width: 46,
                          height: 46,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ExerciseThumb(
                                exerciseId: e.exerciseId,
                                size: 46,
                              ),
                              Positioned(
                                left: -4,
                                top: -4,
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundColor: primary,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

/// Resumen de la vista previa de un día: la figura con los músculos que se
/// trabajarán, junto a duración, calorías y número de ejercicios.
class _RoutineSummary extends StatelessWidget {
  final RoutineDay day;
  final Color primary;

  const _RoutineSummary({required this.day, required this.primary});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final intensity = buildRoutineIntensity(day);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.4)
            : primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (intensity.isNotEmpty) ...[
            _RoutineBody(
              intensity: intensity,
              front: true,
              primary: primary,
              isDark: isDark,
            ),
            const SizedBox(width: 6),
            _RoutineBody(
              intensity: intensity,
              front: false,
              primary: primary,
              isDark: isDark,
            ),
            Container(
              width: 1,
              height: 76,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          ],
          Expanded(
            child: Column(
              children: [
                if (day.duration.isNotEmpty)
                  _SummaryRow(
                    icon: Icons.schedule,
                    label: 'Duración',
                    value: day.duration,
                  ),
                if (day.calories > 0)
                  _SummaryRow(
                    icon: Icons.local_fire_department,
                    label: 'Calorías',
                    value: '${day.calories} kcal',
                  ),
                _SummaryRow(
                  icon: Icons.fitness_center,
                  label: 'Ejercicios',
                  value: '${day.exercises.length}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Figura muscular pequeña (frontal o trasera) de la vista previa.
class _RoutineBody extends StatelessWidget {
  final Map<BodyRegion, double> intensity;
  final bool front;
  final Color primary;
  final bool isDark;

  const _RoutineBody({
    required this.intensity,
    required this.front,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 92,
      child: MuscleBodyMap(
        intensity: intensity,
        front: front,
        base: isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.06),
        trained: primary,
        outline: isDark
            ? Colors.white.withValues(alpha: 0.30)
            : primary.withValues(alpha: 0.22),
      ),
    );
  }
}

/// Fila etiqueta/valor del resumen de la vista previa.
class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

