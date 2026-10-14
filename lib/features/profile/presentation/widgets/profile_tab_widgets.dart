import 'package:flutter/material.dart';

import '../../../training/domain/workout_share_metrics.dart';
import '../../../training/presentation/widgets/muscle_body_map.dart';

class StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const StatColumn({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

/// Tarjeta del historial: la figura con los músculos trabajados de la sesión
/// (estilo Symmetry), la fecha, el título y la duración.
class WorkoutCard extends StatelessWidget {
  final String date;
  final String duration;
  final bool completed;
  final String title;
  final Map<BodyRegion, double>? intensity;
  final VoidCallback onTap;

  const WorkoutCard({super.key,
    required this.date,
    required this.duration,
    required this.completed,
    required this.title,
    this.intensity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: isDark
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                date,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? Colors.white70
                      : primary.withValues(alpha: 0.8),
                ),
              ),
            ),
            Expanded(
              child: intensity == null
                  ? Icon(
                      completed
                          ? Icons.accessibility_new
                          : Icons.hourglass_empty,
                      size: 48,
                      color: completed
                          ? primary.withValues(alpha: 0.85)
                          : Colors.grey,
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      child: MuscleBodyMap(
                        intensity: intensity!,
                        base: isDark
                            ? Colors.white.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.06),
                        trained: primary,
                        outline: isDark
                            ? Colors.white.withValues(alpha: 0.30)
                            : primary.withValues(alpha: 0.22),
                        front: true,
                      ),
                    ),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isDark
                    ? Colors.white54
                    : primary.withValues(alpha: 0.7),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                duration,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
