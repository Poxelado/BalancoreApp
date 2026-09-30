import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
        const Text(
          'Hoy',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B1228)),
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
                              ? const Color(0xFF6B1228)
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

        // ─── Carrusel grande: Rutina semanal ──────────────
        const Text(
          'Tu rutina semanal',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF6B1228)),
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
                  return _RoutineCard(routine: r);
                },
              );
            },
          ),
        ),
      ],
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

  const _RoutineCard({required this.routine});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: routine.isRestDay
                ? [Colors.blueGrey.shade300, Colors.blueGrey.shade500]
                : [const Color(0xFF6B1228), const Color(0xFF9B2D4A)],
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
                routine.duration,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                '${routine.calories} kcal',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ] else
              const Text(
                'Día de recuperación',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
          ],
        ),
      ),
    );
  }
}