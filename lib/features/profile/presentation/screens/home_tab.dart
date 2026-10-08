import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../../core/notifications/smart_schedule.dart';
import '../../../../core/notifications/inactivity_check.dart';
import '../../../../core/first_run/first_run_prefs.dart';

const int kMlPerGlass = 200;
const int kWaterGoalMl = 2000;

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  bool _tutorialChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  Future<void> _maybeShowTutorial() async {
    if (_tutorialChecked) return;
    _tutorialChecked = true;
    final done = await FirstRunPrefs.isTutorialDone();
    if (done || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _FirstRunTutorialDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshSmartNotifications(ref);
      checkInactivityAndNotify(ref);
    });

    final logAsync = ref.watch(todayLogProvider);
    final trainAsync = ref.watch(todayWorkoutSessionProvider);
    final historyAsync = ref.watch(dailyLogsHistoryProvider(60));
    final workoutsAsync = ref.watch(workoutHistoryProvider(60));
    final cardBg = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.65);

    return logAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (log) {
        final profile = ref.watch(userProfileProvider).value;
        final maxGlasses = profile?.targetWaterGlasses ?? 10;
        final goalMl = profile != null && profile.targetWaterMl > 0
            ? profile.targetWaterMl
            : (profile != null
            ? UserProfile.calculateWaterMl(weightKg: profile.currentWeight)
            : kWaterGoalMl);
        final session = trainAsync.valueOrNull;
        final trainedToday = session != null && session.completed;
        final hasWater = log.waterGlasses > 0;
        final hasSleep = log.sleepHours > 0;
        final hasFood =
            log.meals.isNotEmpty || log.consumedCalories > 0;
        final doneCount = [
          trainedToday,
          hasWater,
          hasSleep,
          hasFood,
        ].where((e) => e).length;
        final streakReady = doneCount >= 3;

        final streak = _computeStreak(
          historyAsync.valueOrNull ?? [],
          workoutsAsync.valueOrNull ?? [],
          log,
          trainedToday,
        );

        final ml = log.waterGlasses * kMlPerGlass;
        final sleepLabel = log.sleepHours <= 0
            ? '— h'
            : (log.sleepHours == log.sleepHours.roundToDouble()
            ? '${log.sleepHours.toInt()} h'
            : '${log.sleepHours.toStringAsFixed(1)} h');

        final targetKcal = profile?.targetCalories ?? 2000;
        final targetProtein = (profile?.targetProtein ?? 0) > 0
            ? profile!.targetProtein
            : (profile != null
            ? UserProfile.calculateMacros(
          weight: profile.currentWeight,
          calories: targetKcal,
          goal: profile.goal,
        ).protein
            : 150);
        final consumedKcal = log.consumedCalories;
        final consumedProtein = log.proteinGrams;
        final pendingSession = session != null && !session.completed;

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              'Inicio',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _greeting(profile),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 34,
                          color: streakReady
                              ? const Color(0xFFFF6D00)
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$streak',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: streakReady
                                ? const Color(0xFFFF6D00)
                                : Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'días',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        _StreakIcon(
                          icon: Icons.fitness_center,
                          active: trainedToday,
                          activeColor: const Color(0xFFE91E63),
                        ),
                        const SizedBox(width: 8),
                        _StreakIcon(
                          icon: Icons.water_drop,
                          active: hasWater,
                          activeColor: const Color(0xFF2196F3),
                        ),
                        const SizedBox(width: 8),
                        _StreakIcon(
                          icon: Icons.bedtime,
                          active: hasSleep,
                          activeColor: const Color(0xFF7E57C2),
                        ),
                        const SizedBox(width: 8),
                        _StreakIcon(
                          icon: Icons.restaurant,
                          active: hasFood,
                          activeColor: const Color(0xFFFF9800),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.grey.withValues(alpha: 0.25),
                  ),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _CompactHabit(
                            icon: Icons.water_drop,
                            iconColor: const Color(0xFF2196F3),
                            label: ml > 0
                                ? '${ml}ml / ${(goalMl / 1000).toStringAsFixed(1)}L'
                                : '0ml / ${(goalMl / 1000).toStringAsFixed(1)}L',
                            onMinus: log.waterGlasses > 0
                                ? () => _setWater(ref, log.waterGlasses - 1)
                                : null,
                            onPlus: log.waterGlasses < maxGlasses
                                ? () => _setWater(ref, log.waterGlasses + 1)
                                : null,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: Colors.grey.withValues(alpha: 0.25),
                        ),
                        Expanded(
                          child: _CompactHabit(
                            icon: Icons.bedtime,
                            iconColor: const Color(0xFF7E57C2),
                            label: sleepLabel,
                            onMinus: log.sleepHours > 0
                                ? () => _setSleep(
                              ref,
                              (log.sleepHours - 0.5).clamp(0.0, 24.0),
                            )
                                : null,
                            onPlus: log.sleepHours < 16
                                ? () => _setSleep(
                              ref,
                              (log.sleepHours + 0.5).clamp(0.0, 24.0),
                            )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // 1) Racha + hábitos (agua / sueño)
          const SizedBox(height: 4),
          Text(
            '3 de 4 hábitos del día mantienen la racha',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
            const SizedBox(height: 8),
            // 3) Calorías + proteína
            Text(
              'Nutrición y entreno de hoy',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MacroProgressCard(
                    title: 'Calorías',
                    value: consumedKcal,
                    goal: targetKcal,
                    unit: 'kcal',
                    color: const Color(0xFFFF9800),
                    icon: Icons.local_fire_department_outlined,
                    cardBg: cardBg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MacroProgressCard(
                    title: 'Proteína',
                    value: consumedProtein,
                    goal: targetProtein,
                    unit: 'g',
                    color: const Color(0xFF4CAF50),
                    icon: Icons.egg_outlined,
                    cardBg: cardBg,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            _TodayTrainingCard(
              primary: primary,
              cardBg: cardBg,
              trainedToday: trainedToday,
              pendingSession: pendingSession,
              sessionTitle: session?.title,
              onGoRoutine: () =>
              ref.read(shellTabProvider.notifier).state = 3,
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),

            // 4) Accesos rápidos
            Text(
              'Accesos rápidos',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuickAccess(
                    icon: Icons.fitness_center,
                    label: 'Rutina',
                    color: const Color(0xFFE91E63),
                    onTap: () =>
                    ref.read(shellTabProvider.notifier).state = 3,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAccess(
                    icon: Icons.restaurant_menu,
                    label: 'Nutrición',
                    color: const Color(0xFFFF9800),
                    onTap: () =>
                    ref.read(shellTabProvider.notifier).state = 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuickAccess(
                    icon: Icons.insights,
                    label: 'Progreso',
                    color: const Color(0xFF5C6BC0),
                    onTap: () =>
                    ref.read(shellTabProvider.notifier).state = 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickAccess(
                    icon: Icons.person_outline,
                    label: 'Perfil',
                    color: primary,
                    onTap: () =>
                    ref.read(shellTabProvider.notifier).state = 4,
                  ),
                ),
              ],
            ),

          ],
        );
      },
    );
  }

  String _greeting(UserProfile? profile) {
    final hour = DateTime.now().hour;
    final saludo = hour < 12
        ? 'Buenos días'
        : (hour < 19 ? 'Buenas tardes' : 'Buenas noches');
    final name = profile?.displayName?.trim();
    if (name != null && name.isNotEmpty) return '$saludo, $name';
    final user = profile?.username;
    if (user != null && user.isNotEmpty) return '$saludo, @$user';
    return saludo;
  }

  Future<void> _setWater(WidgetRef ref, int glasses) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    await ref
        .read(profileRepositoryProvider)
        .updateTodayLog(uid, waterGlasses: glasses);
    invalidateProgressData(ref);
  }

  Future<void> _setSleep(WidgetRef ref, double hours) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    await ref
        .read(profileRepositoryProvider)
        .updateTodayLog(uid, sleepHours: hours);
    invalidateProgressData(ref);
  }
}

