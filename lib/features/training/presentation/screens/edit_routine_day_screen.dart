import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/exercise.dart';
import 'exercise_detail_screen.dart';

class EditRoutineDayScreen extends ConsumerStatefulWidget {
  final RoutineDay day;

  const EditRoutineDayScreen({super.key, required this.day});

  @override
  ConsumerState<EditRoutineDayScreen> createState() =>
      _EditRoutineDayScreenState();
}

class _EditRoutineDayScreenState extends ConsumerState<EditRoutineDayScreen> {
  late TextEditingController _titleCtrl;
  late bool _isRestDay;
  late List<RoutineExercise> _exercises;
  bool _saving = false;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.day.title);
    _isRestDay = widget.day.isRestDay;
    _exercises = List<RoutineExercise>.from(widget.day.exercises);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  String get _autoDuration => RoutineExercise.estimateDayDuration(_exercises);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final updated = RoutineDay(
        day: widget.day.day,
        title: _titleCtrl.text.trim().isEmpty
            ? widget.day.title
            : _titleCtrl.text.trim(),
        duration: _isRestDay ? '' : _autoDuration,
        calories: widget.day.calories,
        isRestDay: _isRestDay,
        description: widget.day.description,
        imageUrl: widget.day.imageUrl,
        exercises: _isRestDay ? const [] : _exercises,
      );

      await ref.read(profileRepositoryProvider).saveRoutine(user.uid, updated);

      if (!_isRestDay) {
        for (final ex in _exercises) {
          await ref.read(profileRepositoryProvider).saveExerciseDefault(
            uid: user.uid,
            exerciseId: ex.exerciseId,
            plannedSets: ex.effectiveSets,
            restSeconds: ex.restSeconds,
            notes: ex.notes,
          );
        }
      }

      ref.invalidate(routinesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Día guardado')),
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
    final Exercise? picked = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(builder: (_) => const _PickExerciseScreen()),
    );
    if (picked == null) return;

    final user = ref.read(authServiceProvider).currentUser;
    List<PlannedSet> planned = [
      const PlannedSet(weight: 0, reps: 10),
      const PlannedSet(weight: 0, reps: 10),
      const PlannedSet(weight: 0, reps: 10),
    ];
    var rest = 60;
    var notes = '';

    if (user != null) {
      try {
        final data = await ref
            .read(profileRepositoryProvider)
            .getExerciseDefault(user.uid, picked.id);
        if (data != null) {
          rest = data['restSeconds'] as int? ?? 60;
          notes = (data['notes'] as String?) ?? '';
          final raw = data['plannedSets'];
          if (raw is List && raw.isNotEmpty) {
            planned = [
              for (final item in raw)
                if (item is Map)
                  PlannedSet.fromMap(Map<String, dynamic>.from(item)),
            ];
            if (planned.isEmpty) {
              planned = [
                const PlannedSet(weight: 0, reps: 10),
                const PlannedSet(weight: 0, reps: 10),
                const PlannedSet(weight: 0, reps: 10),
              ];
            }
          }
        }
      } catch (_) {}
    }

    setState(() {
      _exercises.add(
        RoutineExercise(
          exerciseId: picked.id,
          exerciseName: picked.name,
          muscleGroup: picked.muscleGroup,
          sets: planned.length,
          reps: planned.first.reps,
          plannedSets: planned,
          restSeconds: rest,
          notes: notes,
        ),
      );
      _isRestDay = false;
      _expandedIndex = _exercises.length - 1;
    });
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
    return '${ex.muscleGroup.isEmpty ? '—' : ex.muscleGroup} · $n series · $weightHint · $restLabel';
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
        title: Text('Editar · ${widget.day.day}'),
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
          SwitchListTile(
            title: const Text('Día de descanso'),
            value: _isRestDay,
            activeColor: primary,
            onChanged: (v) => setState(() {
              _isRestDay = v;
              if (v) _titleCtrl.text = 'Descanso';
            }),
          ),
          TextField(
            controller: _titleCtrl,
            enabled: !_isRestDay,
            decoration: const InputDecoration(
              labelText: 'Título (ej. Pecho, Pierna)',
              border: OutlineInputBorder(),
            ),
          ),
          if (!_isRestDay) ...[
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
            // Reorderable: arrastre inmediato desde el asa (=)
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _exercises.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _exercises.removeAt(oldIndex);
                    _exercises.insert(newIndex, item);
                    // Ajustar índice expandido
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
                              // Asa: arrastra SIN mantener (DragStartListener)
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
                                    _expandedIndex =
                                    expanded ? null : index;
                                  });
                                },
                                child: AnimatedRotation(
                                  turns: expanded ? 0.25 : 0,
                                  duration:
                                  const Duration(milliseconds: 200),
                                  child: Icon(
                                    Icons.chevron_right,
                                    color: primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _expandedIndex =
                                      expanded ? null : index;
                                    });
                                  },
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
                                    _exercises.removeAt(index);
                                    if (_expandedIndex == index) {
                                      _expandedIndex = null;
                                    } else if (_expandedIndex != null &&
                                        _expandedIndex! > index) {
                                      _expandedIndex =
                                          _expandedIndex! - 1;
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
                          secondChild: _ExerciseEditorPanel(
                            key: ValueKey(
                                'editor_${ex.exerciseId}_$index'),
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
        ],
      ),
    );
  }
}

