import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import 'exercise_detail_screen.dart';

const _kRestSecondsKey = 'balancore_rest_seconds';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  final RoutineDay routine;
  final WorkoutSession? existing;
  final DateTime? sessionDate;

  const WorkoutSessionScreen({
    super.key,
    required this.routine,
    this.existing,
    this.sessionDate,
  });

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  late WorkoutSession _session;
  int _exerciseIndex = 0;
  bool _saving = false;

  Timer? _tickTimer;
  int _elapsedSeconds = 0;
  bool _paused = false;

  int _restSecondsDefault = 90;
  int? _restRemaining;
  Timer? _restTimer;

  final Map<String, TextEditingController> _weightCtrls = {};
  final Map<String, TextEditingController> _repsCtrls = {};

  @override
  void initState() {
    super.initState();
    if (widget.existing != null && !widget.existing!.completed) {
      _session = widget.existing!;
      _elapsedSeconds = widget.existing!.elapsedSeconds;
      _paused = widget.existing!.isPaused;
    } else {
      _session = WorkoutSession.fromRoutine(
        widget.routine,
        date: widget.sessionDate,
      );
      _elapsedSeconds = 0;
      _paused = false;
    }
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _paused) return;
      setState(() => _elapsedSeconds++);
      // persist elapsed every 15s
      if (_elapsedSeconds % 15 == 0) {
        _session = _session.copyWith(elapsedSeconds: _elapsedSeconds);
        _persist(silent: true);
      }
    });
    _loadRestPref();
    _initControllers();
    // Guardar al entrar para que exista en historial / mini player
    WidgetsBinding.instance.addPostFrameCallback((_) => _persist());
  }

  Future<void> _loadRestPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _restSecondsDefault = prefs.getInt(_kRestSecondsKey) ?? 90);
  }

  Future<void> _saveRestPref(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRestSecondsKey, seconds);
    if (mounted) setState(() => _restSecondsDefault = seconds);
  }

  void _initControllers() {
    for (final ex in _session.exercises) {
      for (final s in ex.sets) {
        final key = _key(ex, s);
        _weightCtrls[key] = TextEditingController(
          text: s.weight > 0 ? _fmtWeight(s.weight) : '',
        );
        _repsCtrls[key] = TextEditingController(text: '${s.reps}');
      }
    }
  }

  String _fmtWeight(double w) {
    if (w == w.roundToDouble()) return '${w.toInt()}';
    return w.toStringAsFixed(1);
  }

  String _fmtElapsed(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    final h = sec ~/ 3600;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  String _fmtRest(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  String _key(WorkoutExerciseLog ex, WorkoutSetLog s) =>
      '${ex.exerciseId}_${s.setNumber}';

  @override
  void dispose() {
    _tickTimer?.cancel();
    _restTimer?.cancel();
    for (final c in _weightCtrls.values) {
      c.dispose();
    }
    for (final c in _repsCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _persist({bool silent = false}) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    _session = _session.copyWith(
      elapsedSeconds: _elapsedSeconds,
      isPaused: _paused,
    );
    await ref.read(profileRepositoryProvider).saveWorkoutSession(
      user.uid,
      _session,
    );
    invalidateProgressData(ref);
  }

  Future<void> _togglePause() async {
    setState(() => _paused = !_paused);
    await _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_paused ? 'Sesión pausada' : 'Sesión reanudada'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// Al salir: guarda y vuelve (no cancela).
  Future<void> _minimize() async {
    await _persist();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _updateSetsCascade({
    required int exerciseIndex,
    required int setIndex,
    double? weight,
    int? reps,
  }) async {
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final ex = exercises[exerciseIndex];
    final sets = List<WorkoutSetLog>.from(ex.sets);

    for (var i = setIndex; i < sets.length; i++) {
      sets[i] = sets[i].copyWith(
        weight: weight ?? sets[i].weight,
        reps: reps ?? sets[i].reps,
      );
      final key = '${ex.exerciseId}_${sets[i].setNumber}';
      if (weight != null) {
        _weightCtrls[key]?.text = weight > 0 ? _fmtWeight(weight) : '';
      }
      if (reps != null) {
        _repsCtrls[key]?.text = '$reps';
      }
    }

    exercises[exerciseIndex] = ex.copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
    await _persist();
  }

  Future<void> _syncFromField(int exerciseIndex, int setIndex,
      {required bool isWeight}) async {
    final ex = _session.exercises[exerciseIndex];
    final s = ex.sets[setIndex];
    final key = _key(ex, s);
    if (isWeight) {
      final w = double.tryParse(
        (_weightCtrls[key]?.text ?? '').replaceAll(',', '.'),
      ) ??
          0;
      await _updateSetsCascade(
        exerciseIndex: exerciseIndex,
        setIndex: setIndex,
        weight: w,
      );
    } else {
      final r = int.tryParse(_repsCtrls[key]?.text ?? '') ?? s.reps;
      await _updateSetsCascade(
        exerciseIndex: exerciseIndex,
        setIndex: setIndex,
        reps: r,
      );
    }
  }

  Future<void> _toggleComplete(int exerciseIndex, int setIndex) async {
    // sync fields first without cascade on complete alone
    final ex = _session.exercises[exerciseIndex];
    final s = ex.sets[setIndex];
    final key = _key(ex, s);
    final w = double.tryParse(
      (_weightCtrls[key]?.text ?? '').replaceAll(',', '.'),
    ) ??
        s.weight;
    final r = int.tryParse(_repsCtrls[key]?.text ?? '') ?? s.reps;

    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final sets = List<WorkoutSetLog>.from(ex.sets);
    final wasDone = sets[setIndex].completed;
    sets[setIndex] = sets[setIndex].copyWith(
      weight: w,
      reps: r,
      completed: !wasDone,
    );
    exercises[exerciseIndex] = ex.copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
    await _persist();
    if (!wasDone) {
      HapticFeedback.lightImpact();
      _startRest();
    }
  }

  void _startRest() {
    _restTimer?.cancel();
    // Usa el descanso configurado en la rutina para ESTE ejercicio
    final exerciseRest = _session.exercises.isNotEmpty
        ? _session.exercises[_exerciseIndex].restSeconds
        : 60;
    final seconds = exerciseRest > 0 ? exerciseRest : 60;
    setState(() => _restRemaining = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_restRemaining == null) {
        t.cancel();
        return;
      }
      if (_restRemaining! <= 1) {
        t.cancel();
        setState(() => _restRemaining = null);
        HapticFeedback.mediumImpact();
      } else {
        setState(() => _restRemaining = _restRemaining! - 1);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _restRemaining = null);
  }

  Future<void> _deleteSet(int exerciseIndex, int setIndex) async {
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final ex = exercises[exerciseIndex];
    if (ex.sets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debe quedar al menos una serie')),
      );
      return;
    }
    final sets = List<WorkoutSetLog>.from(ex.sets)..removeAt(setIndex);
    // renumber
    for (var i = 0; i < sets.length; i++) {
      sets[i] = WorkoutSetLog(
        setNumber: i + 1,
        weight: sets[i].weight,
        reps: sets[i].reps,
        completed: sets[i].completed,
      );
    }
    exercises[exerciseIndex] = ex.copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
    // rebuild controllers for this exercise
    for (final s in sets) {
      final key = '${ex.exerciseId}_${s.setNumber}';
      _weightCtrls[key] = TextEditingController(
        text: s.weight > 0 ? _fmtWeight(s.weight) : '',
      );
      _repsCtrls[key] = TextEditingController(text: '${s.reps}');
    }
    await _persist();
  }

  Future<void> _addSet(int exerciseIndex) async {
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final ex = exercises[exerciseIndex];
    final sets = List<WorkoutSetLog>.from(ex.sets);
    final last = sets.isNotEmpty ? sets.last : null;
    final newSet = WorkoutSetLog(
      setNumber: sets.length + 1,
      weight: last?.weight ?? 0,
      reps: last?.reps ?? 10,
      completed: false,
    );
    sets.add(newSet);
    exercises[exerciseIndex] = ex.copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
    final key = _key(ex, newSet);
    _weightCtrls[key] = TextEditingController(
      text: newSet.weight > 0 ? _fmtWeight(newSet.weight) : '',
    );
    _repsCtrls[key] = TextEditingController(text: '${newSet.reps}');
    await _persist();
  }

  Future<void> _finish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar entrenamiento'),
        content: Text(
          'Tiempo: ${_fmtElapsed(_elapsedSeconds)}\n'
              'Series: ${_session.completedSets}/${_session.totalSets}\n\n'
              '¿Finalizar sesión?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalizar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      _session = _session.copyWith(
        completed: true,
        isPaused: false,
        elapsedSeconds: _elapsedSeconds,
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


  Future<void> _editExerciseNotes() async {
    final ex = _session.exercises[_exerciseIndex];
    final ctrl = TextEditingController(text: ex.notes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Notas · ${ex.exerciseName}'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Forma, molestias, tips...',
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
    list[_exerciseIndex] = ex.copyWith(notes: ctrl.text.trim());
    setState(() => _session = _session.copyWith(exercises: list));
    await _persist();
  }

  Future<void> _editSessionNotes() async {
    final ctrl = TextEditingController(text: _session.notes);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notas de la sesión'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Cómo te sentiste hoy...',
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
    setState(() => _session = _session.copyWith(notes: ctrl.text.trim()));
    await _persist();
  }

  void _openSettings() {
    final restCtrl = TextEditingController(text: '$_restSecondsDefault');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Configuración de sesión',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Descanso entre series'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in [60, 90, 120, 180])
                      ChoiceChip(
                        label: Text(_fmtRest(s)),
                        selected: _restSecondsDefault == s,
                        onSelected: (_) {
                          _saveRestPref(s);
                          Navigator.pop(ctx);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: restCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Personalizado (segundos)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    final v = int.tryParse(restCtrl.text);
                    if (v != null && v > 0 && v < 600) {
                      _saveRestPref(v);
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0E0E12) : Colors.grey.shade100;
    final cardBg = isDark ? const Color(0xFF1A1A22) : Colors.white;

    if (_session.exercises.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: const Text('Entrenamiento'),
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'Sin ejercicios en esta rutina.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final ex = _session.exercises[_exerciseIndex];
    final progress = _session.totalSets == 0
        ? 0.0
        : _session.completedSets / _session.totalSets;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Minimizar (no cancela)',
                    icon: const Icon(Icons.close),
                    onPressed: _minimize,
                  ),
                  Icon(
                    _paused ? Icons.pause_circle : Icons.timer_outlined,
                    size: 18,
                    color: _paused ? Colors.orange : primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _fmtElapsed(_elapsedSeconds),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _paused ? Colors.orange : null,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (_paused)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text('PAUSA',
                          style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  const Spacer(),
                  IconButton(
                    tooltip: _paused ? 'Reanudar' : 'Pausar',
                    icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
                    onPressed: _togglePause,
                  ),
                  IconButton(
                    tooltip: 'Notas de sesión',
                    icon: Icon(
                      _session.notes.isEmpty
                          ? Icons.comment_outlined
                          : Icons.comment,
                    ),
                    onPressed: _editSessionNotes,
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: _openSettings,
                  ),
                  TextButton(
                    onPressed: _saving ? null : _finish,
                    child: Text(
                      'Terminar',
                      style: TextStyle(
                          color: primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: primary.withValues(alpha: 0.15),
                  color: primary,
                ),
              ),
            ),
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                itemCount: _session.exercises.length,
                itemBuilder: (context, i) {
                  final e = _session.exercises[i];
                  final selected = i == _exerciseIndex;
                  final allDone =
                      e.sets.isNotEmpty && e.sets.every((s) => s.completed);
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _exerciseIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? primary
                              : (allDone
                              ? Colors.green.withValues(alpha: 0.3)
                              : cardBg),
                          border: Border.all(
                            color: selected
                                ? primary
                                : Colors.grey.withValues(alpha: 0.3),
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        child: Icon(
                          allDone ? Icons.check : Icons.fitness_center,
                          color: selected
                              ? Colors.white
                              : (allDone ? Colors.green : Colors.grey),
                          size: 22,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
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
                          },
                          child: Text(
                            ex.exerciseName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notas del ejercicio',
                    icon: Icon(
                      ex.notes.isEmpty
                          ? Icons.note_add_outlined
                          : Icons.sticky_note_2,
                      color: primary,
                    ),
                    onPressed: _editExerciseNotes,
                  ),
                ],
              ),
            ),
            if (_restRemaining != null)
              Material(
                color: primary.withValues(alpha: 0.15),
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_bottom, color: primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Descanso · ${_fmtRest(_restRemaining!)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      TextButton(
                          onPressed: _skipRest, child: const Text('Saltar')),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _h('SERIE', 2),
                  _h('PREVIA', 3),
                  _h('KG', 3),
                  _h('REPS', 3),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: ex.sets.length + 1,
                itemBuilder: (context, i) {
                  if (i == ex.sets.length) {
                    return TextButton.icon(
                      onPressed: () => _addSet(_exerciseIndex),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir serie'),
                    );
                  }
                  final s = ex.sets[i];
                  final key = _key(ex, s);
                  _weightCtrls.putIfAbsent(
                    key,
                        () => TextEditingController(
                      text: s.weight > 0 ? _fmtWeight(s.weight) : '',
                    ),
                  );
                  _repsCtrls.putIfAbsent(
                    key,
                        () => TextEditingController(text: '${s.reps}'),
                  );

                  String previa = '—';
                  if (i > 0) {
                    final prev = ex.sets[i - 1];
                    if (prev.weight > 0 || prev.completed) {
                      previa =
                      '${prev.weight > 0 ? _fmtWeight(prev.weight) : '-'} × ${prev.reps}';
                    }
                  } else {
                    previa = 'obj. ${s.reps}';
                  }

                  return Dismissible(
                    key: ValueKey('${ex.exerciseId}_${s.setNumber}_$i'),
                    direction: DismissDirection.horizontal,
                    background: Container(
                      color: Colors.red.shade700,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    secondaryBackground: Container(
                      color: Colors.red.shade700,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      if (ex.sets.length <= 1) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                              Text('Debe quedar al menos una serie')),
                        );
                        return false;
                      }
                      return true;
                    },
                    onDismissed: (_) => _deleteSet(_exerciseIndex, i),
                    child: Container(
                      color: s.completed
                          ? Colors.green.withValues(alpha: 0.08)
                          : null,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text('${s.setNumber}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: s.completed ? Colors.green : null,
                                )),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(previa,
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13)),
                          ),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _weightCtrls[key],
                                keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 10),
                                  filled: true,
                                  fillColor: cardBg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (_) => _syncFromField(
                                    _exerciseIndex, i,
                                    isWeight: true),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 40,
                              child: TextField(
                                controller: _repsCtrls[key],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 10),
                                  filled: true,
                                  fillColor: cardBg,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (_) => _syncFromField(
                                    _exerciseIndex, i,
                                    isWeight: false),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              onPressed: () =>
                                  _toggleComplete(_exerciseIndex, i),
                              icon: Icon(
                                s.completed
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                color: s.completed
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exerciseIndex > 0
                          ? () => setState(() => _exerciseIndex--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Anterior'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style:
                      FilledButton.styleFrom(backgroundColor: primary),
                      onPressed:
                      _exerciseIndex < _session.exercises.length - 1
                          ? () => setState(() => _exerciseIndex++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Siguiente'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _h(String t, int flex) => Expanded(
    flex: flex,
    child: Text(
      t,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade500,
        letterSpacing: 0.5,
      ),
    ),
  );
}
