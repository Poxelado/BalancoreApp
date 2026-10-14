import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

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

class PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PeriodChip({super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Material(
        color: selected ? primary : primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WorkoutCard extends StatelessWidget {
  final String date;
  final String duration;
  final bool completed;
  final String title;
  final VoidCallback onTap;

  const WorkoutCard({super.key,
    required this.date,
    required this.duration,
    required this.completed,
    required this.title,
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
              child: Icon(
                completed ? Icons.accessibility_new : Icons.hourglass_empty,
                size: 48,
                color: completed
                    ? primary.withValues(alpha: 0.85)
                    : Colors.grey,
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

/// Fila del historial de entrenamientos para el Perfil: insignia con el día,
/// título, detalle y estado. Más legible que la antigua rejilla de iconos.
class SessionHistoryTile extends StatelessWidget {
  final String day;
  final String month;
  final String title;
  final String subtitle;
  final bool completed;
  final VoidCallback onTap;

  const SessionHistoryTile({
    super.key,
    required this.day,
    required this.month,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final accent = accentOf(context);
    final success = AppSemanticColors.of(context).success;
    final badge = completed ? success : primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: badge.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: 18,
                          height: 1,
                          fontWeight: FontWeight.bold,
                          color: badge,
                        ),
                      ),
                      Text(
                        month,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: badge,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  completed ? Icons.check_circle : Icons.timelapse,
                  size: 18,
                  color: completed ? success : accent,
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
