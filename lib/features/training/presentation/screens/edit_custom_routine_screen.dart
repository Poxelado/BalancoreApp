import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/exercise.dart';
import 'exercise_detail_screen.dart';
import 'pick_exercise_screen.dart';
import '../widgets/exercise_list_widgets.dart';
import '../widgets/routine_day_widgets.dart';

/// Crea o edita una rutina extra (además de la rutina semanal).
/// Una rutina agrupa varios entrenamientos y cada uno sus ejercicios.
/// Si [routine] es null, es una rutina nueva.
class EditCustomRoutineScreen extends ConsumerStatefulWidget {
  final CustomRoutine? routine;

  const EditCustomRoutineScreen({super.key, this.routine});

  @override
  ConsumerState<EditCustomRoutineScreen> createState() =>
      _EditCustomRoutineScreenState();
}

class _EditCustomRoutineScreenState
    extends ConsumerState<EditCustomRoutineScreen> {
  late TextEditingController _nameCtrl;
  late List<CustomWorkout> _workouts;
  bool _saving = false;

  bool get _isNew => widget.routine == null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.routine?.name ?? '');
    _workouts = List<CustomWorkout>.from(widget.routine?.workouts ?? const []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _autoDuration => RoutineExercise.estimateDayDuration(
        [for (final w in _workouts) ...w.exercises],
      );

  Future<void> _save() async {
    final name =
        _nameCtrl.text.trim().isEmpty ? 'Mi rutina' : _nameCtrl.text.trim();
    setState(() => _saving = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final routine = CustomRoutine(
        id: widget.routine?.id ?? '',
        name: name,
        workouts: _workouts,
        createdAt: widget.routine?.createdAt ?? DateTime.now(),
      );
      await ref
          .read(profileRepositoryProvider)
          .saveCustomRoutine(user.uid, routine);

      for (final w in _workouts) {
        for (final ex in w.exercises) {
          await ref.read(profileRepositoryProvider).saveExerciseDefault(
            uid: user.uid,
            exerciseId: ex.exerciseId,
            plannedSets: ex.effectiveSets,
            restSeconds: ex.restSeconds,
            notes: ex.notes,
          );
        }
      }

      ref.invalidate(customRoutinesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isNew ? 'Rutina creada' : 'Rutina guardada')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addWorkout() {
    setState(() {
      _workouts.add(
        CustomWorkout(
          id: CustomWorkout.newId(),
          name: 'Entrenamiento ${_workouts.length + 1}',
        ),
      );
    });
  }

  void _renameWorkout(int index, String name) {
    setState(() => _workouts[index] = _workouts[index].copyWith(name: name));
  }

  void _deleteWorkout(int index) {
    setState(() => _workouts.removeAt(index));
  }

  Future<RoutineExercise> _buildRoutineExercise(Exercise exercise) async {
    final user = ref.read(authServiceProvider).currentUser;
    List<PlannedSet> planned = const [
      PlannedSet(weight: 0, reps: 10),
      PlannedSet(weight: 0, reps: 10),
      PlannedSet(weight: 0, reps: 10),
    ];
    var rest = 60;
    var notes = '';

    if (user != null) {
      try {
        final data = await ref
            .read(profileRepositoryProvider)
            .getExerciseDefault(user.uid, exercise.id);
        if (data != null) {
          rest = (data['restSeconds'] as num?)?.toInt() ?? 60;
          notes = (data['notes'] as String?) ?? '';
          final raw = data['plannedSets'];
          if (raw is List && raw.isNotEmpty) {
            final parsed = [
              for (final item in raw)
                if (item is Map)
                  PlannedSet.fromMap(Map<String, dynamic>.from(item)),
            ];
            if (parsed.isNotEmpty) planned = parsed;
          }
        }
      } catch (e) {
        debugPrint('edit_custom_routine: sin último registro: $e');
      }
    }

    return RoutineExercise(
      exerciseId: exercise.id,
      exerciseName: exercise.name,
      muscleGroup: exercise.muscleGroup,
      sets: planned.length,
      reps: planned.first.reps,
      plannedSets: planned,
      restSeconds: rest,
      notes: notes,
    );
  }

  Future<void> _addExercisesToWorkout(int index) async {
    final picked = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(builder: (_) => const PickExerciseScreen()),
    );
    if (picked == null || picked.isEmpty) return;

    final added = <RoutineExercise>[];
    for (final exercise in picked) {
      added.add(await _buildRoutineExercise(exercise));
    }
    if (!mounted) return;
    setState(() {
      final w = _workouts[index];
      _workouts[index] = w.copyWith(exercises: [...w.exercises, ...added]);
    });
  }

  void _updateExercise(int wi, int ei, RoutineExercise updated) {
    setState(() {
      final w = _workouts[wi];
      final list = List<RoutineExercise>.from(w.exercises);
      list[ei] = updated;
      _workouts[wi] = w.copyWith(exercises: list);
    });
  }

  void _removeExercise(int wi, int ei) {
    setState(() {
      final w = _workouts[wi];
      final list = List<RoutineExercise>.from(w.exercises)..removeAt(ei);
      _workouts[wi] = w.copyWith(exercises: list);
    });
  }

  void _reorderExercise(int wi, int oldIndex, int newIndex) {
    setState(() {
      final w = _workouts[wi];
      final list = List<RoutineExercise>.from(w.exercises);
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _workouts[wi] = w.copyWith(exercises: list);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Nueva rutina' : 'Editar rutina'),
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
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre de la rutina (ej. Rutina 1)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Duración estimada (auto)',
              border: OutlineInputBorder(),
              helperText: '1 min por serie + descansos entre series',
            ),
            child: Text(
              _autoDuration.isEmpty ? '—' : _autoDuration,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Entrenamientos (${_workouts.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primary,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addWorkout,
                icon: const Icon(Icons.add),
                label: const Text('Añadir entrenamiento'),
              ),
            ],
          ),
          if (_workouts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Sin entrenamientos. Añade uno para empezar.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            for (var i = 0; i < _workouts.length; i++)
              _WorkoutEditorCard(
                key: ValueKey(_workouts[i].id.isEmpty
                    ? 'w_$i'
                    : _workouts[i].id),
                workout: _workouts[i],
                index: i,
                primary: primary,
                onNameChanged: (v) => _renameWorkout(i, v),
                onDelete: () => _deleteWorkout(i),
                onAddExercise: () => _addExercisesToWorkout(i),
                onExerciseChanged: (ei, updated) =>
                    _updateExercise(i, ei, updated),
                onExerciseRemoved: (ei) => _removeExercise(i, ei),
                onReorder: (o, n) => _reorderExercise(i, o, n),
              ),
        ],
      ),
    );
  }
}

