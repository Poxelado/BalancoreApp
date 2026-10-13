import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class WaterRow extends ConsumerWidget {
  final int glasses;

  const WaterRow({super.key, required this.glasses});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.water_drop, color: Colors.blue.shade400),
            const SizedBox(width: 8),
            Text('Agua: $glasses vasos',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              tooltip: 'Quitar vaso',
              onPressed: glasses <= 0
                  ? null
                  : () async {
                final user =
                    ref.read(authServiceProvider).currentUser;
                if (user == null) return;
                await ref
                    .read(profileRepositoryProvider)
                    .updateTodayLog(user.uid,
                    waterGlasses: glasses - 1);
                invalidateProgressData(ref);
              },
              icon: const Icon(Icons.remove_circle_outline),
            ),
            IconButton(
              tooltip: 'Añadir vaso',
              onPressed: () async {
                final user = ref.read(authServiceProvider).currentUser;
                if (user == null) return;
                await ref
                    .read(profileRepositoryProvider)
                    .updateTodayLog(user.uid, waterGlasses: glasses + 1);
                invalidateProgressData(ref);
              },
              icon: Icon(Icons.add_circle, color: primary),
            ),
          ],
        ),
      ),
    );
  }
}
