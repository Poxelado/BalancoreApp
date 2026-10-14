import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balancore/core/achievements/achievement_toast.dart';
import 'package:balancore/core/achievements/achievement_watcher.dart';
import 'package:balancore/core/achievements/achievements.dart';
import 'package:balancore/core/achievements/achievements_provider.dart';
import 'package:balancore/core/achievements/achievements_store.dart';

final _statsProvider =
    StateProvider<AchievementStats>((ref) => const AchievementStats());

/// Avanza el reloj para consumir el aviso (timer de cierre + delay interno).
Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('showAchievementToast muestra el aviso', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold();
      }),
    ));

    showAchievementToast(ctx, AchievementsCatalog.all.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('¡LOGRO DESBLOQUEADO!'), findsOneWidget);

    await _drainToasts(tester);
  });

  testWidgets('el watcher avisa al desbloquear un logro nuevo',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          achievementStatsProvider.overrideWith((ref) async {
            return ref.watch(_statsProvider);
          }),
        ],
        child: const MaterialApp(
          home: AchievementWatcher(child: Scaffold()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('¡LOGRO DESBLOQUEADO!'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AchievementWatcher)),
    );
    container.read(_statsProvider.notifier).state =
        const AchievementStats(workouts: 1);
    await tester.pumpAndSettle();

    expect(container.read(achievementUnlockProvider), contains('first_workout'));
    expect(find.text('¡LOGRO DESBLOQUEADO!'), findsOneWidget);
    expect(find.text('Primer paso'), findsOneWidget);

    await _drainToasts(tester);
  });
}
