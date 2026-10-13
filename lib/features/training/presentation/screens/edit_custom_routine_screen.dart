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
  late List<RoutineExercise> _exercises;
  bool _saving = false;
  int? _expandedIndex;

  bool get _isNew => widget.routine == null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.routine?.name ?? '');
    _exercises = List<RoutineExercise>.from(
      widget.routine?.exercises ?? const [],
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _autoDuration => RoutineExercise.estimateDayDuration(_exercises);

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
        exercises: _exercises,
        createdAt: widget.routine?.createdAt ?? DateTime.now(),
      );
      await ref
          .read(profileRepositoryProvider)
          .saveCustomRoutine(user.uid, routine);

      for (final ex in _exercises) {
        await ref.read(profileRepositoryProvider).saveExerciseDefault(
          uid: user.uid,
          exerciseId: ex.exerciseId,
          plannedSets: ex.effectiveSets,
          restSeconds: ex.restSeconds,
          notes: ex.notes,
        );
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

  Future<void> _addExercise() async {
    final picked = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(builder: (_) => const PickExerciseScreen()),
    );
    if (picked == null || picked.isEmpty) return;

    final added = <RoutineExercise>[];
    for (final exercise in picked) {
      added.add(await _buildRoutineExercise(exercise));
    }

    setState(() {
      _exercises.addAll(added);
      _expandedIndex = _exercises.length - 1;
    });
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

  void _updateExercise(int index, RoutineExercise updated) {
    setState(() => _exercises[index] = updated);
  }

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

  static String _fmtRest(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0 && s > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    if (m > 0) return '${m}min';
    return '${s}s';
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
              labelText: 'Nombre (ej. Día de brazos extra, Full body)',
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
                'Ejercicios (${_exercises.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primary,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Añadir'),
              ),
            ],
          ),
          if (_exercises.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Sin ejercicios. Pulsa Añadir.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _exercises.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final item = _exercises.removeAt(oldIndex);
                  _exercises.insert(newIndex, item);
                  if (_expandedIndex == oldIndex) {
                    _expandedIndex = newIndex;
                  } else if (_expandedIndex != null) {
                    if (oldIndex < _expandedIndex! &&
                        newIndex >= _expandedIndex!) {
                      _expandedIndex = _expandedIndex! - 1;
                    } else if (oldIndex > _expandedIndex! &&
                        newIndex <= _expandedIndex!) {
                      _expandedIndex = _expandedIndex! + 1;
                    }
                  }
                });
              },
              itemBuilder: (context, index) {
                final ex = _exercises[index];
                final expanded = _expandedIndex == index;

                return Card(
                  key: ValueKey('ex_${ex.exerciseId}_$index'),
                  margin: const EdgeInsets.only(bottom: 10),
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
                              onTap: () {
                                setState(() {
                                  _expandedIndex = expanded ? null : index;
                                });
                              },
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
                                onTap: () {
                                  setState(() {
                                    _expandedIndex = expanded ? null : index;
                                  });
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  _exercises.removeAt(index);
                                  if (_expandedIndex == index) {
                                    _expandedIndex = null;
                                  } else if (_expandedIndex != null &&
                                      _expandedIndex! > index) {
                                    _expandedIndex = _expandedIndex! - 1;
                                  }
                                });
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
                              _updateExercise(index, updated),
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
        ],
      ),
    );
  }
}
