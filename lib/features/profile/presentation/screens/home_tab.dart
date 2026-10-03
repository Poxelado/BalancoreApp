import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../../core/notifications/smart_schedule.dart';

const int kMlPerGlass = 200;
const int kWaterGoalMl = 2000;

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshSmartNotifications(ref);
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
            const SizedBox(height: 6),
            Text(
              'Suma 3 de 4 hábitos del día para Activar a la racha',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            // Un solo bloque: racha + agua/sueño
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
                                ? '${ml}ml / ${kWaterGoalMl ~/ 1000}L'
                                : '0ml / 2L',
                            onMinus: log.waterGlasses > 0
                                ? () => _setWater(ref, log.waterGlasses - 1)
                                : null,
                            onPlus: log.waterGlasses < 20
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
                              (log.sleepHours - 0.5).clamp(0, 24),
                            )
                                : null,
                            onPlus: log.sleepHours < 16
                                ? () => _setSleep(
                              ref,
                              (log.sleepHours + 0.5).clamp(0, 24),
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
          ],
        );
      },
    );
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
  final todayKey = todayLog.date.isEmpty
      ? WorkoutSession.dateKey()
      : todayLog.date;
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
  var cursor = DateTime(today.year, today.month, today.day);
  if (!qualifies(WorkoutSession.dateKey(cursor))) {
    cursor = cursor.subtract(const Duration(days: 1));
  }

  var streak = 0;
  for (var i = 0; i < 400; i++) {
    final key =
        '${cursor.year}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
    if (!qualifies(key)) break;
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
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
    return CircleAvatar(
      radius: 15,
      backgroundColor: active
          ? activeColor.withValues(alpha: 0.9)
          : Colors.grey.withValues(alpha: 0.25),
      child: Icon(
        icon,
        size: 15,
        color: active ? Colors.white : Colors.grey.shade500,
      ),
    );
  }
}

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
            label: ml > 0 ? '${ml}ml / 2L' : '0ml / 2L',
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
            onPlus: log.waterGlasses < 20
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: iconColor.withValues(alpha: 0.2),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MiniBtn(icon: Icons.add, onTap: onPlus),
              _MiniBtn(icon: Icons.remove, onTap: onMinus),
            ],
          ),
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
      height: 26,
      width: 26,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        iconSize: 16,
        onPressed: onTap,
        icon: Icon(icon, color: onTap == null ? Colors.grey : null),
      ),
    );
  }
}
  