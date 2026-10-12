part of 'workout_session_screen.dart';

mixin _WorkoutSessionLogic on ConsumerState<WorkoutSessionScreen> {
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
  /// exerciseId -> suggestion from history
  final Map<String, ProgressionSuggestion> _suggestions = {};
  Future<void> _loadProgression() async {
    try {
      final history = await ref.read(workoutHistoryProvider(120).future);
      final map = <String, ProgressionSuggestion>{};
      for (final ex in _session.exercises) {
        final target = ex.sets.isNotEmpty
            ? (ex.sets.first.reps > 0 ? ex.sets.first.reps : 10)
            : 10;
        final sug = ProgressionRules.suggest(
          exerciseId: ex.exerciseId,
          exerciseName: ex.exerciseName,
          setCount: ex.sets.length,
          targetReps: target,
          history: history,
        );
        // Clave por id o por nombre si id vacío
        final key = ex.exerciseId.isNotEmpty ? ex.exerciseId : ex.exerciseName;
        if (sug != null) map[key] = sug;
      }
      if (!mounted) return;
      setState(() {
        _suggestions
          ..clear()
          ..addAll(map);
      });
      // Campos vacíos + hint desvanecido (solo series no completadas)
      if (widget.existing == null ||
          !_session.exercises.any((e) => e.sets.any((s) => s.completed))) {
        for (final ex in _session.exercises) {
          for (final s in ex.sets) {
            if (s.completed) continue;
            final key = _key(ex, s);
            _weightCtrls[key]?.clear();
            _repsCtrls[key]?.clear();
          }
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('workout_session: no se pudieron limpiar las series: $e');
    }
  }

  ProgressionSuggestion? _sugFor(WorkoutExerciseLog ex) {
    if (_suggestions.containsKey(ex.exerciseId)) {
      return _suggestions[ex.exerciseId];
    }
    return _suggestions[ex.exerciseName];
  }

  void _applySuggestionForExercise(int exerciseIndex) {
    final ex = _session.exercises[exerciseIndex];
    final sug = _sugFor(ex);
    if (sug == null) return;
    final exercises = [..._session.exercises];
    final sets = [...ex.sets];
    for (var i = 0; i < sets.length; i++) {
      final w = i < sug.weights.length ? sug.weights[i] : sug.weights.last;
      final r = i < sug.reps.length ? sug.reps[i] : sug.reps.last;
      sets[i] = sets[i].copyWith(weight: w, reps: r);
      final key = '${ex.exerciseId}_${sets[i].setNumber}';
      _weightCtrls[key]?.text = w > 0 ? _fmtWeight(w) : '';
      _repsCtrls[key]?.text = '$r';
    }
    exercises[exerciseIndex] = ex.copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
    _persist(silent: true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sug.message)),
    );
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

  String _fmtRest(int sec) => fmtRest(sec);

  String _key(WorkoutExerciseLog ex, WorkoutSetLog s) =>
      '${ex.exerciseId}_${s.setNumber}';

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
    final ex = _session.exercises[exerciseIndex];
    final s = ex.sets[setIndex];
    final key = _key(ex, s);
    final sug = _sugFor(ex);

    // Texto del campo; si vacío, usar sugerencia / previa (desvanecido → sólido)
    var wText = (_weightCtrls[key]?.text ?? '').trim();
    var rText = (_repsCtrls[key]?.text ?? '').trim();

    double w = double.tryParse(wText.replaceAll(',', '.')) ?? 0;
    int r = int.tryParse(rText) ?? 0;

    if (!s.completed) {
      // Al marcar: confirmar valores sugeridos si el usuario no escribió
      if (w <= 0 && sug != null) {
        w = sug.weightFor(setIndex);
        if (w <= 0 && setIndex < sug.previousWeights.length) {
          w = sug.previousWeights[setIndex];
        }
      }
      if (w <= 0) w = s.weight;

      if (r <= 0 && sug != null) {
        r = sug.repsFor(setIndex);
        if (r <= 0 && setIndex < sug.previousReps.length) {
          r = sug.previousReps[setIndex];
        }
      }
      if (r <= 0) r = s.reps > 0 ? s.reps : 0;

      // Volcar a los campos (ya no desvanecidos)
      if (w > 0) _weightCtrls[key]?.text = _fmtWeight(w);
      if (r > 0) _repsCtrls[key]?.text = '$r';
    } else {
      if (w <= 0) w = s.weight;
      if (r <= 0) r = s.reps;
    }

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


  Future<void> _editExerciseRest(int exerciseIndex) async {
    final ex = _session.exercises[exerciseIndex];
    final sec = ex.restSeconds > 0 ? ex.restSeconds : 60;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SessionRestTimeSheet(
        initialSeconds: sec,
        exerciseName: ex.exerciseName,
      ),
    );
    if (chosen == null) return;
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    exercises[exerciseIndex] = ex.copyWith(restSeconds: chosen);
    setState(() => _session = _session.copyWith(exercises: exercises));
    await _persist(silent: true);
    final user = ref.read(authServiceProvider).currentUser;
    if (user != null && ex.exerciseId.isNotEmpty) {
      try {
        await ref.read(profileRepositoryProvider).saveExerciseDefault(
          uid: user.uid,
          exerciseId: ex.exerciseId,
          plannedSets: [
            for (final s in ex.sets)
              PlannedSet(weight: s.weight, reps: s.reps),
          ],
          restSeconds: chosen,
          notes: ex.notes,
        );
      } catch (e) {
        debugPrint('workout_session: no se pudo guardar la serie planificada: $e');
      }
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

  /// Solo afecta la sesión actual, NO la plantilla de rutina.
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
      sets[i] = sets[i].copyWith(setNumber: i + 1);
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

  Future<void> _changeSetType(
      int exerciseIndex, int setIndex, SetType type) async {
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final ex = exercises[exerciseIndex];
    final sets = List<WorkoutSetLog>.from(ex.sets);
    sets[setIndex] = sets[setIndex].copyWith(type: type);
    exercises[exerciseIndex] = ex.copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
    await _persist(silent: true);
  }

  Future<void> _editSetNote(int exerciseIndex, int setIndex) async {
    final ex = _session.exercises[exerciseIndex];
    final s = ex.sets[setIndex];
    final ctrl = TextEditingController(text: s.note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Nota · serie ${s.setNumber}'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Sensaciones, técnica, ajustes...',
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
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final e = exercises[exerciseIndex];
    final sets = List<WorkoutSetLog>.from(e.sets);
    sets[setIndex] = sets[setIndex].copyWith(note: ctrl.text.trim());
    exercises[exerciseIndex] = e.copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
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
        final history =
        await ref.read(workoutHistoryProvider(120).future);
        final completedBefore = history
            .where((s) => s.completed && s.id != _session.id)
            .length;
        MotivationalMessages.pickSync(MotivationContext(
          justFinishedWorkout: true,
          firstWorkoutEver: completedBefore == 0,
          trainedToday: true,
        ));
        if (mounted) Navigator.pop(context);
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

  Future<void> _setExerciseRpe(int exerciseIndex, int rpe) async {
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final ex = exercises[exerciseIndex];
    exercises[exerciseIndex] = ex.copyWith(rpe: rpe);
    setState(() => _session = _session.copyWith(exercises: exercises));
    await _persist(silent: true);
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
