import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import 'exercise_detail_screen.dart';
import 'pick_exercise_screen.dart';
import '../widgets/session_rest_time_sheet.dart';
import '../widgets/session_plates_sheet.dart';
import '../widgets/session_widgets.dart';
import '../../../../core/motivation/motivational_messages.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../domain/exercise.dart';
import '../../domain/progression_rules.dart';
import '../../domain/personal_records.dart';
import '../../domain/session_stats.dart';
import '../workout_builders.dart';
import 'workout_summary_screen.dart';
import '../../../../core/theme/app_theme.dart';

part 'workout_session_logic.dart';
const _kRestSecondsKey = 'balancore_rest_seconds';

class WorkoutSessionScreen extends ConsumerStatefulWidget {
  /// Rutina semanal o extra desde la que arranca la sesión. Puede ser null
  /// para un entrenamiento libre (se usa [initialExercises] y [title]).
  final RoutineDay? routine;
  final WorkoutSession? existing;
  final DateTime? sessionDate;

  /// Ejercicios con los que arranca una sesión libre (sin rutina).
  final List<WorkoutExerciseLog>? initialExercises;

  /// Título del entreno libre ("Entrenamiento libre" por defecto).
  final String title;

  /// Nombre de día para el entreno libre; por defecto, el día de hoy.
  final String dayName;

  /// Muestra el botón "Añadir ejercicio" dentro de la sesión.
  final bool allowAddExercises;

  const WorkoutSessionScreen({
    super.key,
    this.routine,
    this.existing,
    this.sessionDate,
    this.initialExercises,
    this.title = '',
    this.dayName = '',
    this.allowAddExercises = false,
  });

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen>
    with _WorkoutSessionLogic {

  @override
  void initState() {
    super.initState();
    if (widget.existing != null && !widget.existing!.completed) {
      _session = widget.existing!;
      _elapsedSeconds = widget.existing!.elapsedSeconds;
      _paused = widget.existing!.isPaused;
    } else if (widget.routine != null) {
      _session = WorkoutSession.fromRoutine(
        widget.routine!,
        date: widget.sessionDate,
      );
      _elapsedSeconds = 0;
      _paused = false;
    } else {
      // Entrenamiento libre: sin rutina, sin ejercicios o con los elegidos.
      _session = WorkoutSession(
        id: WorkoutSession.newSessionId(),
        dayName: widget.dayName.isEmpty
            ? WorkoutSession.weekdayName()
            : widget.dayName,
        title: widget.title.isEmpty ? 'Entrenamiento libre' : widget.title,
        startedAt: widget.sessionDate ?? DateTime.now(),
        exercises: widget.initialExercises ?? const [],
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
    // Retoma un descanso que quedó en curso (p. ej. se cerró la app).
    _resumeRestIfAny();
    // Guardar al entrar para que exista en historial / mini player
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _persist();
      _loadProgression();
    });
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

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final cardBg = Theme.of(context).colorScheme.surface;

    if (_session.exercises.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: const Text('Entrenamiento'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fitness_center,
                  size: 56,
                  color: primary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.allowAddExercises
                      ? 'Este entrenamiento está vacío.\n'
                          'Añade tu primer ejercicio.'
                      : 'Sin ejercicios en esta rutina.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
                if (widget.allowAddExercises) ...[
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _addExercisesToSession,
                    style: FilledButton.styleFrom(backgroundColor: primary),
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir ejercicio'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final ex = _session.exercises[_exerciseIndex];
    final progress = _session.totalSets == 0
        ? 0.0
        : _session.completedSets / _session.totalSets;
    final sug = _sugFor(ex);

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
                    color: _paused ? Colors.orange : accentOf(context),
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
                    tooltip: 'Ajustes',
                    onPressed: _openSettings,
                  ),
                  TextButton(
                    onPressed: _saving ? null : _finish,
                    child: Text(
                      'Terminar',
                      style: TextStyle(
                          color: accentOf(context), fontWeight: FontWeight.bold),
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
                  color: accentOf(context),
                ),
              ),
            ),
            ExerciseSelectorStrip(
              exercises: _session.exercises,
              selectedIndex: _exerciseIndex,
              primary: primary,
              cardBg: cardBg,
              onSelect: (i) => setState(() => _exerciseIndex = i),
              onAdd: widget.allowAddExercises ? _addExercisesToSession : null,
            ),
            ExerciseHeaderCard(
              ex: ex,
              primary: primary,
              supersetPartner: _supersetPartnerName(_exerciseIndex),
              onOpenDetail: () {
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
              onEditRest: () => _editExerciseRest(_exerciseIndex),
              onEditNotes: _editExerciseNotes,
              onEditSuperset: () => _editSuperset(_exerciseIndex),
              onSetRpe: (r) => _setExerciseRpe(_exerciseIndex, r),
            ),
            if (sug != null)
              ProgressionBanner(
                suggestion: sug,
                primary: primary,
                onApply: () => _applySuggestionForExercise(_exerciseIndex),
              ),
            if (_restRemaining != null)
              RestBanner(
                remaining: _restRemaining!,
                primary: primary,
                onSkip: _skipRest,
                onAdjust: _adjustRest,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 8, 20, 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Text(
                      'SERIE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _h('PREVIA', 3),
                  _h('KG', 3),
                  _h('REPS', 3),
                  const SizedBox(width: 72),
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

                  final String previa = sug != null ? sug.previaLabel(i) : '—';
                  final hintW = sug != null && sug.weightFor(i) > 0
                      ? _fmtWeight(sug.weightFor(i))
                      : (s.weight > 0 ? _fmtWeight(s.weight) : null);
                  final hintR = sug != null && sug.repsFor(i) > 0
                      ? '${sug.repsFor(i)}'
                      : (s.reps > 0 ? '${s.reps}' : null);

                  return SetLogRow(
                    dismissKey: '${ex.exerciseId}_${s.setNumber}_$i',
                    s: s,
                    weightCtrl: _weightCtrls[key]!,
                    repsCtrl: _repsCtrls[key]!,
                    previa: previa,
                    hintW: hintW,
                    hintR: hintR,
                    cardBg: cardBg,
                    onWeightChanged: (_) =>
                        _syncFromField(_exerciseIndex, i, isWeight: true),
                    onRepsChanged: (_) =>
                        _syncFromField(_exerciseIndex, i, isWeight: false),
                    onChangeType: (t) => _changeSetType(_exerciseIndex, i, t),
                    onEditNote: () => _editSetNote(_exerciseIndex, i),
                    onLongPress: () => _showSetActions(_exerciseIndex, i),
                    onToggle: () => _toggleComplete(_exerciseIndex, i),
                    prLabel: _prLabelFor(_exerciseIndex, i),
                    onDismissed: () => _deleteSet(_exerciseIndex, i),
                    confirmDismiss: () async {
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
                      style: FilledButton.styleFrom(backgroundColor: primary),
                      onPressed: _exerciseIndex < _session.exercises.length - 1
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
}
