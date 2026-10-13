import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/routine_templates.dart';
import '../providers/exercise_provider.dart';
import 'routine_generator_screen.dart';
import '../../../../core/theme/app_theme.dart';

/// Una rutina lista para usar, derivada de las plantillas de la app.
class _ReadyRoutine {
  final String name;
  final String description;
  final List<CustomWorkout> workouts;

  const _ReadyRoutine({
    required this.name,
    required this.description,
    required this.workouts,
  });
}

/// Pantalla "Explorar": biblioteca de rutinas predefinidas que se agregan a
/// "Tus rutinas", más un acceso al asistente de rutina.
class ExploreRoutinesScreen extends ConsumerStatefulWidget {
  const ExploreRoutinesScreen({super.key});

  @override
  ConsumerState<ExploreRoutinesScreen> createState() =>
      _ExploreRoutinesScreenState();
}

class _ExploreRoutinesScreenState
    extends ConsumerState<ExploreRoutinesScreen> {
  @override
  void initState() {
    super.initState();
    // Prefetch para resolver nombres/grupos de las plantillas.
    ref.read(exerciseRepositoryProvider).loadCatalog();
  }

  List<_ReadyRoutine> _buildReady() {
    final out = <_ReadyRoutine>[];
    for (final t in RoutineTemplates.all) {
      final workouts = <CustomWorkout>[
        for (final d in t.week)
          if (!d.isRestDay && d.exercises.isNotEmpty)
            CustomWorkout(name: d.title, exercises: d.exercises),
      ];
      if (workouts.isEmpty) continue;
      out.add(
        _ReadyRoutine(
          name: t.name,
          description:
              '${workouts.length} entrenamientos · ${t.description}',
          workouts: workouts,
        ),
      );
    }
    return out;
  }

  Future<void> _useAssistant() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoutineGeneratorScreen()),
    );
    ref.invalidate(routinesProvider);
    ref.invalidate(customRoutinesProvider);
  }

  Future<void> _addRoutine(_ReadyRoutine r) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    final routine = CustomRoutine(
      id: '',
      name: r.name,
      workouts: r.workouts,
      createdAt: DateTime.now(),
    );
    await ref.read(profileRepositoryProvider).saveCustomRoutine(user.uid, routine);
    ref.invalidate(customRoutinesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${r.name}" agregada a tus rutinas')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final existing = ref.watch(customRoutinesProvider).valueOrNull ??
        const <CustomRoutine>[];
    final existingNames = existing.map((e) => e.name.toLowerCase()).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar rutinas'),
      ),
      body: ref.watch(exercisesProvider).when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: accentOf(context))),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (_) {
              final ready = _buildReady();
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.auto_awesome, color: accentOf(context)),
                      title: const Text(
                        'Crear con el asistente',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Genera una rutina según tu objetivo, nivel y días',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _useAssistant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Rutinas listas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: accentOf(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Agrega una a tus rutinas para reutilizarla cuando quieras.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  for (final r in ready)
                    _readyTile(
                      primary: primary,
                      r: r,
                      added: existingNames.contains(r.name.toLowerCase()),
                    ),
                ],
              );
            },
          ),
    );
  }

  Widget _readyTile({
    required Color primary,
    required _ReadyRoutine r,
    required bool added,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: primary.withValues(alpha: 0.12),
              child: Icon(Icons.fitness_center, color: accentOf(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    r.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (added)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Agregada',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              FilledButton.tonal(
                onPressed: () => _addRoutine(r),
                child: const Text('Agregar'),
              ),
          ],
        ),
      ),
    );
  }
}
