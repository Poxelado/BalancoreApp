import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/home_widgets.dart';
import '../../../../core/notifications/smart_schedule.dart';
import '../../../../core/notifications/inactivity_check.dart';
import '../../../../core/first_run/first_run_prefs.dart';
import '../../../../core/motivation/motivational_messages.dart';

const int kMlPerGlass = 200;
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  bool _tutorialChecked = false;
  String? _motivationMsg;
  String? _motivationKey;


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
      builder: (ctx) => const FirstRunTutorialDialog(),
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

        final workouts = workoutsAsync.valueOrNull ?? [];
        final weekN = MotivationalMessages.workoutsInCurrentWeek(workouts);
        final routines = ref.watch(routinesProvider).valueOrNull ?? [];
        final firstEver =
            workouts.where((s) => s.completed).isEmpty && !trainedToday;
        final mCtx = MotivationContext(
          streakDays: streak,
          streakReadyToday: streakReady,
          trainedToday: trainedToday,
          isRestDay: MotivationalMessages.isRestDayFromRoutines(routines),
          firstWorkoutEver: firstEver,
          weekGoalMet: weekN >= 3,
          workoutsThisWeek: weekN,
          mealsToday: log.meals.length,
          waterGlasses: log.waterGlasses,
        );
        if (_motivationKey != mCtx.key) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final msg = await MotivationalMessages.next(mCtx);
            if (!mounted) return;
            setState(() {
              _motivationKey = mCtx.key;
              _motivationMsg = msg;
            });
          });
        }



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
            const SizedBox(height: 6),
            if (_motivationMsg != null) ...[
              const SizedBox(height: 6),
              MotivationBanner(message: _motivationMsg!),
            ],
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
                        StreakIcon(
                          icon: Icons.fitness_center,
                          active: trainedToday,
                          activeColor: const Color(0xFFE91E63),
                        ),
                        const SizedBox(width: 8),
                        StreakIcon(
                          icon: Icons.water_drop,
                          active: hasWater,
                          activeColor: const Color(0xFF2196F3),
                        ),
                        const SizedBox(width: 8),
                        StreakIcon(
                          icon: Icons.bedtime,
                          active: hasSleep,
                          activeColor: const Color(0xFF7E57C2),
                        ),
                        const SizedBox(width: 8),
                        StreakIcon(
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
                          child: CompactHabit(
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
                          child: CompactHabit(
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
                  child: MacroProgressCard(
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
                  child: MacroProgressCard(
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
            TodayTrainingCard(
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
                  child: QuickAccess(
                    icon: Icons.fitness_center,
                    label: 'Rutina',
                    color: const Color(0xFFE91E63),
                    onTap: () =>
                    ref.read(shellTabProvider.notifier).state = 3,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickAccess(
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
                  child: QuickAccess(
                    icon: Icons.insights,
                    label: 'Progreso',
                    color: const Color(0xFF5C6BC0),
                    onTap: () =>
                    ref.read(shellTabProvider.notifier).state = 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: QuickAccess(
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

