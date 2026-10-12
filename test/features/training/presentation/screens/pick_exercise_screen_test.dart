import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:balancore/features/training/domain/exercise.dart';
import 'package:balancore/features/training/presentation/providers/exercise_provider.dart';
import 'package:balancore/features/training/presentation/screens/pick_exercise_screen.dart';
import 'package:balancore/features/training/presentation/widgets/exercise_list_widgets.dart';

const _list = [
  Exercise(
    id: 'b',
    name: 'Press banca',
    muscleGroup: 'Pecho',
    equipment: 'Barra',
    level: 'beginner',
    levelEs: 'Principiante',
  ),
  Exercise(
    id: 'c',
    name: 'Remo con barra',
    muscleGroup: 'Espalda',
    equipment: 'Barra',
  ),
  Exercise(
    id: 'a',
    name: 'Sentadilla',
    muscleGroup: 'Pierna',
    equipment: 'Barra',
  ),
];

Future<List<Exercise>?> _open(WidgetTester tester) async {
  List<Exercise>? result;
  final container = ProviderContainer(
    overrides: [
      exercisesProvider.overrideWith((ref) async => _list),
      favoriteExerciseIdsProvider.overrideWith((ref) async => <String>{}),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await Navigator.push<List<Exercise>>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const PickExerciseScreen(),
                    ),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('muestra la lista completa (no solo el fallback)', (tester) async {
    await _open(tester);
    expect(find.text('Press banca'), findsOneWidget);
    expect(find.text('Remo con barra'), findsOneWidget);
  });

  testWidgets('agrupa por músculo con encabezados', (tester) async {
    await _open(tester);
    expect(find.text('Pecho'), findsWidgets);
    expect(find.text('Espalda'), findsWidgets);
  });

  testWidgets('el botón Añadir devuelve los seleccionados', (tester) async {
    List<Exercise>? result;
    final container = ProviderContainer(
      overrides: [
        exercisesProvider.overrideWith((ref) async => _list),
        favoriteExerciseIdsProvider.overrideWith((ref) async => <String>{}),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await Navigator.push<List<Exercise>>(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => const PickExerciseScreen(),
                      ),
                    );
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Press banca'));
    await tester.pump();
    await tester.tap(find.text('Remo con barra'));
    await tester.pump();

    await tester.tap(find.text('Añadir (2)'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.map((e) => e.id).toSet(), {'b', 'c'});
  });

  group('ExerciseCatalog.forPicker', () {
    test('incluye los extras de cardio', () {
      final ids = ExerciseCatalog.forPicker(_list).map((e) => e.id).toList();
      expect(ids, contains('ex_treadmill'));
      expect(ids, contains('ex_bike'));
      expect(ids, containsAll(['a', 'b', 'c']));
    });

    test('no duplica ids', () {
      final all = ExerciseCatalog.forPicker(_list);
      expect(all.map((e) => e.id).toSet().length, all.length);
    });
  });

  group('groupByMuscle', () {
    test('ordena por grupos conocidos y agrupa', () {
      final groups = groupByMuscle(_list).map((e) => e.key).toList();
      expect(groups, ['Pecho', 'Espalda', 'Pierna']);
    });
  });
}
