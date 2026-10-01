import 'package:flutter/material.dart';
import '../../../profile/domain/user_profile.dart';

/// Edición detallada de un ejercicio dentro de la rutina del día.
/// Pesos por serie, reps, descanso entre series, notas.
class EditRoutineExerciseScreen extends StatefulWidget {
  final RoutineExercise exercise;

  const EditRoutineExerciseScreen({super.key, required this.exercise});

  @override
  State<EditRoutineExerciseScreen> createState() =>
      _EditRoutineExerciseScreenState();
}

class _EditRoutineExerciseScreenState extends State<EditRoutineExerciseScreen> {
  late List<PlannedSet> _sets;
  late int _restSeconds;
  late TextEditingController _notesCtrl;
  late TextEditingController _restMinCtrl;
  late TextEditingController _restSecCtrl;
  final List<TextEditingController> _weightCtrls = [];
  final List<TextEditingController> _repsCtrls = [];

  @override
  void initState() {
    super.initState();
    final base = widget.exercise.effectiveSets;
    _sets = base.map((s) => PlannedSet(weight: s.weight, reps: s.reps)).toList();
    if (_sets.isEmpty) {
      _sets = [const PlannedSet(weight: 0, reps: 10)];
    }
    _restSeconds =
    widget.exercise.restSeconds <= 0 ? 60 : widget.exercise.restSeconds;
    _notesCtrl = TextEditingController(text: widget.exercise.notes);
    _restMinCtrl = TextEditingController(text: '${_restSeconds ~/ 60}');
    _restSecCtrl = TextEditingController(text: '${_restSeconds % 60}');
    _rebuildSetControllers();
  }

  void _rebuildSetControllers() {
    for (final c in _weightCtrls) {
      c.dispose();
    }
    for (final c in _repsCtrls) {
      c.dispose();
    }
    _weightCtrls.clear();
    _repsCtrls.clear();
    for (final s in _sets) {
      _weightCtrls.add(TextEditingController(
        text: s.weight > 0 ? _fmtWeight(s.weight) : '',
      ));
      _repsCtrls.add(TextEditingController(text: '${s.reps}'));
    }
  }

  String _fmtWeight(double w) {
    if (w == w.roundToDouble()) return '${w.toInt()}';
    return w.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _restMinCtrl.dispose();
    _restSecCtrl.dispose();
    for (final c in _weightCtrls) {
      c.dispose();
    }
    for (final c in _repsCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncRestFromFields() {
    final m = int.tryParse(_restMinCtrl.text) ?? 0;
    final s = int.tryParse(_restSecCtrl.text) ?? 0;
    _restSeconds = (m * 60 + s).clamp(0, 30 * 60);
  }

  void _syncSetsFromFields() {
    for (var i = 0; i < _sets.length; i++) {
      final w = double.tryParse(
        _weightCtrls[i].text.replaceAll(',', '.'),
      ) ??
          0;
      final r = int.tryParse(_repsCtrls[i].text) ?? _sets[i].reps;
      _sets[i] = PlannedSet(weight: w, reps: r);
    }
  }

  void _addSet() {
    _syncSetsFromFields();
    final last = _sets.isNotEmpty ? _sets.last : const PlannedSet();
    setState(() {
      _sets.add(PlannedSet(weight: last.weight, reps: last.reps));
      _weightCtrls.add(TextEditingController(
        text: last.weight > 0 ? _fmtWeight(last.weight) : '',
      ));
      _repsCtrls.add(TextEditingController(text: '${last.reps}'));
    });
  }

  void _removeSet(int i) {
    if (_sets.length <= 1) return;
    setState(() {
      _sets.removeAt(i);
      _weightCtrls.removeAt(i).dispose();
      _repsCtrls.removeAt(i).dispose();
    });
  }

  void _save() {
    _syncRestFromFields();
    _syncSetsFromFields();
    final updated = widget.exercise.copyWith(
      plannedSets: List<PlannedSet>.from(_sets),
      sets: _sets.length,
      reps: _sets.isNotEmpty ? _sets.first.reps : 10,
      restSeconds: _restSeconds <= 0 ? 60 : _restSeconds,
      notes: _notesCtrl.text.trim(),
    );
    Navigator.pop(context, updated);
  }

  String _fmtRest() {
    final m = _restSeconds ~/ 60;
    final s = _restSeconds % 60;
    if (m > 0 && s > 0) return '${m}min ${s}s';
    if (m > 0) return '${m}min';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exercise.exerciseName),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Actualizar',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.exercise.muscleGroup.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.exercise.muscleGroup,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Agregar notas de rutina aquí',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.timer_outlined, color: primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Descanso entre series',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              SizedBox(
                width: 52,
                child: TextField(
                  controller: _restMinCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'min',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    _syncRestFromFields();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 52,
                child: TextField(
                  controller: _restSecCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'seg',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    _syncRestFromFields();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              'Actual: ${_fmtRest()} (base recomendada 1 min)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  'SERIE',
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
              SizedBox(width: 40),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_sets.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: primary.withValues(alpha: 0.15),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
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
                          vertical: 10,
                        ),
                      ),
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
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _removeSet(i),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addSet,
            icon: const Icon(Icons.add),
            label: const Text('Agregar serie'),
          ),
        ],
      ),
    );
  }
}