class _FirstRunTutorialDialog extends StatefulWidget {
  const _FirstRunTutorialDialog();

  @override
  State<_FirstRunTutorialDialog> createState() =>
      _FirstRunTutorialDialogState();
}

class _FirstRunTutorialDialogState extends State<_FirstRunTutorialDialog> {
  final _page = PageController();
  int _index = 0;

  static const _pages = <({
  IconData icon,
  String title,
  String body,
  Color color
  })>[
    (
    icon: Icons.home_outlined,
    title: 'Tu día en un vistazo',
    body:
    'En Inicio ves calorías, proteína, si toca entrenar, tu racha y accesos rápidos.',
    color: Color(0xFF6B1228),
    ),
    (
    icon: Icons.fitness_center,
    title: 'Rutina',
    body:
    'Arma o elige tu rutina, registra series, pesos y descansos. La progresión te sugiere cuándo subir.',
    color: Color(0xFFE91E63),
    ),
    (
    icon: Icons.restaurant_menu,
    title: 'Nutrición',
    body:
    'Registra comidas, agua y sueño. Tus macros del día se comparan con tu objetivo.',
    color: Color(0xFFFF9800),
    ),
    (
    icon: Icons.insights,
    title: 'Progreso',
    body:
    'Revisa constancia, entrenos, hábitos y tendencias de macros por semana o mes.',
    color: Color(0xFF5C6BC0),
    ),
    (
    icon: Icons.local_fire_department,
    title: 'Racha diaria',
    body:
    'Cumple 3 de 4 hábitos (entreno, agua, sueño, comida) para mantener la racha activa.',
    color: Color(0xFFFF6D00),
    ),
  ];

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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: p.color.withValues(alpha: 0.15),
                          child: Icon(p.icon, size: 36, color: p.color),
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
                            color: Colors.grey.shade700,
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
                        ? _pages[i].color
                        : Colors.grey.shade300,
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

class _MacroProgressCard extends StatelessWidget {
  final String title;
  final int value;
  final int goal;
  final String unit;
  final Color color;
  final IconData icon;
  final Color cardBg;

