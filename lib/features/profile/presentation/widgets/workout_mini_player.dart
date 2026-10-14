import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../training/presentation/screens/workout_session_screen.dart';
import '../../../../core/theme/app_theme.dart';

/// Mini reproductor flotante del entrenamiento en curso. Vive encima de la
/// barra inferior y persiste mientras haya una sesión activa, en cualquier
/// pestaña. Se oculta solo si no hay sesión.
class WorkoutMiniPlayer extends ConsumerStatefulWidget {
  const WorkoutMiniPlayer({super.key});

  @override
  ConsumerState<WorkoutMiniPlayer> createState() => _WorkoutMiniPlayerState();
}

class _WorkoutMiniPlayerState extends ConsumerState<WorkoutMiniPlayer> {
  Timer? _timer;
  int _elapsed = 0;
  String? _sessionId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<WorkoutSession?>>(
      activeWorkoutSessionProvider,
      (_, next) => _apply(next.valueOrNull),
      fireImmediately: true,
    );
  }

  void _apply(WorkoutSession? s) {
    if (!mounted) return;
    setState(() {
      if (s != null) {
        if (_sessionId != s.id) {
          _sessionId = s.id;
          _elapsed = s.elapsedSeconds;
        } else if (s.elapsedSeconds > _elapsed) {
          _elapsed = s.elapsedSeconds;
        }
      }
      _busy = false;
    });
    _syncTimer(s);
  }

  void _syncTimer(WorkoutSession? s) {
    _timer?.cancel();
    if (s == null || s.completed || s.isPaused) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(int sec) {
    final h = sec ~/ 3600;
    final m = ((sec % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Future<void> _resume(WorkoutSession session) async {
    if (_busy) return;
    _busy = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          existing: session,
          allowAddExercises: true,
        ),
      ),
    );
    if (!mounted) return;
    ref.invalidate(activeWorkoutSessionProvider);
    ref.invalidate(routinesProvider);
  }

  Future<void> _togglePause(WorkoutSession session) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    final updated = session.copyWith(isPaused: !session.isPaused);
    await ref
        .read(profileRepositoryProvider)
        .saveWorkoutSession(user.uid, updated);
    ref.invalidate(activeWorkoutSessionProvider);
  }

  Future<void> _cancel(WorkoutSession session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar entrenamiento'),
        content: const Text(
          'Se eliminará esta sesión en curso. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sí, cancelar',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    await ref
        .read(profileRepositoryProvider)
        .deleteWorkoutSession(user.uid, session.id);
    if (!mounted) return;
    ref.invalidate(activeWorkoutSessionProvider);
    for (final d in [30, 90, 180, 365, 36500]) {
      ref.invalidate(workoutHistoryProvider(d));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sesión cancelada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeWorkoutSessionProvider).valueOrNull;
    final active = session != null && !session.completed;

    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: active
            ? _pill(context, session)
            : const SizedBox.shrink(key: ValueKey('mini-empty')),
      ),
    );
  }

  Widget _pill(BuildContext context, WorkoutSession session) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentOf(context);
    return Padding(
      key: const ValueKey('mini-active'),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(16),
        color: cs.surfaceContainerHighest,
        shadowColor: Colors.black54,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _resume(session),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: session.isPaused
                    ? AppSemanticColors.of(context).warning
                    : accent,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: session.isPaused
                      ? AppSemanticColors.of(context).warning
                      : accent,
                  child: Icon(
                    session.isPaused ? Icons.pause : Icons.fitness_center,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.isPaused
                            ? 'Sesión en pausa'
                            : 'Entrenamiento en curso',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${session.title.isEmpty ? session.dayName : session.title}'
                        ' · ${_fmt(_elapsed)}'
                        ' · ${session.completedSets}/${session.totalSets} series',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: session.isPaused ? 'Reanudar' : 'Pausar',
                  icon: Icon(
                    session.isPaused ? Icons.play_arrow : Icons.pause,
                    color: accent,
                  ),
                  onPressed: () => _togglePause(session),
                ),
                IconButton(
                  tooltip: 'Cancelar',
                  icon: Icon(Icons.close, color: cs.error),
                  onPressed: () => _cancel(session),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
