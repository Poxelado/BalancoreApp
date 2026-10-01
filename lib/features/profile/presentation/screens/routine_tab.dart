import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../training/presentation/screens/weekly_routine_screen.dart';
import '../../../training/presentation/screens/exercise_library_screen.dart';
import '../../../training/presentation/screens/edit_routine_day_screen.dart';
import '../../../training/presentation/screens/workout_session_screen.dart';

class RoutineTab extends ConsumerStatefulWidget {
  const RoutineTab({super.key});

  @override
  ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  final PageController _habitsController = PageController();
  int _habitsPage = 0;

  @override
  void dispose() {
    _habitsController.dispose();
    super.dispose();
  }

  Future<void> _updateWater(int value) async {
    final uid = ref.read(authServiceProvider).currentUser!.uid;
    await ref.read(profileRepositoryProvider).updateTodayLog(uid, waterGlasses: value);
    ref.invalidate(todayLogProvider);
  }

  Future<void> _updateSleep(double value) async {
    final uid = ref.read(authServiceProvider).currentUser!.uid;
    await ref.read(profileRepositoryProvider).updateTodayLog(uid, sleepHours: value);
    ref.invalidate(todayLogProvider);
  }

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
    final key = WorkoutSession.dateKey(sessionDate);
    final user = ref.read(authServiceProvider).currentUser;
    WorkoutSession? existing;
    if (user != null) {
      existing = await ref
          .read(profileRepositoryProvider)
          .getWorkoutSession(user.uid, key);
      if (existing != null && existing.completed) {
        existing = null; // nueva sesión si ya terminó
      }
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
  }

  @override
  Widget build(BuildContext context) {
    final logAsync = ref.watch(todayLogProvider);
    final routinesAsync = ref.watch(routinesProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final todayName = WorkoutSession.weekdayName();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
                  return _RoutineCard(
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

        // ═══ 2) Agua / Sueño ══════════════════════════════
        Text(
          'Hoy',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: logAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (log) {
              return Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: _habitsController,
                      onPageChanged: (i) => setState(() => _habitsPage = i),
                      children: [
                        _HabitCard(
                          icon: Icons.water_drop,
                          iconColor: Colors.blue,
                          title: 'Agua',
                          value: '${log.waterGlasses} / 8 vasos',
                          onMinus: log.waterGlasses > 0
                              ? () => _updateWater(log.waterGlasses - 1)
                              : null,
                          onPlus: log.waterGlasses < 20
                              ? () => _updateWater(log.waterGlasses + 1)
                              : null,
                        ),
                        _HabitCard(
                          icon: Icons.bedtime,
                          iconColor: Colors.indigo,
                          title: 'Sueño',
                          value: '${log.sleepHours.toStringAsFixed(1)} h',
                          onMinus: log.sleepHours > 0
                              ? () => _updateSleep(
                            (log.sleepHours - 0.5).clamp(0, 24),
                          )
                              : null,
                          onPlus: log.sleepHours < 16
                              ? () => _updateSleep(
                            (log.sleepHours + 0.5).clamp(0, 24),
                          )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(2, (i) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _habitsPage
                              ? primary
                              : Colors.grey.shade300,
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),

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

class _HabitCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _HabitCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.onMinus,
    this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            IconButton(
              onPressed: onMinus,
              icon: Icon(Icons.remove_circle, color: onMinus != null ? iconColor : Colors.grey.shade300),
            ),
            IconButton(
              onPressed: onPlus,
              icon: Icon(Icons.add_circle, color: onPlus != null ? iconColor : Colors.grey.shade300, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  final RoutineDay routine;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final bool isToday;

  const _RoutineCard({
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
