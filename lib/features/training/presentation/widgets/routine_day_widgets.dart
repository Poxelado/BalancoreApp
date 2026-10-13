import 'package:flutter/material.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../../core/theme/app_theme.dart';

class RestTimeSheet extends StatefulWidget {
  final int initialSeconds;
  final String exerciseName;

  const RestTimeSheet({super.key,
    required this.initialSeconds,
    required this.exerciseName,
  });

  @override
  State<RestTimeSheet> createState() => RestTimeSheetState();
}

class RestTimeSheetState extends State<RestTimeSheet> {
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

class ExerciseEditorPanel extends StatefulWidget {
  final RoutineExercise exercise;
  final Color primary;
  final ValueChanged<RoutineExercise> onChanged;

  const ExerciseEditorPanel({
    super.key,
    required this.exercise,
    required this.primary,
    required this.onChanged,
  });

  @override
  State<ExerciseEditorPanel> createState() => ExerciseEditorPanelState();
}

class ExerciseEditorPanelState extends State<ExerciseEditorPanel> {
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
  void didUpdateWidget(covariant ExerciseEditorPanel oldWidget) {
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
                    Icon(Icons.timer_outlined, color: accentOf(context), size: 20),
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
                        color: accentOf(context),
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
                          color: accentOf(context),
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
                    tooltip: 'Eliminar serie',
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
    builder: (ctx) => RestTimeSheet(
      initialSeconds: initialSeconds,
      exerciseName: exerciseName,
    ),
  );
}
