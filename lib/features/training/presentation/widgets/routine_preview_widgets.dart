import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/exercise.dart';

/// Previsualización de una rutina generada (IA o reglas).
///
/// Muestra cada día en una tarjeta con un carrusel horizontal deslizable de
/// miniaturas de ejercicios: cada miniatura lleva la imagen del ejercicio,
/// su nombre y las series × reps. Pensado para reutilizarse en el asistente
/// de rutina y en el onboarding.
class RoutinePreviewCard extends StatelessWidget {
  final RoutineDay day;
  final ValueChanged<RoutineExercise>? onExerciseTap;

  const RoutinePreviewCard({super.key, required this.day, this.onExerciseTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentOf(context);
    final exercises = day.exercises;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    day.day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    day.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '${exercises.length} ej.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            if (day.duration.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    day.duration,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            if (exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Día de descanso',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              )
            else
              _ExerciseCarousel(
                exercises: exercises,
                onExerciseTap: onExerciseTap,
              ),
          ],
        ),
      ),
    );
  }
}

/// Carrusel horizontal de miniaturas de ejercicios con puntos indicadores.
class _ExerciseCarousel extends StatefulWidget {
  final List<RoutineExercise> exercises;
  final ValueChanged<RoutineExercise>? onExerciseTap;

  const _ExerciseCarousel({required this.exercises, this.onExerciseTap});

  @override
  State<_ExerciseCarousel> createState() => _ExerciseCarouselState();
}

class _ExerciseCarouselState extends State<_ExerciseCarousel> {
  late final PageController _controller;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.72);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.exercises.length;
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _controller,
            itemCount: n,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _ExerciseMiniCard(
                  exercise: widget.exercises[i],
                  onTap: widget.onExerciseTap == null
                      ? null
                      : () => widget.onExerciseTap!(widget.exercises[i]),
                ),
              );
            },
          ),
        ),
        if (n > 1) ...[
          const SizedBox(height: 8),
          _Dots(count: n, current: _current),
        ],
      ],
    );
  }
}

/// Miniatura ancha de un ejercicio: imagen arriba, nombre y series × reps abajo.
class _ExerciseMiniCard extends StatelessWidget {
  final RoutineExercise exercise;
  final VoidCallback? onTap;

  const _ExerciseMiniCard({required this.exercise, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentOf(context);
    final e = ExerciseCatalog.byId(exercise.exerciseId);
    final url = e?.imageUrl;
    final sets = exercise.effectiveSets.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: accent.withValues(alpha: 0.06),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url != null)
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        semanticLabel: exercise.exerciseName,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => _fallback(accent),
                      )
                    else
                      _fallback(accent),
                    if (exercise.muscleGroup.trim().isNotEmpty)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            exercise.muscleGroup,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      exercise.exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.repeat, size: 13, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          sets == 1 ? '1 serie' : '$sets series',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.fitness_center, size: 13, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          '${exercise.reps} reps',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback(Color accent) => Center(
        child: Icon(
          Icons.fitness_center,
          size: 44,
          color: accent.withValues(alpha: 0.5),
        ),
      );
}

class _Dots extends StatelessWidget {
  final int count;
  final int current;

  const _Dots({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: i == current ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == current
                  ? accent
                  : accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
