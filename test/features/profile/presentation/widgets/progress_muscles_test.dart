import 'package:balancore/features/profile/presentation/widgets/progress_muscles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MuscleDetailPanel muestra zonas específicas tappables',
      (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MuscleDetailPanel(
            muscle: 'Brazo',
            sets: 30,
            exercises: const {'Curl bíceps': 18, 'Extensión tríceps': 12},
            subZones: const {
              'Bíceps': {'Curl bíceps': 18},
              'Tríceps': {'Extensión tríceps': 12},
            },
            color: Colors.purple,
            cardBg: Colors.grey.shade200,
            expanded: true,
            onToggle: () {},
            onSelectZone: (z) => picked = z,
          ),
        ),
      ),
    );

    expect(find.text('Zonas específicas'), findsOneWidget);
    expect(find.text('Brazo'), findsOneWidget);
    expect(find.text('Curl bíceps'), findsOneWidget);

    await tester.tap(find.text('Bíceps · 18'));
    expect(picked, 'Bíceps');

    await tester.tap(find.text('Tríceps · 12'));
    expect(picked, 'Tríceps');
  });

  testWidgets('sin subzonas no muestra el rótulo de zonas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MuscleDetailPanel(
            muscle: 'Pecho',
            sets: 10,
            exercises: const {'Press banca': 10},
            color: Colors.pink,
            cardBg: Colors.grey.shade200,
            expanded: true,
            onToggle: () {},
            onSelectZone: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Zonas específicas'), findsNothing);
    expect(find.text('Ejercicios'), findsOneWidget);
    expect(find.text('Press banca'), findsOneWidget);
  });
}
