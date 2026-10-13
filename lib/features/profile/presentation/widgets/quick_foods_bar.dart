import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../../core/theme/app_theme.dart';

/// Frecuentes (savedFoods por useCount) + recientes — 1 toque = registrar.
class QuickFoodsBar extends ConsumerWidget {
  final void Function(String msg) onQuickAdd;
  final void Function(MealEntry meal) onEditTemplate;

  const QuickFoodsBar({
    super.key,
    required this.onQuickAdd,
    required this.onEditTemplate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(savedFoodsProvider);
    final recentAsync = ref.watch(recentMealsProvider);

    final foods = foodsAsync.valueOrNull ?? [];
    final recent = recentAsync.valueOrNull ?? [];
    final frequent = foods.take(8).toList();

    if (frequent.isEmpty && recent.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (frequent.isNotEmpty) ...[
          Text(
            'Frecuentes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accentOf(context),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: frequent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = frequent[i];
                return GestureDetector(
                  onLongPress: () {
                    onEditTemplate(
                      f.toMeal(
                        mealType: f.defaultMealType ?? 'Snack',
                      ),
                    );
                  },
                  child: ActionChip(
                    avatar: Icon(Icons.bolt, size: 16, color: accentOf(context)),
                    label: Text(
                      f.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      final user = ref.read(authServiceProvider).currentUser;
                      if (user == null) return;
                      await ref
                          .read(profileRepositoryProvider)
                          .quickAddSavedFood(user.uid, f);
                      invalidateProgressData(ref);
                      ref.invalidate(todayLogProvider);
                      ref.invalidate(savedFoodsProvider);
                      onQuickAdd('${f.name} añadido');
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (recent.isNotEmpty) ...[
          Text(
            'Recientes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: accentOf(context),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length.clamp(0, 12),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final m = recent[i];
                return GestureDetector(
                  onLongPress: () => onEditTemplate(m),
                  child: ActionChip(
                    avatar: const Icon(Icons.history, size: 16),
                    label: Text(
                      m.name,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () async {
                      final user = ref.read(authServiceProvider).currentUser;
                      if (user == null) return;
                      await ref
                          .read(profileRepositoryProvider)
                          .quickAddMealTemplate(user.uid, m);
                      invalidateProgressData(ref);
                      ref.invalidate(todayLogProvider);
                      ref.invalidate(recentMealsProvider);
                      onQuickAdd('${m.name} añadido');
                    },
                  ),
                );
              },
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Toque = registrar · Mantén = editar antes de guardar',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}
