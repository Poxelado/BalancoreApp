import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../../core/first_run/first_run_prefs.dart';
import '../../../../core/theme/app_theme.dart';

const int kMlPerGlass = 200;
const int kWaterGoalMl = 2000;

class FirstRunTutorialDialog extends StatefulWidget {
  const FirstRunTutorialDialog({super.key});

  @override
  State<FirstRunTutorialDialog> createState() =>
      FirstRunTutorialDialogState();
}

class FirstRunTutorialDialogState extends State<FirstRunTutorialDialog> {
  final _page = PageController();
  int _index = 0;

  static const _pages = <({
  IconData icon,
  String title,
  String body
  })>[
    (
    icon: Icons.home_outlined,
    title: 'Tu día en un vistazo',
    body:
    'En Inicio ves calorías, proteína, si toca entrenar, tu racha y accesos rápidos.',
    ),
    (
    icon: Icons.fitness_center,
    title: 'Rutina',
    body:
    'Arma o elige tu rutina, registra series, pesos y descansos. La progresión te sugiere cuándo subir.',
    ),
    (
    icon: Icons.restaurant_menu,
    title: 'Nutrición',
    body:
    'Registra comidas, agua y sueño. Tus macros del día se comparan con tu objetivo.',
    ),
    (
    icon: Icons.insights,
    title: 'Progreso',
    body:
    'Revisa constancia, entrenos, hábitos y tendencias de macros por semana o mes.',
    ),
    (
    icon: Icons.local_fire_department,
    title: 'Racha diaria',
    body:
    'Cumple 3 de 4 hábitos (entreno, agua, sueño, comida) para mantener la racha activa.',
    ),
  ];

  Color _tutorialColor(BuildContext context, int i) {
    final s = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    final palette = [
      s.primary,
      sem.info,
      sem.warning,
      s.secondary,
      s.tertiary,
    ];
    return palette[i % palette.length];
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await FirstRunPrefs.markTutorialDone();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _pages.length - 1;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 260,
              child: PageView.builder(
                controller: _page,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  final color = _tutorialColor(context, i);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Icon(p.icon, size: 36, color: color),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          p.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          p.body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.35,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                    (i) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _index
                        ? _tutorialColor(context, i)
                        : Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (!last)
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Saltar'),
                    )
                  else
                    const SizedBox(width: 64),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (last) {
                        _finish();
                      } else {
                        _page.nextPage(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: Text(last ? 'Empezar' : 'Siguiente'),
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

class MacroProgressCard extends StatelessWidget {
  final String title;
  final int value;
  final int goal;
  final String unit;
  final Color color;
  final IconData icon;
  final Color cardBg;

  const MacroProgressCard({super.key,
    required this.title,
    required this.value,
    required this.goal,
    required this.unit,
    required this.color,
    required this.icon,
    required this.cardBg,
  });

  @override
  Widget build(BuildContext context) {
    final pct = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            '/ $goal $unit',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.15),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class TodayTrainingCard extends StatelessWidget {
  final Color primary;
  final Color cardBg;
  final bool trainedToday;
  final bool pendingSession;
  final String? sessionTitle;
  final VoidCallback onGoRoutine;

  const TodayTrainingCard({super.key,
    required this.primary,
    required this.cardBg,
    required this.trainedToday,
    required this.pendingSession,
    required this.sessionTitle,
    required this.onGoRoutine,
  });

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String title;
    late final String subtitle;
    late final Color accent;

    if (trainedToday) {
      icon = Icons.check_circle;
      title = 'Entreno completado';
      subtitle = (sessionTitle != null && sessionTitle!.isNotEmpty)
          ? sessionTitle!
          : 'Buen trabajo hoy';
      accent = AppSemanticColors.of(context).success;
    } else if (pendingSession) {
      icon = Icons.play_circle_outline;
      title = 'Entreno en curso';
      subtitle = (sessionTitle != null && sessionTitle!.isNotEmpty)
          ? 'Continúa: $sessionTitle'
          : 'Sigue en la pestaña Rutina';
      accent = primary;
    } else {
      icon = Icons.fitness_center;
      title = 'Entreno de hoy';
      subtitle = 'Abre Rutina para empezar tu sesión';
      accent = primary;
    }

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onGoRoutine,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}

class QuickAccess extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickAccess({super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StreakIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;

  const StreakIcon({super.key,
    required this.icon,
    required this.active,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: 20,
      color: active ? activeColor : Colors.grey.shade500,
    );
  }
}

class CompactHabit extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const CompactHabit({super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.onMinus,
    this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          MiniBtn(icon: Icons.remove, label: 'Quitar', onTap: onMinus),
          const SizedBox(width: 4),
          MiniBtn(icon: Icons.add, label: 'Añadir', onTap: onPlus),
        ],
      ),
    );
  }
}

class MiniBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;

  const MiniBtn({super.key, required this.icon, this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}


/// Usado por [RoutineTab] (import home_tab.dart) para sincronizar agua con Inicio.
class CompactWaterControl extends ConsumerWidget {
  const CompactWaterControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(todayLogProvider);
    return logAsync.when(
      loading: () => const SizedBox(
        height: 52,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('$e'),
      data: (log) {
        final profile = ref.watch(userProfileProvider).value;
        final maxGlasses = profile?.targetWaterGlasses ?? 10;
        final goalMl = profile != null && profile.targetWaterMl > 0
            ? profile.targetWaterMl
            : (profile != null
            ? UserProfile.calculateWaterMl(weightKg: profile.currentWeight)
            : kWaterGoalMl);

        final ml = log.waterGlasses * kMlPerGlass;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
          ),
          child: CompactHabit(
            icon: Icons.water_drop,
            iconColor: const Color(0xFF2196F3),
            label: ml > 0
                ? '${ml}ml / ${(goalMl / 1000).toStringAsFixed(1)}L'
                : '0ml / ${(goalMl / 1000).toStringAsFixed(1)}L',
            onMinus: log.waterGlasses > 0
                ? () async {
              final uid =
                  ref.read(authServiceProvider).currentUser?.uid;
              if (uid == null) return;
              await ref.read(profileRepositoryProvider).updateTodayLog(
                uid,
                waterGlasses: log.waterGlasses - 1,
              );
              invalidateProgressData(ref);
            }
                : null,
            onPlus: log.waterGlasses < maxGlasses
                ? () async {
              final uid =
                  ref.read(authServiceProvider).currentUser?.uid;
              if (uid == null) return;
              await ref.read(profileRepositoryProvider).updateTodayLog(
                uid,
                waterGlasses: log.waterGlasses + 1,
              );
              invalidateProgressData(ref);
            }
                : null,
          ),
        );
      },
    );
  }
}

class MotivationBanner extends StatelessWidget {
  final String message;
  const MotivationBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 18, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