  const _MacroProgressCard({
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

class _TodayTrainingCard extends StatelessWidget {
  final Color primary;
  final Color cardBg;
  final bool trainedToday;
  final bool pendingSession;
  final String? sessionTitle;
  final VoidCallback onGoRoutine;

  const _TodayTrainingCard({
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
      accent = const Color(0xFF4CAF50);
    } else if (pendingSession) {
      icon = Icons.play_circle_outline;
      title = 'Entreno en curso';
      subtitle = (sessionTitle != null && sessionTitle!.isNotEmpty)
          ? 'Continúa: $sessionTitle'
          : 'Sigue en la pestaña Rutina';
      accent = const Color(0xFFE91E63);
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

class _QuickAccess extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccess({
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

int _computeStreak(
    List<DailyLog> logs,
    List<WorkoutSession> sessions,
    DailyLog todayLog,
    bool trainedToday,
    ) {
  final logByDate = <String, DailyLog>{};
  for (final l in logs) {
    if (l.date.isNotEmpty) logByDate[l.date] = l;
  }
  final todayKey =
  todayLog.date.isEmpty ? WorkoutSession.dateKey() : todayLog.date;
  logByDate[todayKey] = todayLog;

  final trainDates = <String>{};
  for (final s in sessions) {
    if (!s.completed) continue;
    final d = s.startedAt.toLocal();
    trainDates.add(
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    );
  }
  if (trainedToday) trainDates.add(WorkoutSession.dateKey());

  bool qualifies(String key) {
    final l = logByDate[key];
    var n = 0;
    if (trainDates.contains(key)) n++;
    if (l != null && l.waterGlasses > 0) n++;
    if (l != null && (l.meals.isNotEmpty || l.consumedCalories > 0)) n++;
    if (l != null && l.sleepHours > 0) n++;
    return n >= 3;
  }

  final today = DateTime.now();
  var streak = 0;
  for (var i = 0; i < 60; i++) {
    final d = today.subtract(Duration(days: i));
    final key =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    if (!qualifies(key)) {
      if (i == 0) continue;
      break;
    }
    streak++;
  }
  return streak;
}

class _StreakIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final Color activeColor;

  const _StreakIcon({
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

class _CompactHabit extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _CompactHabit({
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
          _MiniBtn(icon: Icons.remove, onTap: onMinus),
          const SizedBox(width: 4),
          _MiniBtn(icon: Icons.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _MiniBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 18,
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
          child: _CompactHabit(
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

