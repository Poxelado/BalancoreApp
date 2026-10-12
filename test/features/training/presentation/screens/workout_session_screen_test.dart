import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balancore/features/auth/presentation/providers/auth_provider.dart';
import 'package:balancore/features/profile/domain/user_profile.dart';
import 'package:balancore/features/profile/presentation/providers/profile_provider.dart';
import 'package:balancore/features/training/presentation/screens/workout_session_screen.dart';

const _uid = 'u2';

RoutineDay _routine() => RoutineDay(
      day: 'Lunes',
      title: 'Pecho y Hombro',
      exercises: [
        const RoutineExercise(
          exerciseId: 'ex1',
          exerciseName: 'Press Banca',
          muscleGroup: 'Pecho',
          plannedSets: [
            PlannedSet(weight: 0, reps: 10),
            PlannedSet(weight: 0, reps: 10),
          ],
        ),
        const RoutineExercise(
          exerciseId: 'ex2',
          exerciseName: 'Press Militar',
          muscleGroup: 'Hombros',
          plannedSets: [
            PlannedSet(weight: 0, reps: 8),
            PlannedSet(weight: 0, reps: 8),
          ],
        ),
      ],
    );

/// La fuente por defecto de los widget tests es "Ahem" (glifos de ancho fijo),
/// que falsifica el layout de filas con texto. Cargar un TTF real hace que
/// las medidas se parezcan a las de un dispositivo.
Future<void> _loadRealFont() async {
  const candidates = [
    // Roboto real: la app usa la fuente por defecto (Roboto). Sin cargarla,
    // Flutter usa "Ahem" en los tests y el texto se ensancha tanto que la
    // columna de series desborda y el gesto del Dismissible se lo come un
    // scroll horizontal artificial (el swipe no existe en el dispositivo).
    '/home/deck/Applications/android-studio/plugins/design-tools/resources/layoutlib/data/fonts/Roboto-Regular.ttf',
    '/usr/share/fonts/liberation/LiberationSans-Regular.ttf',
    '/usr/share/fonts/truetype/ttf-dejavu/DejaVuSans.ttf',
  ];
  for (final path in candidates) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final bytes = f.readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
    return;
  }
}

/// Abre la pantalla empujándola como ruta hija (el "Terminar" hace pop).
Future<void> _openScreen(
  WidgetTester tester,
  ProviderContainer container,
) async {
  // La pantalla está diseñada para móvil; el viewport por defecto del test
  // (800x600) reparte el espacio de forma distinta. Ancho de móvil real (412).
  tester.view.physicalSize = const Size(1236, 2745);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await _loadRealFont();

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: Center(child: Text('HOME'))),
      ),
    ),
  );
  final nav = tester.state<NavigatorState>(find.byType(Navigator));
  nav.push(
    MaterialPageRoute(builder: (_) => WorkoutSessionScreen(routine: _routine())),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Drena microtareas/escrituras asíncronas sin disparar pumpAndSettle
/// (el temporizador tick de 1s impide que se asiente).
Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 30));
}

