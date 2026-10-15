import 'package:balancore/features/profile/presentation/widgets/progress_muscles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MuscleDetailPanel lista zonas específicas y permite filtrar',
      (tester) async {
    String? picked;
    var pickCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MuscleDetailPanel(
            muscle: 'Brazo',
            sets: 30,
            subZones: const {
              'Bíceps': {'Curl bíceps': 18},
              'Tríceps': {'Extensión tríceps': 12},
            },
            color: Colors.purple,
            cardBg: Colors.grey.shade200,
            expanded: true,
            onToggle: () {},
            onSelectZone: (z) {
              picked = z;
              pickCount++;
            },
          ),
        ),
      ),
    );

    expect(find.text('Zonas específicas'), findsOneWidget);
    expect(find.text('Brazo'), findsOneWidget);
    // Sin zona elegida se ven todos los ejercicios del sector.
    expect(find.text('Curl bíceps'), findsOneWidget);
    expect(find.text('Extensión tríceps'), findsOneWidget);

    await tester.tap(find.text('Bíceps · 18'));
    expect(picked, 'Bíceps');

    await tester.tap(find.text('Todos'));
    expect(picked, isNull);
    expect(pickCount, 2);
  });

  testWidgets('al elegir una zona solo muestra sus ejercicios',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MuscleDetailPanel(
            muscle: 'Brazo',
            sets: 30,
            subZones: const {
              'Bíceps': {'Curl bíceps': 18},
              'Tríceps': {'Extensión tríceps': 12},
            },
            selectedZone: 'Bíceps',
            color: Colors.purple,
            cardBg: Colors.grey.shade200,
            expanded: true,
            onToggle: () {},
            onSelectZone: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Brazo · Bíceps'), findsOneWidget);
    expect(find.text('Ejercicios · Bíceps'), findsOneWidget);
    expect(find.text('Curl bíceps'), findsOneWidget);
    expect(find.text('Extensión tríceps'), findsNothing);
  });

  testWidgets('sin zonas específicas no muestra el selector', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MuscleDetailPanel(
            muscle: 'Pecho',
            sets: 10,
            subZones: const {
              'Pecho': {'Press banca': 10},
            },
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