/// Tarjeta editable de un entrenamiento (nombre + lista de ejercicios).
class _WorkoutEditorCard extends StatefulWidget {
  final CustomWorkout workout;
  final int index;
  final Color primary;
  final ValueChanged<String> onNameChanged;
  final VoidCallback onDelete;
  final VoidCallback onAddExercise;
  final void Function(int index, RoutineExercise updated) onExerciseChanged;
  final ValueChanged<int> onExerciseRemoved;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _WorkoutEditorCard({
    super.key,
    required this.workout,
    required this.index,
    required this.primary,
    required this.onNameChanged,
    required this.onDelete,
    required this.onAddExercise,
    required this.onExerciseChanged,
    required this.onExerciseRemoved,
    required this.onReorder,
  });

  @override
  State<_WorkoutEditorCard> createState() => _WorkoutEditorCardState();
}

class _WorkoutEditorCardState extends State<_WorkoutEditorCard> {
  bool _expanded = true;
  int? _expandedExercise;

  String _summary(RoutineExercise ex) {
    final n = ex.effectiveSets.length;
    final restLabel = _fmtRest(ex.restSeconds);
    final firstW = n > 0 ? ex.effectiveSets.first.weight : 0.0;
    final weightHint = firstW > 0
        ? '${firstW == firstW.roundToDouble() ? firstW.toInt() : firstW} kg'
        : 'sin peso';
    return '${ex.muscleGroup.isEmpty ? '—' : ex.muscleGroup} · $n series · '
        '$weightHint · $restLabel';
  }

  void _openDetail(RoutineExercise ex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exerciseId: ex.exerciseId,
          exerciseName: ex.exerciseName,
          muscleGroup: ex.muscleGroup,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;
    final workout = widget.workout;
    final exercises = workout.exercises;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: workout.name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Nombre del entrenamiento',
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    onChanged: widget.onNameChanged,
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar entrenamiento',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
                IconButton(
                  tooltip: _expanded ? 'Contraer' : 'Expandir',
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (exercises.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Sin ejercicios. Pulsa Añadir ejercicio.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: exercises.length,
                onReorderItem: (oldIndex, newIndex) {
                  setState(() {
                    if (_expandedExercise == oldIndex) {
                      _expandedExercise = newIndex;
                    } else if (_expandedExercise != null) {
                      if (oldIndex < _expandedExercise! &&
                          newIndex >= _expandedExercise!) {
                        _expandedExercise = _expandedExercise! - 1;
                      } else if (oldIndex > _expandedExercise! &&
                          newIndex <= _expandedExercise!) {
                        _expandedExercise = _expandedExercise! + 1;
                      }
                    }
                  });
                  widget.onReorder(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final ex = exercises[index];
                  final expanded = _expandedExercise == index;

                  return Card(
                    key: ValueKey('ex_${ex.exerciseId}_$index'),
                    margin: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                          child: Row(
                            children: [
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setState(() {
                                  _expandedExercise = expanded ? null : index;
                                }),
                                child: AnimatedRotation(
                                  turns: expanded ? 0.25 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.chevron_right,
                                    color: primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              ExerciseThumb(
                                exerciseId: ex.exerciseId,
                                size: 40,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _expandedExercise =
                                        expanded ? null : index;
                                  }),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ex.exerciseName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _summary(ex),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Ver detalle',
                                icon: const Icon(Icons.info_outline),
                                onPressed: () => _openDetail(ex),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (_expandedExercise == index) {
                                      _expandedExercise = null;
                                    } else if (_expandedExercise != null &&
                                        _expandedExercise! > index) {
                                      _expandedExercise =
                                          _expandedExercise! - 1;
                                    }
                                  });
                                  widget.onExerciseRemoved(index);
                                },
                              ),
                            ],
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild:
                              const SizedBox(width: double.infinity),
                          secondChild: ExerciseEditorPanel(
                            key: ValueKey('editor_${ex.exerciseId}_$index'),
                            exercise: ex,
                            primary: primary,
                            onChanged: (updated) =>
                                widget.onExerciseChanged(index, updated),
                          ),
                          crossFadeState: expanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 220),
                        ),
                      ],
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onAddExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir ejercicio'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _fmtRest(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  if (m > 0 && s > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
  if (m > 0) return '${m}min';
  return '${s}s';
}
