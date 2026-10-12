import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';

class SavedFoodChips extends ConsumerWidget {
  final void Function(SavedFood food) onPick;

  const SavedFoodChips({super.key, required this.onPick});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodsAsync = ref.watch(savedFoodsProvider);
    return foodsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (foods) {
        if (foods.isEmpty) {
          return const Text(
            'Tip: guarda alimentos en la pestaña "Mis alimentos"',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: foods.take(10).map((f) {
                return ActionChip(
                  label: Text(f.name, style: const TextStyle(fontSize: 12)),
                  onPressed: () => onPick(f),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
