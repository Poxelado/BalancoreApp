import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

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

  // Workout elapsed timer
  late final DateTime _startedAt;
  Timer? _tickTimer;
  Duration _elapsed = Duration.zero;

  // Rest timer
  int _restSecondsDefault = 90;
  int? _restRemaining; // null = not resting
  Timer? _restTimer;

  final Map<String, TextEditingController> _weightCtrls = {};
  final Map<String, TextEditingController> _repsCtrls = {};

  @override
  void initState() {
    super.initState();
    if (widget.existing != null && !widget.existing!.completed) {
      _session = widget.existing!;
      _startedAt = widget.existing!.startedAt;
      _elapsed = DateTime.now().difference(_startedAt);
    } else {
      _session = WorkoutSession.fromRoutine(
        widget.routine,
        date: widget.sessionDate,
      );
      _startedAt = _session.startedAt;
    }
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt));
    });
    _loadRestPref();
    _initControllers();
  }

  Future<void> _loadRestPref() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _restSecondsDefault = prefs.getInt(_kRestSecondsKey) ?? 90;
    });
  }

  Future<void> _saveRestPref(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kRestSecondsKey, seconds);
    setState(() => _restSecondsDefault = seconds);
  }

  void _initControllers() {
    for (final ex in _session.exercises) {
      for (final s in ex.sets) {
        final key = '${ex.exerciseId}_${s.setNumber}';
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

  String _fmtElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  String _fmtRest(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

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

  Future<void> _persist() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    await ref.read(profileRepositoryProvider).saveWorkoutSession(
      user.uid,
      _session,
    );
    ref.invalidate(todayWorkoutSessionProvider);
    ref.invalidate(workoutHistoryProvider(30));
    ref.invalidate(workoutHistoryProvider(90));
    ref.invalidate(workoutHistoryProvider(180));
    ref.invalidate(workoutHistoryProvider(365));
  }

  String _key(WorkoutExerciseLog ex, WorkoutSetLog s) =>
      '${ex.exerciseId}_${s.setNumber}';

  Future<void> _syncSetFromFields(int exIndex, int setIndex) async {
    final ex = _session.exercises[exIndex];
    final s = ex.sets[setIndex];
    final key = _key(ex, s);
    final w = double.tryParse(
      (_weightCtrls[key]?.text ?? '').replaceAll(',', '.'),
    ) ??
        0;
    final r = int.tryParse(_repsCtrls[key]?.text ?? '') ?? s.reps;
    await _updateSet(exIndex, setIndex, weight: w, reps: r);
  }

  Future<void> _updateSet(
      int exerciseIndex,
      int setIndex, {
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

  Future<void> _completeSet(int exerciseIndex, int setIndex) async {
    await _syncSetFromFields(exerciseIndex, setIndex);
    final wasDone = _session.exercises[exerciseIndex].sets[setIndex].completed;
    if (wasDone) {
      // uncheck
      await _updateSet(exerciseIndex, setIndex, completed: false);
      return;
    }
    await _updateSet(exerciseIndex, setIndex, completed: true);
    HapticFeedback.lightImpact();
    _startRest();
  }

  void _startRest() {
    _restTimer?.cancel();
    setState(() => _restRemaining = _restSecondsDefault);
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
          'Tiempo: ${_fmtElapsed(_elapsed)}\n'
              'Series: ${_session.completedSets}/${_session.totalSets}\n\n'
              '¿Finalizar sesión?',
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

  void _openSettings() {
    final restCtrl =
    TextEditingController(text: '$_restSecondsDefault');
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
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
              const SizedBox(height: 16),
              const Text('Descanso entre series (segundos)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final s in [60, 90, 120, 180])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_fmtRest(s)),
                        selected: _restSecondsDefault == s,
                        onSelected: (_) {
                          _saveRestPref(s);
                          restCtrl.text = '$s';
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: restCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Personalizado (seg)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
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
            'Sin ejercicios en esta rutina.\nEdita el día y agrega ejercicios.',
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
            // ─── Top bar: timer + finish ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      await _persist();
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                  Icon(Icons.timer_outlined, size: 18, color: primary),
                  const SizedBox(width: 6),
                  Text(
                    _fmtElapsed(_elapsed),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Ajustes (descanso)',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: _openSettings,
                  ),
                  TextButton(
                    onPressed: _saving ? null : _finish,
                    child: Text(
                      'Terminar',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                      ),
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

            // ─── Exercise selector strip ─────────────────
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                itemCount: _session.exercises.length,
                itemBuilder: (context, i) {
                  final e = _session.exercises[i];
                  final selected = i == _exerciseIndex;
                  final allDone = e.sets.isNotEmpty &&
                      e.sets.every((s) => s.completed);
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

            // ─── Current exercise header ─────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ex.exerciseName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (ex.muscleGroup.isNotEmpty)
                    Text(
                      ex.muscleGroup,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),

            // ─── Rest banner ─────────────────────────────
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
                        onPressed: _skipRest,
                        child: const Text('Saltar'),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Sets table ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _colHeader('SERIE', flex: 2),
                  _colHeader('PREVIA', flex: 3),
                  _colHeader('KG', flex: 3),
                  _colHeader('REPS', flex: 3),
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

                  // PREVIA: previous set of same exercise or target
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

                  return Container(
                    color: s.completed
                        ? Colors.green.withValues(alpha: 0.08)
                        : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${s.setNumber}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: s.completed ? Colors.green : null,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            previa,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 40,
                            child: TextField(
                              controller: _weightCtrls[key],
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w600),
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
                              onChanged: (_) =>
                                  _syncSetFromFields(_exerciseIndex, i),
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
                              style: const TextStyle(fontWeight: FontWeight.w600),
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
                              onChanged: (_) =>
                                  _syncSetFromFields(_exerciseIndex, i),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            onPressed: () =>
                                _completeSet(_exerciseIndex, i),
                            icon: Icon(
                              s.completed
                                  ? Icons.check_circle
                                  : Icons.check_circle_outline,
                              color: s.completed ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ─── Bottom nav exercises ────────────────────
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
                      style: FilledButton.styleFrom(backgroundColor: primary),
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

  Widget _colHeader(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
