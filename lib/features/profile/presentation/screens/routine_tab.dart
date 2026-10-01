import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../training/presentation/screens/weekly_routine_screen.dart';
import '../../../training/presentation/screens/exercise_library_screen.dart';
import '../../../training/presentation/screens/edit_routine_day_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final logAsync = ref.watch(todayLogProvider);
    final routinesAsync = ref.watch(routinesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ─── Carrusel pequeño: Agua / Sueño ───────────────
        Text(
          'Hoy',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
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
                          value: '${log.sleepHours.toStringAsFixed(1)} / 8 hrs',
                          onMinus: log.sleepHours >= 0.5
                              ? () => _updateSleep(log.sleepHours - 0.5)
                              : null,
                          onPlus: log.sleepHours < 24
                              ? () => _updateSleep(log.sleepHours + 0.5)
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(2, (i) {
                      return Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _habitsPage == i
                              ? Theme.of(context).colorScheme.primary
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


        // ─── Accesos entrenamiento ────────────────────────
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.calendar_view_week,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Configurar semana',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Plantillas y ejercicios por día'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WeeklyRoutineScreen(),
                    ),
                  ).then((_) => ref.invalidate(routinesProvider));
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.menu_book_outlined,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Biblioteca de ejercicios',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Catálogo y favoritos'),
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
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ─── Carrusel grande: Rutina semanal ──────────────
        Text(
          'Tu rutina semanal',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: routinesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (routines) {
              if (routines.isEmpty) {
                return const Center(child: Text('No hay rutinas'));
              }
              return PageView.builder(
                controller: PageController(viewportFraction: 0.85),
                itemCount: routines.length,
                itemBuilder: (context, index) {
                  final r = routines[index];
                  return _RoutineCard(
                    routine: r,
                    onTap: () => _showDayPreview(context, ref, r),
                  );
                },
              );
            },
          ),
        ),
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

  const _RoutineCard({required this.routine, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: routine.isRestDay
                  ? [Colors.blueGrey.shade300, Colors.blueGrey.shade500]
                  : [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                routine.day,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                routine.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (!routine.isRestDay) ...[
                Text(
                  routine.duration.isEmpty
                      ? '${routine.exercises.length} ejercicios'
                      : '${routine.duration} · ${routine.exercises.length} ej.',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                if (routine.calories > 0)
                  Text(
                    '${routine.calories} kcal est.',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
              ] else
                const Text(
                  'Día de recuperación',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              Align(
                alignment: Alignment.bottomRight,
                child: Icon(
                  Icons.touch_app,
                  color: Colors.white.withValues(alpha: 0.7),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
