import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'achievement_toast.dart';
import 'achievements.dart';
import 'achievements_provider.dart';
import 'achievements_store.dart';

/// Sección de Logros: muestra todos los hitos, cuáles están desbloqueados y el
/// progreso de los que faltan.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(achievementStatsProvider);
    final unlockedIds = ref.watch(achievementUnlockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logros'),
        actions: [
          IconButton(
            tooltip: 'Probar aviso',
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () {
              final stats = statsAsync.valueOrNull;
              if (stats == null) return;
              final unlocked = AchievementsCatalog.unlockedBy(stats);
              final sample = unlocked.isNotEmpty
                  ? unlocked.last
                  : AchievementsCatalog.all.first;
              showAchievementToast(context, sample);
            },
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudieron cargar los logros.\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (stats) {
          final unlockedCount = AchievementsCatalog.all
              .where((a) => unlockedIds.contains(a.id))
              .length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _SummaryCard(
                unlocked: unlockedCount,
                total: AchievementsCatalog.all.length,
              ),
              const SizedBox(height: 20),
              for (final category in AchievementCategory.values)
                ..._categorySection(category, stats, unlockedIds),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _categorySection(
    AchievementCategory category,
    AchievementStats stats,
    Set<String> unlockedIds,
  ) {
    final items =
        AchievementsCatalog.all.where((a) => a.category == category).toList();
    if (items.isEmpty) return const [];
    final done = items.where((a) => unlockedIds.contains(a.id)).length;
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                category.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Text('$done/${items.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      for (final a in items)
        _AchievementTile(
          achievement: a,
          stats: stats,
          unlocked: unlockedIds.contains(a.id),
        ),
      const SizedBox(height: 14),
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = total == 0 ? 0.0 : unlocked / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDataColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppDataColors.gold, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$unlocked de $total desbloqueados',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text('${(pct * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppDataColors.gold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppDataColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.stats,
    required this.unlocked,
  });

  final Achievement achievement;
  final AchievementStats stats;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tier = achievement.tier;
    final accent = unlocked ? tier.color : cs.onSurfaceVariant;
    final current = achievement.count(stats);
    final shown = current > achievement.target ? achievement.target : current;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked
            ? tier.color.withValues(alpha: 0.10)
            : cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: unlocked
              ? tier.color.withValues(alpha: 0.55)
              : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unlocked
                  ? tier.color.withValues(alpha: 0.18)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              unlocked ? achievement.icon : Icons.lock_outline,
              color: accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        achievement.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: unlocked ? null : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      tier.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (!unlocked && achievement.target > 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: achievement.progress(stats),
                            minHeight: 6,
                            backgroundColor: cs.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              tier.color.withValues(alpha: 0.8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('$shown/${achievement.target}',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
                if (unlocked) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: tier.color),
                      const SizedBox(width: 4),
                      Text('Desbloqueado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tier.color,
                          )),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