// ─── Selector de descanso estilo bottom sheet ─────────────

Future<int?> showRestTimePicker(
    BuildContext context, {
      required int initialSeconds,
      required String exerciseName,
    }) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _RestTimeSheet(
      initialSeconds: initialSeconds,
      exerciseName: exerciseName,
    ),
  );
}

class _RestTimeSheet extends StatefulWidget {
  final int initialSeconds;
  final String exerciseName;

  const _RestTimeSheet({
    required this.initialSeconds,
    required this.exerciseName,
  });

  @override
  State<_RestTimeSheet> createState() => _RestTimeSheetState();
}

class _RestTimeSheetState extends State<_RestTimeSheet> {
  late int _seconds;
  late FixedExtentScrollController _controller;

  // Opciones de 15s a 10min cada 15s
  static final List<int> _options = [
    for (var s = 15; s <= 600; s += 15) s,
  ];

  @override
  void initState() {
    super.initState();
    _seconds = widget.initialSeconds.clamp(15, 600);
    // Snap to nearest 15
    _seconds = ((_seconds / 15).round() * 15).clamp(15, 600);
    final idx = _options.indexOf(_seconds);
    _controller = FixedExtentScrollController(
      initialItem: idx >= 0 ? idx : 3, // 60s default
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _label(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0 && s > 0) {
      return '${m}min ${s.toString().padLeft(2, '0')}s';
    }
    if (m > 0) return '${m}min 0s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Temporizador de Descanso',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Temporizador de Descanso – ${widget.exerciseName}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: 44,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  setState(() => _seconds = _options[i]);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _options.length,
                  builder: (context, i) {
                    final selected = _options[i] == _seconds;
                    return Center(
                      child: Text(
                        _label(_options[i]),
                        style: TextStyle(
                          fontSize: selected ? 22 : 16,
                          fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? primary : Colors.grey.shade600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _seconds),
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Listo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Panel de edición expandido ───────────────────────────

class _ExerciseEditorPanel extends StatefulWidget {
  final RoutineExercise exercise;
  final Color primary;
  final ValueChanged<RoutineExercise> onChanged;

  const _ExerciseEditorPanel({
    super.key,
    required this.exercise,
    required this.primary,
    required this.onChanged,
  });

  @override
  State<_ExerciseEditorPanel> createState() => _ExerciseEditorPanelState();
}

class _ExerciseEditorPanelState extends State<_ExerciseEditorPanel> {
  late List<PlannedSet> _sets;
  late int _restSeconds;
  late TextEditingController _notesCtrl;
  final List<TextEditingController> _weightCtrls = [];
  final List<TextEditingController> _repsCtrls = [];

  @override
  void initState() {
    super.initState();
    _loadFrom(widget.exercise);
  }

  @override
  void didUpdateWidget(covariant _ExerciseEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.exerciseId != widget.exercise.exerciseId) {
      _loadFrom(widget.exercise);
    }
  }

  void _loadFrom(RoutineExercise exercise) {
    for (final c in _weightCtrls) {
      c.dispose();
    }
    for (final c in _repsCtrls) {
      c.dispose();
    }
    _weightCtrls.clear();
    _repsCtrls.clear();

    final base = exercise.effectiveSets;
    _sets =
        base.map((s) => PlannedSet(weight: s.weight, reps: s.reps)).toList();
    if (_sets.isEmpty) {
      _sets = [const PlannedSet(weight: 0, reps: 10)];
    }
    _restSeconds = exercise.restSeconds <= 0 ? 60 : exercise.restSeconds;
    _notesCtrl = TextEditingController(text: exercise.notes);
    for (final s in _sets) {
      _weightCtrls.add(TextEditingController(
        text: s.weight > 0 ? _fmtW(s.weight) : '',
      ));
      _repsCtrls.add(TextEditingController(text: '${s.reps}'));
    }
  }

  String _fmtW(double w) {
    if (w == w.roundToDouble()) return '${w.toInt()}';
    return w.toStringAsFixed(1);
  }

  String _fmtRest(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0 && s > 0) {
      return '${m}min ${s.toString().padLeft(2, '0')}s';
    }
    if (m > 0) return '${m}min 0s';
    return '${s}s';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    for (final c in _weightCtrls) {
      c.dispose();
    }
    for (final c in _repsCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit({int? restOverride}) {
    final rest = restOverride ?? _restSeconds;
    final sets = <PlannedSet>[];
    for (var i = 0; i < _sets.length; i++) {
      final w = double.tryParse(
        _weightCtrls[i].text.replaceAll(',', '.'),
      ) ??
          0;
      final r = int.tryParse(_repsCtrls[i].text) ?? _sets[i].reps;
      sets.add(PlannedSet(weight: w, reps: r));
    }

    widget.onChanged(
      widget.exercise.copyWith(
        plannedSets: sets,
        sets: sets.length,
        reps: sets.isNotEmpty ? sets.first.reps : 10,
        restSeconds: rest <= 0 ? 60 : rest,
        notes: _notesCtrl.text.trim(),
      ),
    );
  }

  Future<void> _pickRest() async {
    final result = await showRestTimePicker(
      context,
      initialSeconds: _restSeconds,
      exerciseName: widget.exercise.exerciseName,
    );
    if (result == null) return;
    setState(() => _restSeconds = result);
    _emit(restOverride: result);
  }

  void _addSet() {
    final last = _sets.isNotEmpty ? _sets.last : const PlannedSet();
    setState(() {
      _sets.add(PlannedSet(weight: last.weight, reps: last.reps));
      _weightCtrls.add(TextEditingController(
        text: last.weight > 0 ? _fmtW(last.weight) : '',
      ));
      _repsCtrls.add(TextEditingController(text: '${last.reps}'));
    });
    _emit();
  }

  void _removeSet(int i) {
    if (_sets.length <= 1) return;
    setState(() {
      _sets.removeAt(i);
      _weightCtrls.removeAt(i).dispose();
      _repsCtrls.removeAt(i).dispose();
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Agregar notas de rutina aquí',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 10),
          // Descanso: tocas y abre el selector
          Material(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickRest,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Descanso:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _fmtRest(_restSeconds),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primary,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.unfold_more, color: primary.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '#',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  'PESO (kg)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  'REPS',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 6),
          ...List.generate(_sets.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: primary.withValues(alpha: 0.15),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _weightCtrls[i],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _repsCtrls[i],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (_) => _emit(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => _removeSet(i),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: _addSet,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar serie'),
          ),
        ],
      ),
    );
  }
}

class _PickExerciseScreen extends StatefulWidget {
  const _PickExerciseScreen();

  @override
  State<_PickExerciseScreen> createState() => _PickExerciseScreenState();
}

class _PickExerciseScreenState extends State<_PickExerciseScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final filtered = ExerciseCatalog.builtIn.where((e) {
      if (_query.isEmpty) return true;
      return e.name.toLowerCase().contains(_query.toLowerCase()) ||
          e.muscleGroup.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegir ejercicio'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final e = filtered[i];
                return ListTile(
                  title: Text(e.name),
                  subtitle: Text('${e.muscleGroup} · ${e.equipment}'),
                  onTap: () => Navigator.pop(context, e),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