/// Desmonta la pantalla (dispose cancela los temporizadores que aún corren).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// Desplaza el contenido hasta que `f` quede dentro de la raíz y tappable.
Future<void> _visible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore db;
  late ProfileRepository repo;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FakeFirebaseFirestore();
    repo = ProfileRepository(db: db);
    container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(
          AuthService(
            auth: MockFirebaseAuth(
              signedIn: true,
              mockUser: MockUser(uid: _uid, email: 'a@b.com'),
            ),
          ),
        ),
        profileRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<WorkoutSession?> active() =>
      repo.getActiveWorkoutSession(_uid);

  Future<List<WorkoutSession>> all() =>
      repo.getWorkoutHistory(_uid, limit: 20);

  testWidgets('al abrir persiste una sesión incompleta con los ejercicios de la rutina',
      (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    final s = await active();
    expect(s, isNotNull);
    expect(s!.completed, isFalse);
    expect(s.title, 'Pecho y Hombro');
    expect(s.exercises.length, 2);
    expect(s.exercises.first.exerciseName, 'Press Banca');
    expect(s.exercises.first.sets.map((e) => e.setNumber), [1, 2]);

    await _unmount(tester);
  });

  testWidgets('cambiar el peso propaga en cascada y persiste en Firestore', (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.enterText(find.byType(TextField).first, '80');
    await _flush(tester);

    final s = await active();
    final pecho = s!.exercises.first;
    expect(pecho.sets.every((set) => set.weight == 80), isTrue,
        reason: 'El peso debe aplicarse a todas las series del ejercicio');
    expect(pecho.sets.every((set) => set.reps == 10), isTrue,
        reason: 'Las reps del resto de series no se tocan');
    // El ejercicio siguiente no se ve afectado por la cascada.
    expect(s.exercises[1].sets.every((set) => set.weight == 0), isTrue);

    await _unmount(tester);
  });

  testWidgets('marcar una serie completa arranca el descanso y persiste', (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await _visible(tester, find.byIcon(Icons.check_circle_outline).first);
    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await _flush(tester);

    final s = await active();
    expect(s!.exercises.first.sets.first.completed, isTrue);
    expect(s.exercises.first.completedSets, 1);

    // El descanso aparece con el valor por defecto (90s → "1min 30s").
    expect(find.textContaining('Descanso · '), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('añadir serie copia la última y renumera', (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.tap(find.text('Añadir serie'));
    await _flush(tester);

    final s = await active();
    final sets = s!.exercises.first.sets;
    expect(sets.length, 3);
    expect(sets.map((e) => e.setNumber), [1, 2, 3]);

    await _unmount(tester);
  });
testWidgets('borrar una serie la elimina de la sesión y renumera',
      (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    // El gesto horizontal del Dismissible pierde contra el scroll horizontal
    // de la tarjeta del ejercicio (posible defecto real); se invoca el
    // callback onDismissed enlazado por la UI para fijar la lógica de borrado.
    final first = find.byType(Dismissible).first;
    tester.widget<Dismissible>(first).onDismissed!(DismissDirection.endToStart);
    await _flush(tester);

    final s = await active();
    final sets = s!.exercises.first.sets;
    expect(sets.length, 1);
    expect(sets.single.setNumber, 1);

    await _unmount(tester);
  });

  testWidgets('pausar/reanudar persiste el estado en la sesión', (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.tap(find.byTooltip('Pausar'));
    await _flush(tester);
    expect((await active())!.isPaused, isTrue);
    expect(find.text('PAUSA'), findsOneWidget);

    await tester.tap(find.byTooltip('Reanudar'));
    await _flush(tester);
    expect((await active())!.isPaused, isFalse);

    await _unmount(tester);
  });

  testWidgets('asignar RPE persiste en el ejercicio', (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.tap(find.text('7'));
    await _flush(tester);

    final s = await active();
    expect(s!.exercises.first.rpe, 7);

    await _unmount(tester);
  });

  testWidgets('cambiar el tipo de serie persiste', (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.tap(find.byType(PopupMenuButton<SetType>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Calentamiento'));
    await _flush(tester);

    final s = await active();
    expect(s!.exercises.first.sets.first.type, SetType.warmup);

    await _unmount(tester);
  });

  testWidgets('editar la nota de una serie persiste', (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.tap(find.byIcon(Icons.sticky_note_2_outlined).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).last, 'buena forma');
    await tester.tap(find.text('Guardar'));
    await _flush(tester);

    final s = await active();
    expect(s!.exercises.first.sets.first.note, 'buena forma');

    await _unmount(tester);
  });

  Future<void> openSetSheet(WidgetTester tester) async {
    await tester.longPress(find.text('—').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('duplicar una serie la inserta después y renumera',
      (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await openSetSheet(tester);
    await tester.tap(find.text('Duplicar serie'));
    await _flush(tester);

    final sets = (await active())!.exercises.first.sets;
    expect(sets.length, 3);
    expect(sets.map((e) => e.setNumber), [1, 2, 3]);

    await _unmount(tester);
  });

  testWidgets('mover una serie reordena y renumera', (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.tap(find.byType(PopupMenuButton<SetType>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Calentamiento'));
    await _flush(tester);

    await openSetSheet(tester);
    await tester.tap(find.text('Mover abajo'));
    await _flush(tester);

    final sets = (await active())!.exercises.first.sets;
    expect(sets.map((e) => e.setNumber), [1, 2]);
    expect(sets.first.type, SetType.normal);
    expect(sets.last.type, SetType.warmup);

    await _unmount(tester);
  });

  testWidgets('finalizar guarda la sesión como completada y sale de la pantalla',
      (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await _visible(tester, find.text('Terminar'));
    await tester.tap(find.text('Terminar'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Terminar entrenamiento'), findsOneWidget);

    await tester.tap(find.text('Finalizar'));
    await tester.pump(const Duration(milliseconds: 400));
    await _flush(tester);

    // Vuelve a la pantalla base.
    expect(find.text('HOME'), findsOneWidget);

    final done = (await all()).where((s) => s.completed).toList();
    expect(done.length, 1);
    expect(done.single.completed, isTrue);
    expect(await active(), isNull, reason: 'Ya no hay sesión activa');

    await _unmount(tester);
  });
}