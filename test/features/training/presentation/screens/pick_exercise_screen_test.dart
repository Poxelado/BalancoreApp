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

Future<List<Exercise>?> _open(WidgetTester tester, [List<Exercise> list = _list]) async {
  List<Exercise>? result;
  final container = ProviderContainer(
    overrides: [
      exercisesProvider.overrideWith((ref) async => list),
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

  group('búsqueda por zona y sin tildes', () {
    const list = [
      Exercise(
        id: 'wrist',
        name: 'Curl de muñeca',
        muscleGroup: 'Brazo',
        primaryMuscles: ['forearms'],
      ),
      Exercise(
        id: 'curl',
        name: 'Curl bíceps',
        muscleGroup: 'Brazo',
        primaryMuscles: ['biceps'],
      ),
    ];

    testWidgets('"antebrazo" encuentra el ejercicio de antebrazo', (tester) async {
      await _open(tester, list);
      expect(find.text('Curl de muñeca'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'antebrazo');
      await tester.pumpAndSettle();

      expect(find.text('Curl de muñeca'), findsOneWidget);
      expect(find.text('Curl bíceps'), findsNothing);
    });

    testWidgets('buscar sin tilde encuentra el nombre con tilde', (tester) async {
      await _open(tester, list);
      await tester.enterText(find.byType(TextField), 'biceps');
      await tester.pumpAndSettle();

      expect(find.text('Curl bíceps'), findsOneWidget);
      expect(find.text('Curl de muñeca'), findsNothing);
    });

    testWidgets('el chip de zona filtra por Antebrazos', (tester) async {
      await _open(tester, list);
      expect(find.text('Toda zona'), findsOneWidget);

      await tester.tap(find.text('Antebrazos'));
      await tester.pumpAndSettle();

      expect(find.text('Curl de muñeca'), findsOneWidget);
      expect(find.text('Curl bíceps'), findsNothing);
    });
  });

  group('ExerciseThumb', () {
    testWidgets('resuelve por id y cae al ícono si no existe', (tester) async {
      ExerciseCatalog.cache = null; // sin catálogo: fallback
      addTearDown(() => ExerciseCatalog.cache = null);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ExerciseThumb(exerciseId: 'ex_bench_press'),
                ExerciseThumb(exerciseId: 'no_existe_xyz'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ExerciseThumb), findsNWidgets(2));
      expect(find.byIcon(Icons.fitness_center), findsNWidgets(2));
    });
  });
}
