import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/profile/presentation/providers/profile_provider.dart';
import 'package:balancore/features/training/presentation/screens/weekly_routine_screen.dart';

List<RoutineDay> _week() => [
      RoutineDay(
        day: 'Lunes',
        title: 'Full Body A',
        exercises: [
          const RoutineExercise(exerciseId: 'ex1', exerciseName: 'Sentadilla'),
        ],
      ),
      RoutineDay(day: 'Martes', title: 'Descanso', isRestDay: true),
      RoutineDay(
        day: 'Miércoles',
        title: 'Full Body B',
        exercises: [
          const RoutineExercise(exerciseId: 'ex2', exerciseName: 'Remo'),
        ],
      ),
      RoutineDay(day: 'Jueves', title: 'Descanso', isRestDay: true),
      RoutineDay(
        day: 'Viernes',
        title: 'Full Body C',
        exercises: [
          const RoutineExercise(exerciseId: 'ex3', exerciseName: 'Press'),
        ],
      ),
      RoutineDay(day: 'Sábado', title: 'Cardio', exercises: []),
      RoutineDay(day: 'Domingo', title: 'Descanso', isRestDay: true),
    ];

Widget _app(List<RoutineDay> days) => ProviderScope(
      overrides: [
        routinesProvider.overrideWith((ref) async => days),
      ],
      child: const MaterialApp(home: WeeklyRoutineScreen()),
    );

void main() {
  testWidgets('por defecto muestra los días en bloques', (tester) async {
    await tester.pumpWidget(_app(_week()));
    await tester.pumpAndSettle();

    expect(find.text('Full Body A'), findsOneWidget);
    expect(find.text('Full Body B'), findsOneWidget);
    expect(find.text('Full Body C'), findsOneWidget);
    expect(find.text('Sugerir plantillas'), findsOneWidget);
    expect(find.byTooltip('Ver como cascada'), findsOneWidget);
  });

  testWidgets('el botón cambia a la vista en cascada', (tester) async {
    await tester.pumpWidget(_app(_week()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ver como cascada'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Ver en bloques'), findsOneWidget);
    expect(find.textContaining('Full Body A · 1 ejercicios'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsWidgets);
  });
}
