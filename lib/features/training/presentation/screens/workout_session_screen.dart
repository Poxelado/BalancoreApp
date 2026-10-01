import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  final RoutineDay routine;
  final WorkoutSession? existing;

  const WorkoutSessionScreen({
    super.key,
    required this.routine,
    this.existing,
  });

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  late WorkoutSession _session;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null && !widget.existing!.completed) {
      _session = widget.existing!;
    } else {
      _session = WorkoutSession.fromRoutine(widget.routine);
    }
  }

  Future<void> _persist() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    await ref.read(profileRepositoryProvider).saveWorkoutSession(
      user.uid,
      _session,
    );
    ref.invalidate(todayWorkoutSessionProvider);
  }

  Future<void> _updateSet({
    required int exerciseIndex,
    required int setIndex,
    double? weight,
    int? reps,
    bool? completed,
  }) async {
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final ex = exercises[exerciseIndex];
    final sets = List<WorkoutSetLog>.from(ex.sets);
    sets[setIndex] = sets[setIndex].copyWith(
      weight: weight,
      reps: reps,
      completed: completed,
    );
    exercises[exerciseIndex] = ex.copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
    await _persist();
  }

  Future<void> _addSet(int exerciseIndex) async {
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final ex = exercises[exerciseIndex];
    final sets = List<WorkoutSetLog>.from(ex.sets);
    final last = sets.isNotEmpty ? sets.last : null;
    sets.add(
      WorkoutSetLog(
        setNumber: sets.length + 1,
        weight: last?.weight ?? 0,
        reps: last?.reps ?? 10,
        completed: false,
      ),
    );
    exercises[exerciseIndex] = ex.copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
    await _persist();
  }

  Future<void> _finish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar entrenamiento'),
        content: Text(
          'Completaste ${_session.completedSets} de ${_session.totalSets} series.\n¿Finalizar sesión?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      _session = _session.copyWith(
        completed: true,
        finishedAt: DateTime.now(),
      );
      await _persist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Entrenamiento guardado!')),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final progress = _session.totalSets == 0
        ? 0.0
        : (_session.completedSets / _session.totalSets).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(_session.title.isEmpty ? 'Entrenamiento' : _session.title),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saving ? null : _finish,
            child: const Text(
              'Terminar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progreso
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _session.dayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_session.completedSets}/${_session.totalSets} series',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: primary.withValues(alpha: 0.15),
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _session.exercises.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Esta rutina no tiene ejercicios.\n'
                      'Configura el día en "Configurar semana" '
                      'o aplica una plantilla.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: _session.exercises.length,
              itemBuilder: (context, i) {
                final ex = _session.exercises[i];
                return _ExerciseCard(
                  exercise: ex,
                  index: i,
                  onToggleSet: (setIndex, completed) {
                    _updateSet(
                      exerciseIndex: i,
                      setIndex: setIndex,
                      completed: completed,
                    );
                  },
                  onEditSet: (setIndex) => _editSetDialog(i, setIndex),
                  onAddSet: () => _addSet(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editSetDialog(int exerciseIndex, int setIndex) async {
    final set = _session.exercises[exerciseIndex].sets[setIndex];
    final weightCtrl = TextEditingController(
      text: set.weight > 0 ? set.weight.toString() : '',
    );
    final repsCtrl = TextEditingController(text: '${set.reps}');
    final primary = Theme.of(context).colorScheme.primary;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Serie ${set.setNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Peso (kg)',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: repsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Repeticiones',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Guardar', style: TextStyle(color: primary)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _updateSet(
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
      weight: double.tryParse(weightCtrl.text.replaceAll(',', '.')) ?? 0,
      reps: int.tryParse(repsCtrl.text) ?? set.reps,
      completed: true,
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final WorkoutExerciseLog exercise;
  final int index;
  final void Function(int setIndex, bool completed) onToggleSet;
  final void Function(int setIndex) onEditSet;
  final VoidCallback onAddSet;

  const _ExerciseCard({
    required this.exercise,
    required this.index,
    required this.onToggleSet,
    required this.onEditSet,
    required this.onAddSet,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final done = exercise.completedSets;
    final total = exercise.sets.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: index == 0,
        title: Text(
          exercise.exerciseName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${exercise.muscleGroup.isEmpty ? 'Ejercicio' : exercise.muscleGroup} · $done/$total series',
          style: const TextStyle(fontSize: 12),
        ),
        children: [
          ...exercise.sets.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return ListTile(
              dense: true,
              leading: Checkbox(
                value: s.completed,
                activeColor: primary,
                onChanged: (v) => onToggleSet(i, v ?? false),
              ),
              title: Text(
                'Serie ${s.setNumber}',
                style: TextStyle(
                  decoration:
                  s.completed ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                s.weight > 0
                    ? '${s.weight} kg × ${s.reps} reps'
                    : '${s.reps} reps · sin peso',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => onEditSet(i),
              ),
              onTap: () => onEditSet(i),
            );
          }),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir serie'),
            ),
          ),
        ],
      ),
    );
  }
}
