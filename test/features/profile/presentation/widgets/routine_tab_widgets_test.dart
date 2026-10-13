import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/profile/presentation/widgets/routine_tab_widgets.dart';

RoutineExercise _ex(String id, String name, String group) => RoutineExercise(
      exerciseId: id,
      exerciseName: name,
      muscleGroup: group,
      sets: 3,
      reps: 10,
    );

CustomRoutine _routine() => CustomRoutine(
      id: 'cr1',
      name: 'Rutina 1',
      workouts: [
        CustomWorkout(
          id: 'w1',
          name: 'Día de pecho',
          exercises: [_ex('ex1', 'Press Banca', 'Pecho')],
        ),
        CustomWorkout(
          id: 'w2',
          name: 'Día de pierna',
          exercises: [_ex('ex2', 'Sentadilla', 'Pierna')],
        ),
      ],
    );

void main() {
  testWidgets('CustomRoutineCard contrae la rutina y muestra entrenamientos',
      (tester) async {
    CustomWorkout? started;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomRoutineCard(
            routine: _routine(),
            onStartWorkout: (w) => started = w,
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Rutina 1'), findsOneWidget);
    expect(find.textContaining('2 entrenamientos'), findsOneWidget);
    expect(find.text('Día de pecho'), findsNothing);

    await tester.tap(find.text('Rutina 1'));
    await tester.pump();
    expect(find.text('Día de pecho'), findsOneWidget);
    expect(find.text('Día de pierna'), findsOneWidget);
    expect(find.text('Press Banca'), findsNothing);

    await tester.tap(find.text('Día de pecho'));
    await tester.pump();
    expect(find.text('Press Banca'), findsOneWidget);

    await tester.tap(find.byTooltip('Empezar').first);
    expect(started?.name, 'Día de pecho');
  });

  testWidgets('CustomRoutineCard borra la rutina desde el botón expandido',
      (tester) async {
    var deleted = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomRoutineCard(
            routine: _routine(),
            onStartWorkout: (_) {},
            onEdit: () {},
            onDelete: () => deleted++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rutina 1'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(deleted, 1);
  });

  testWidgets('CustomRoutineCard sin entrenamientos muestra el aviso',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomRoutineCard(
            routine: const CustomRoutine(id: 'cr0', name: 'Vacía'),
            onStartWorkout: (_) {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('Sin entrenamientos'), findsOneWidget);
    await tester.tap(find.text('Vacía'));
    await tester.pump();
    expect(find.text('Sin entrenamientos todavía'), findsOneWidget);
  });
}
