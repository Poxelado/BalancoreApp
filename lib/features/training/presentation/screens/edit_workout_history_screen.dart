import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// Editar una sesión ya guardada (historial).
class EditWorkoutHistoryScreen extends ConsumerStatefulWidget {
  final WorkoutSession session;

  const EditWorkoutHistoryScreen({super.key, required this.session});

  @override
  ConsumerState<EditWorkoutHistoryScreen> createState() =>
      _EditWorkoutHistoryScreenState();
}

class _EditWorkoutHistoryScreenState
    extends ConsumerState<EditWorkoutHistoryScreen> {
  late WorkoutSession _session;
  late TextEditingController _sessionNotesCtrl;
  late TextEditingController _titleCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _sessionNotesCtrl = TextEditingController(text: _session.notes ?? '');
    _titleCtrl = TextEditingController(text: _session.title ?? '');
  }

  @override
  void dispose() {
    _sessionNotesCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;
      final updated = _session.copyWith(
        notes: _sessionNotesCtrl.text.trim(),
      );
      // title is final on session - need to rebuild if we want to change title
      // WorkoutSession title is final - use toMap workaround via new session
      final toSave = WorkoutSession(
        id: updated.id,
        dayName: updated.dayName,
        title: _titleCtrl.text.trim().isEmpty
            ? updated.title
            : _titleCtrl.text.trim(),
        startedAt: updated.startedAt,
        finishedAt: updated.finishedAt,
        completed: updated.completed,
        isPaused: updated.isPaused,
        elapsedSeconds: updated.elapsedSeconds,
        notes: updated.notes,
        exercises: updated.exercises,
      );
      await ref
          .read(profileRepositoryProvider)
          .saveWorkoutSession(user.uid, toSave);
      for (final d in [30, 90, 180, 365]) {
        ref.invalidate(workoutHistoryProvider(d));
      }
      ref.invalidate(activeWorkoutSessionProvider);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editExerciseNotes(int index) async {
    final ex = _session.exercises[index];
    final ctrl = TextEditingController(text: ex.notes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notas · ${ex.exerciseName}'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Notas de este ejercicio...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    final list = List<WorkoutExerciseLog>.from(_session.exercises);
    list[index] = ex.copyWith(notes: ctrl.text.trim());
    setState(() => _session = _session.copyWith(exercises: list));
  }

  Future<void> _editSet(int exIndex, int setIndex) async {
    final s = _session.exercises[exIndex].sets[setIndex];
    final wCtrl = TextEditingController(
      text: s.weight > 0 ? '${s.weight}' : '',
    );
    final rCtrl = TextEditingController(text: '${s.reps}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Serie ${s.setNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wCtrl,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Peso (kg)'),
            ),
            TextField(
              controller: rCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
            ),
            SwitchListTile(
              title: const Text('Completada'),
              value: s.completed,
              onChanged: null, // set via checkbox in dialog differently
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK')),
        ],
      ),
    );
    if (ok != true) return;
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final sets = List<WorkoutSetLog>.from(exercises[exIndex].sets);
    sets[setIndex] = s.copyWith(
      weight: double.tryParse(wCtrl.text.replaceAll(',', '.')) ?? 0,
      reps: int.tryParse(rCtrl.text) ?? s.reps,
    );
    exercises[exIndex] = exercises[exIndex].copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar entrenamiento'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
                : const Text('Guardar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sessionNotesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notas de la sesión',
              border: OutlineInputBorder(),
              hintText: 'Cómo te sentiste, etc.',
            ),
          ),
          const SizedBox(height: 20),
          Text('Ejercicios',
              style: TextStyle(fontWeight: FontWeight.bold, color: primary)),
          const SizedBox(height: 8),
          ..._session.exercises.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                title: Text(e.exerciseName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                  e.notes.isEmpty
                      ? '${e.completedSets}/${e.sets.length} series'
                      : '📝 ${e.notes}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.notes),
                  onPressed: () => _editExerciseNotes(i),
                ),
                children: [
                  ...e.sets.asMap().entries.map((se) {
                    final si = se.key;
                    final s = se.value;
                    return ListTile(
                      dense: true,
                      title: Text(
                          'Serie ${s.setNumber}: ${s.weight} kg × ${s.reps}'),
                      trailing: Icon(
                        s.completed
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: s.completed ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                      onTap: () => _editSet(i, si),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
