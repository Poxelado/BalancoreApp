import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../widgets/exercise_list_widgets.dart';
import '../../domain/workout_calories.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/input_limits.dart';

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
    _sessionNotesCtrl = TextEditingController(text: _session.notes);
    _titleCtrl = TextEditingController(text: _session.title);
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

      final toSave = WorkoutSession(
        id: _session.id,
        dayName: _session.dayName,
        title: _titleCtrl.text.trim().isEmpty
            ? _session.title
            : _titleCtrl.text.trim(),
        startedAt: _session.startedAt,
        finishedAt: _session.finishedAt,
        completed: _session.completed,
        isPaused: _session.isPaused,
        elapsedSeconds: _session.elapsedSeconds,
        notes: _sessionNotesCtrl.text.trim(),
        exercises: _session.exercises,
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
    final ctrl = TextEditingController(text: ex.notes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notas · ${ex.exerciseName}'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          inputFormatters: InputFormatters.text(InputLimits.notesMax),
          decoration: const InputDecoration(
            hintText: 'Notas de este ejercicio...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
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
    var completed = s.completed;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Serie ${s.setNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: InputFormatters.decimal(maxLength: 6),
                decoration: const InputDecoration(labelText: 'Peso (kg)'),
              ),
              TextField(
                controller: rCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: InputFormatters.digits(maxLength: 3),
                decoration: const InputDecoration(labelText: 'Reps'),
              ),
              SwitchListTile(
                title: const Text('Completada'),
                value: completed,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setLocal(() => completed = v),
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
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final sets = List<WorkoutSetLog>.from(exercises[exIndex].sets);
    sets[setIndex] = s.copyWith(
      weight: double.tryParse(wCtrl.text.replaceAll(',', '.')) ?? 0,
      reps: int.tryParse(rCtrl.text) ?? s.reps,
      completed: completed,
    );
    exercises[exIndex] = exercises[exIndex].copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
  }

  @override
  Widget build(BuildContext context) {
    final weight = ref.watch(userProfileProvider).value?.currentWeight ?? 70;
    final kcal = estimateWorkoutCalories(_session, weightKg: weight);
    final met = estimateWorkoutMet(_session);
    final minutes = (_session.elapsedSeconds / 60).round();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar entrenamiento'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Text(
              'Guardar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            inputFormatters: InputFormatters.text(InputLimits.titleMax),
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sessionNotesCtrl,
            maxLines: 3,
            inputFormatters: InputFormatters.text(InputLimits.notesMax),
            decoration: const InputDecoration(
              labelText: 'Notas de la sesión',
              border: OutlineInputBorder(),
              hintText: 'Cómo te sentiste, etc.',
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppDataColors.calories.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppDataColors.calories.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0x22FF9800),
                  child: Icon(
                    Icons.local_fire_department,
                    color: AppDataColors.calories,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gasto estimado',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppDataColors.calories,
                        ),
                      ),
                      Text(
                        '≈ $kcal kcal',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'MET ${met.toStringAsFixed(1)} · $minutes min · '
                        '${weight.round()} kg',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ejercicios',
            style: TextStyle(fontWeight: FontWeight.bold, color: accentOf(context)),
          ),
          const SizedBox(height: 8),
          ..._session.exercises.asMap().entries.map((entry) {
            final i = entry.key;
            final e = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                leading: ExerciseThumb(exerciseId: e.exerciseId, size: 40),
                title: Text(
                  e.exerciseName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  e.notes.isEmpty
                      ? '${e.completedSets}/${e.sets.length} series'
                      : '📝 ${e.notes}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: 'Notas del ejercicio',
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
                        'Serie ${s.setNumber}: ${s.weight} kg × ${s.reps}',
                      ),
                      trailing: Icon(
                        s.completed
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: s.completed ? AppSemanticColors.of(context).success : Colors.grey,
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
