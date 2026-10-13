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
  /// Claves "<índiceEjercicio>_<índiceSerie>" de las series que son récord.
  final Set<String> _prKeys = {};

  /// Etiqueta de récord para la serie, o null si no lo es.
  String? _prLabelFor(int exerciseIndex, int setIndex) =>
      _prKeys.contains('$exerciseIndex' '_$setIndex') ? 'PR' : null;
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
    // Una sesión libre recién abierta y sin ejercicios no se guarda: evita
    // entradas fantasma en el historial y en el mini-player.
    if (_session.exercises.isEmpty && !_session.completed) return;
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
      await _checkPersonalRecords(exerciseIndex, setIndex);
    }
  }

  /// Recalcula los récords de la sesión y avisa si esta serie los batió.
  Future<void> _checkPersonalRecords(int exerciseIndex, int setIndex) async {
    final ex = _session.exercises[exerciseIndex];
    final set = ex.sets[setIndex];
    if (!set.completed || !set.countsForRecord || set.weight <= 0) return;
    try {
      final history = await ref.read(workoutHistoryProvider(120).future);
      if (!mounted) return;
      // La sesión en curso ya está persistida: si se contara, cada serie
      // igualaría su propio récord y nunca habría aviso. Solo el pasado.
      final past = history.where((s) => s.id != _session.id).toList();
      final records = recordsForSet(
        exercise: ex,
        set: set,
        history: past,
      );
      if (records.isEmpty) return;
      final key = '${exerciseIndex}_$setIndex';
      _prKeys.add(key);
      // Aviso visible solo para peso o 1RM: el volumen cambia casi en cada
      // serie y molestaría.
      final headline =
          records.where((r) => r.kind != PrKind.volume).toList();
      if (headline.isEmpty) return;
      setState(() {});
      final best = headline.first;
      _toast('🏆 ¡Nuevo récord en ${ex.exerciseName}! '
          '${best.label}: ${best.value.round()} kg');
    } catch (e) {
      debugPrint('workout_session: no se pudieron calcular los récords: $e');
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

  /// El descanso se guarda como instante de fin (`restEndsAt`), no como
  /// contador: así sobrevive a cerrar la app y el tiempo restante se recalcula
  /// al volver.
  void _startRest([int? seconds]) {
    _restTimer?.cancel();
    // Usa el descanso configurado en la rutina para ESTE ejercicio
    final exerciseRest = _session.exercises.isNotEmpty
        ? _session.exercises[_exerciseIndex].restSeconds
        : 60;
    final total = seconds ?? (exerciseRest > 0 ? exerciseRest : 60);
    if (total <= 0) {
      _clearRest();
      return;
    }
    final ends = DateTime.now().add(Duration(seconds: total));
    setState(() {
      _session = _session.copyWith(restEndsAt: ends);
      _restRemaining = total;
    });
    _persist(silent: true);
    _scheduleRestNotification(ends);
    _runRestTicker();
  }

  /// Un solo ticker para arranque y reanudación: en cada tick se recalcula el
  /// tiempo restante desde `restEndsAt` (no se resta de a uno, así no se
  /// desvía si el proceso quedó en segundo plano).
  void _runRestTicker() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final left = _session.restRemaining();
      if (left <= 0) {
        t.cancel();
        setState(() {
          _session = _session.copyWith(clearRest: true);
          _restRemaining = null;
        });
        _persist(silent: true);
        HapticFeedback.mediumImpact();
        _notifyRestDone();
      } else {
        setState(() => _restRemaining = left);
      }
    });
  }

  /// Añade o quita segundos al descanso en curso (±15s).
  Future<void> _adjustRest(int delta) async {
    final ends = _session.restEndsAt;
    if (ends == null) return;
    var target = ends.add(Duration(seconds: delta));
    final now = DateTime.now();
    if (target.isBefore(now)) target = now.add(const Duration(seconds: 1));
    setState(() {
      _session = _session.copyWith(restEndsAt: target);
      _restRemaining = _session.restRemaining();
    });
    await _persist(silent: true);
    _scheduleRestNotification(target);
  }

  void _clearRest() {
    _restTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _session = _session.copyWith(clearRest: true);
      _restRemaining = null;
    });
    _persist(silent: true);
  }

  void _skipRest() => _clearRest();

  /// Al reabrir una sesión con un descanso en curso, se retoma desde el
  /// tiempo que realmente queda (o se cierra si ya venció).
  void _resumeRestIfAny() {
    final ends = _session.restEndsAt;
    if (ends == null) return;
    final left = _session.restRemaining();
    if (left <= 0) {
      _session = _session.copyWith(clearRest: true);
      _persist(silent: true);
      return;
    }
    setState(() => _restRemaining = left);
    _runRestTicker();
  }

  void _scheduleRestNotification(DateTime ends) {
    final secs = ends.difference(DateTime.now()).inSeconds;
    if (secs <= 0 || secs > 3600) return;
    NotificationService.instance.showRestTimer(secs);
  }

  void _notifyRestDone() {
    // Si la app está en primer plano la vibración ya avisa; la notificación
    // local cubre el caso de tener la pantalla apagada.
    try {
      NotificationService.instance.showRestDone();
    } catch (_) {
      // Sin permisos de notificación: solo queda la vibración.
    }
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
    _applySets(exerciseIndex, sets);
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

  Future<void> _showSetActions(int exerciseIndex, int setIndex) async {
    final ex = _session.exercises[exerciseIndex];
    final isFirst = setIndex == 0;
    final isLast = setIndex == ex.sets.length - 1;
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text(
                'Serie ${ex.sets[setIndex].setNumber} · ${ex.exerciseName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              enabled: !isFirst,
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Mover arriba'),
              onTap: () => Navigator.pop(ctx, 'up'),
            ),
            ListTile(
              enabled: !isLast,
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Mover abajo'),
              onTap: () => Navigator.pop(ctx, 'down'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined),
              title: const Text('Duplicar serie'),
              onTap: () => Navigator.pop(ctx, 'duplicate'),
            ),
            ListTile(
              enabled: !isFirst,
              leading: const Icon(Icons.content_copy_outlined),
              title: const Text('Copiar valores de la anterior'),
              onTap: () => Navigator.pop(ctx, 'copy_prev'),
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('Calculadora de discos'),
              onTap: () => Navigator.pop(ctx, 'plates'),
            ),
            ListTile(
              enabled: ex.sets.length > 1,
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text('Eliminar serie',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == null) return;
    switch (action) {
      case 'up':
        await _moveSet(exerciseIndex, setIndex, -1);
        break;
      case 'down':
        await _moveSet(exerciseIndex, setIndex, 1);
        break;
      case 'duplicate':
        await _duplicateSet(exerciseIndex, setIndex);
        break;
      case 'copy_prev':
        await _copyFromPrevious(exerciseIndex, setIndex);
        break;
      case 'plates':
        await _openPlateCalculator(exerciseIndex, setIndex);
        break;
      case 'delete':
        await _deleteSet(exerciseIndex, setIndex);
        break;
    }
  }

  Future<void> _openPlateCalculator(int exerciseIndex, int setIndex) async {
    final ex = _session.exercises[exerciseIndex];
    final s = ex.sets[setIndex];
    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PlateCalculatorSheet(initialWeight: s.weight),
    );
    if (result == null) return;
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final e = exercises[exerciseIndex];
    final sets = List<WorkoutSetLog>.from(e.sets);
    sets[setIndex] = sets[setIndex].copyWith(weight: result);
    exercises[exerciseIndex] = e.copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
    _syncControllersForExercise(exercises[exerciseIndex]);
    await _persist();
  }

  /// Reasigna el número de serie (1..n) y sincroniza los controladores.
  void _applySets(int exerciseIndex, List<WorkoutSetLog> sets) {
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final ex = exercises[exerciseIndex];
    for (var i = 0; i < sets.length; i++) {
      sets[i] = sets[i].copyWith(setNumber: i + 1);
    }
    exercises[exerciseIndex] = ex.copyWith(sets: sets);
    setState(() => _session = _session.copyWith(exercises: exercises));
    _syncControllersForExercise(exercises[exerciseIndex]);
  }

  void _syncControllersForExercise(WorkoutExerciseLog ex) {
    for (final s in ex.sets) {
      final key = '${ex.exerciseId}_${s.setNumber}';
      final w = _weightCtrls.putIfAbsent(key, TextEditingController.new);
      final r = _repsCtrls.putIfAbsent(key, TextEditingController.new);
      final wText = s.weight > 0 ? _fmtWeight(s.weight) : '';
      final rText = '${s.reps}';
      if (w.text != wText) w.text = wText;
      if (r.text != rText) r.text = rText;
    }
  }

  Future<void> _moveSet(int exerciseIndex, int setIndex, int delta) async {
    final ex = _session.exercises[exerciseIndex];
    final target = setIndex + delta;
    if (target < 0 || target >= ex.sets.length) return;
    final sets = List<WorkoutSetLog>.from(ex.sets);
    final item = sets.removeAt(setIndex);
    sets.insert(target, item);
    _applySets(exerciseIndex, sets);
    await _persist();
  }

  Future<void> _duplicateSet(int exerciseIndex, int setIndex) async {
    final ex = _session.exercises[exerciseIndex];
    final sets = List<WorkoutSetLog>.from(ex.sets);
    sets.insert(setIndex + 1, sets[setIndex].copyWith(completed: false));
    _applySets(exerciseIndex, sets);
    await _persist();
  }

  Future<void> _copyFromPrevious(int exerciseIndex, int setIndex) async {
    if (setIndex <= 0) return;
    final ex = _session.exercises[exerciseIndex];
    final sets = List<WorkoutSetLog>.from(ex.sets);
    final prev = sets[setIndex - 1];
    sets[setIndex] =
        sets[setIndex].copyWith(weight: prev.weight, reps: prev.reps);
    _applySets(exerciseIndex, sets);
    await _persist();
  }

  String? _supersetPartnerName(int index) {
    final ex = _session.exercises[index];
    if (!ex.hasSuperset) return null;
    for (var i = 0; i < _session.exercises.length; i++) {
      if (i == index) continue;
      final o = _session.exercises[i];
      if (o.supersetId == ex.supersetId) return o.exerciseName;
    }
    return null;
  }

  Future<void> _editSuperset(int index) async {
    final ex = _session.exercises[index];
    final others = <int>[
      for (var i = 0; i < _session.exercises.length; i++)
        if (i != index && !_session.exercises[i].hasSuperset) i,
    ];
    final choice = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text(
                'Superset · ${ex.exerciseName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            if (ex.hasSuperset)
              ListTile(
                leading: const Icon(Icons.link_off),
                title: const Text('Quitar del superset'),
                onTap: () => Navigator.pop(ctx, -1),
              ),
            for (final i in others)
              ListTile(
                leading: const Icon(Icons.add_link),
                title: Text(
                    'Emparejar con ${_session.exercises[i].exerciseName}'),
                onTap: () => Navigator.pop(ctx, i),
              ),
            if (others.isEmpty && !ex.hasSuperset)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No hay otros ejercicios libres para emparejar.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == -1) {
      await _unpairSuperset(index);
    } else {
      await _pairSuperset(index, choice);
    }
  }

  Future<void> _pairSuperset(int a, int b) async {
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    final id = 'ss_${DateTime.now().millisecondsSinceEpoch}';
    exercises[a] = exercises[a].copyWith(supersetId: id);
    exercises[b] = exercises[b].copyWith(supersetId: id);
    setState(() => _session = _session.copyWith(exercises: exercises));
    await _persist();
  }

  Future<void> _unpairSuperset(int index) async {
    final id = _session.exercises[index].supersetId;
    if (id == null) return;
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    for (var i = 0; i < exercises.length; i++) {
      if (exercises[i].supersetId == id) {
        exercises[i] = exercises[i].copyWith(clearSuperset: true);
      }
    }
    setState(() => _session = _session.copyWith(exercises: exercises));
    await _persist();
  }

  Future<void> _copyFromLastSession() async {
    final history = await ref.read(workoutHistoryProvider(120).future);
    final candidates = history
        .where((s) => s.completed && s.id != _session.id)
        .toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (candidates.isEmpty) {
      _toast('No hay sesiones anteriores para copiar');
      return;
    }

    String keyOf(WorkoutExerciseLog e) =>
        e.exerciseId.isNotEmpty ? e.exerciseId : e.exerciseName;

    // Más reciente que comparta al menos un ejercicio.
    final currentKeys = _session.exercises.map(keyOf).toSet();
    final last = candidates.firstWhere(
      (s) => s.exercises.any((e) => currentKeys.contains(keyOf(e))),
      orElse: () => candidates.first,
    );

    final byKey = <String, WorkoutExerciseLog>{};
    for (final e in last.exercises) {
      byKey[keyOf(e)] = e;
    }

    var copied = 0;
    final exercises = List<WorkoutExerciseLog>.from(_session.exercises);
    for (var i = 0; i < exercises.length; i++) {
      final ex = exercises[i];
      final prevEx = byKey[keyOf(ex)];
      if (prevEx == null) continue;
      final sets = List<WorkoutSetLog>.from(ex.sets);
      for (var j = 0; j < sets.length; j++) {
        if (sets[j].completed) continue;
        if (j < prevEx.sets.length) {
          sets[j] = sets[j].copyWith(
            weight: prevEx.sets[j].weight,
            reps: prevEx.sets[j].reps,
          );
        }
      }
      exercises[i] = ex.copyWith(sets: sets);
      copied++;
    }

    if (copied == 0) {
      _toast('Ningún ejercicio coincide con la sesión anterior');
      return;
    }
    setState(() => _session = _session.copyWith(exercises: exercises));
    for (final ex in exercises) {
      _syncControllersForExercise(ex);
    }
    await _persist();
    setState(() {});
    _toast('Valores copiados de la sesión anterior');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
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

  /// Abre el selector y añade los ejercicios elegidos a la sesión en curso.
  /// Se usa en entrenamientos libres (y rutinas extra) para armar la sesión
  /// sobre la marcha.
  Future<void> _addExercisesToSession() async {
    final picked = await Navigator.push<List<Exercise>>(
      context,
      MaterialPageRoute(builder: (_) => const PickExerciseScreen()),
    );
    if (picked == null || picked.isEmpty) return;

    final user = ref.read(authServiceProvider).currentUser;
    final added = <WorkoutExerciseLog>[];
    for (final exercise in picked) {
      added.add(
        await buildWorkoutExerciseLog(
          repo: ref.read(profileRepositoryProvider),
          exercise: exercise,
          uid: user?.uid,
        ),
      );
    }
    if (!mounted) return;

    final exercises = [..._session.exercises, ...added];
    setState(() {
      _session = _session.copyWith(exercises: exercises);
      _exerciseIndex = exercises.length - added.length;
    });
    for (final ex in added) {
      _syncControllersForExercise(ex);
    }
    await _persist(silent: true);
  }

  Future<void> _finish() async {
    if (_session.exercises.isEmpty) {
      _toast('Añade al menos un ejercicio antes de terminar');
      return;
    }
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
        clearRest: true,
      );
      _restTimer?.cancel();
      _restRemaining = null;
      await _persist();
      if (!mounted) return;
      final history = await ref.read(workoutHistoryProvider(120).future);
      if (!mounted) return;
      final past = history.where((s) => s.id != _session.id).toList();
      final message = MotivationalMessages.pickSync(MotivationContext(
        justFinishedWorkout: true,
        firstWorkoutEver: past.where((s) => s.completed).isEmpty,
        trainedToday: true,
      ));
      if (!mounted) return;
      // Sustituye la pantalla de sesión por el resumen: el botón "Listo" cierra
      // el resumen y vuelve al hub, sin pasar por detrás.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutSummaryScreen(
            stats: computeSessionStats(_session, past),
            records: detectPersonalRecords(_session, past),
            title: message,
          ),
        ),
      );
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
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _copyFromLastSession();
                  },
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Copiar de la última sesión'),
                ),
                const SizedBox(height: 16),
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
