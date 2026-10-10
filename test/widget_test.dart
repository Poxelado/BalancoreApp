import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState muestra título y subtítulo', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.fitness_center,
            title: 'Sin datos',
            subtitle: 'Registra tu primer entreno',
          ),
        ),
      ),
    );

    expect(find.text('Sin datos'), findsOneWidget);
    expect(find.text('Registra tu primer entreno'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
  });

  testWidgets('EmptyState dispara el CTA al pulsar', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.add,
            title: 'Vacío',
            actionLabel: 'Agregar',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Agregar'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
