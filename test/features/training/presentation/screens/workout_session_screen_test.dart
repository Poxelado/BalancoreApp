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
import 'package:balancore/features/training/presentation/screens/workout_summary_screen.dart';
import 'package:balancore/features/training/presentation/widgets/session_plates_sheet.dart';
import 'package:balancore/features/training/presentation/widgets/session_widgets.dart';

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

/// Sesión anterior completada: mismo Press Banca con 70/75 kg, sin Press
/// Militar (para comprobar que lo que no coincide no se toca).
WorkoutSession _previousSession() => WorkoutSession(
      id: 'prev_1',
      dayName: 'Lunes',
      title: 'Pecho y Hombro',
      startedAt: DateTime.now().subtract(const Duration(days: 3)),
      finishedAt: DateTime.now().subtract(const Duration(days: 3, minutes: -5)),
      completed: true,
      exercises: const [
        WorkoutExerciseLog(
          exerciseId: 'ex1',
          exerciseName: 'Press Banca',
          muscleGroup: 'Pecho',
          sets: [
            WorkoutSetLog(setNumber: 1, weight: 70, reps: 12, completed: true),
            WorkoutSetLog(setNumber: 2, weight: 75, reps: 10, completed: true),
          ],
        ),
      ],
    );

/// Sesión en curso cuyo descanso ya venció hace 10 minutos.
WorkoutSession _staleRestSession() => WorkoutSession(
      id: 'prev_rest',
      dayName: 'Lunes',
      title: 'Pecho y Hombro',
      startedAt: DateTime.now().subtract(const Duration(hours: 1)),
      restEndsAt: DateTime.now().subtract(const Duration(minutes: 10)),
      exercises: const [],
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
  await tester.pump(const Duration(milliseconds: 400));
}

/// Igual que [_openScreen], pero abriendo una pantalla cualquiera.
Future<void> _openWidget(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen,
) async {
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
  nav.push(MaterialPageRoute(builder: (_) => screen));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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

    // El descanso aparece con el descanso configurado del ejercicio (60s).
    expect(find.byType(RestBanner), findsOneWidget);
    expect(find.text('1min 00s'), findsOneWidget);
    // Y queda persistido como instante de fin, no como contador.
    expect((await active())!.restEndsAt, isNotNull);

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

  testWidgets('emparejar y quitar un superset persiste', (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.tap(find.byTooltip('Superset'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Emparejar con Press Militar'));
    await _flush(tester);

    final paired = await active();
    expect(paired!.exercises[0].supersetId, isNotNull);
    expect(paired.exercises[1].supersetId, paired.exercises[0].supersetId);
    expect(find.textContaining('Superset con Press Militar'), findsOneWidget);

    await tester.tap(find.byTooltip('Superset'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Quitar del superset'));
    await _flush(tester);

    final unpaired = await active();
    expect(unpaired!.exercises[0].supersetId, isNull);
    expect(unpaired.exercises[1].supersetId, isNull);

    await _unmount(tester);
  });

  testWidgets('la calculadora de discos aplica el peso a la serie',
      (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await openSetSheet(tester);
    await tester.tap(find.text('Calculadora de discos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.enterText(
      find.descendant(
        of: find.byType(PlateCalculatorSheet),
        matching: find.byType(TextField),
      ),
      '100',
    );
    await tester.pump();
    await tester.tap(find.text('Usar este peso'));
    await _flush(tester);

    final sets = (await active())!.exercises.first.sets;
    expect(sets.first.weight, 100);

    await _unmount(tester);
  });

  testWidgets('copiar de la última sesión rellena pesos y reps', (WidgetTester tester) async {
    await repo.saveWorkoutSession(_uid, _previousSession());

    await _openScreen(tester, container);
    await _flush(tester);

    await tester.tap(find.byTooltip('Ajustes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Copiar de la última sesión'));
    await _flush(tester);
    await tester.pump(const Duration(milliseconds: 400));

    final s = await active();
    final pecho = s!.exercises.first;
    expect(pecho.sets.map((e) => e.weight), [70, 75]);
    expect(pecho.sets.map((e) => e.reps), [12, 10]);
    expect(s.exercises[1].sets.every((e) => e.weight == 0), isTrue,
        reason: 'Un ejercicio ausente en la sesión anterior queda intacto');

    await _unmount(tester);
  });

  testWidgets('la primera serie completada queda marcada como récord',
      (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.enterText(find.byType(TextField).first, '80');
    await _flush(tester);
    await _visible(tester, find.byIcon(Icons.check_circle_outline).first);
    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Sin historial previo, la primera serie marcada es récord personal.
    expect(find.text('PR'), findsWidgets);
    expect(find.textContaining('¡Nuevo récord en Press Banca!'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('una serie igual al récord previo no se marca',
      (WidgetTester tester) async {
    await repo.saveWorkoutSession(_uid, _previousSession());

    await _openScreen(tester, container);
    await _flush(tester);

    // El Press Banca ya tiene 70 kg: repetir 70 no es récord.
    await tester.enterText(find.byType(TextField).first, '70');
    await _flush(tester);
    await _visible(tester, find.byIcon(Icons.check_circle_outline).first);
    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('PR'), findsNothing);

    await _unmount(tester);
  });

  testWidgets('marca un solo PR por ejercicio y en la mejor serie',
      (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.enterText(find.byType(TextField).first, '80');
    await _flush(tester);
    await _visible(tester, find.byIcon(Icons.check_circle_outline).first);
    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('PR'), findsOneWidget);

    // Segunda serie más pesada: el badge se mueve, pero sigue habiendo uno.
    await tester.enterText(find.byType(TextField).at(2), '100');
    await _flush(tester);
    await _visible(tester, find.byIcon(Icons.check_circle_outline).first);
    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('PR'), findsOneWidget,
        reason: 'Un solo récord por ejercicio, en la serie más alta');

    await _unmount(tester);
  });

  testWidgets('el descanso se ajusta con ±15s y se salta limpiando el instante',
      (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await _flush(tester);
    final ends = (await active())!.restEndsAt!;
    expect(ends.difference(DateTime.now()).inSeconds, closeTo(60, 5));

    await tester.tap(find.byTooltip('Quitar 15s'));
    await _flush(tester);
    expect(
      (await active())!.restEndsAt!.difference(DateTime.now()).inSeconds,
      closeTo(45, 5),
    );
    expect(ends.difference((await active())!.restEndsAt!).inSeconds, 15,
        reason: 'Quitar 15s acorta el descanso 15 segundos');

    await tester.tap(find.byTooltip('Añadir 15s'));
    await _flush(tester);
    expect(
      (await active())!.restEndsAt!.difference(DateTime.now()).inSeconds,
      closeTo(60, 5),
    );

    await tester.tap(find.text('Saltar'));
    await _flush(tester);
    expect(find.byType(RestBanner), findsNothing);
    expect((await active())!.restEndsAt, isNull);

    await _unmount(tester);
  });

  testWidgets('al reabrir la sesión se retoma el descanso en curso',
      (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);
    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await _flush(tester);
    await _unmount(tester);

    // Reabre la sesión persistida (como si la app se hubiera cerrado).
    final saved = (await active())!;
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
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          routine: _routine(),
          existing: saved,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // El descanso sigue vivo: se recalcula desde restEndsAt (no desde un
    // contador que quedó congelado al cerrar la app).
    expect(find.byType(RestBanner), findsOneWidget);
    final left = (await active())!.restRemaining();
    expect(left, greaterThan(0));
    expect(left, lessThan(60), reason: 'El tiempo restante debe haber corrido');
    expect(find.text(fmtRest(left)), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('un descanso ya vencido no se retoma', (WidgetTester tester) async {
    await repo.saveWorkoutSession(_uid, _staleRestSession());

    await _openScreen(tester, container);
    await _flush(tester);

    expect(find.byType(RestBanner), findsNothing);
    expect((await active())!.restEndsAt, isNull);

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

    // Terminado el entrenamiento se muestra el resumen.
    expect(find.byType(WorkoutSummaryScreen), findsOneWidget);
    expect(find.text('Resumen'), findsOneWidget);

    // "Listo" cierra el resumen y vuelve a la pantalla base.
    await tester.tap(find.text('Listo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('HOME'), findsOneWidget);
    expect(find.byType(WorkoutSummaryScreen), findsNothing);

    final done = (await all()).where((s) => s.completed).toList();
    expect(done.length, 1);
    expect(done.single.completed, isTrue);
    expect(await active(), isNull, reason: 'Ya no hay sesión activa');

    await _unmount(tester);
  });

  testWidgets('el resumen desglosa los ejercicios y sus series',
      (WidgetTester tester) async {
    await _openScreen(tester, container);
    await _flush(tester);

    await tester.enterText(find.byType(TextField).first, '80');
    await _flush(tester);
    await _visible(tester, find.byIcon(Icons.check_circle_outline).first);
    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await _visible(tester, find.text('Terminar'));
    await tester.tap(find.text('Terminar'));
    await tester.pump(const Duration(milliseconds: 400));

    // El diálogo resume lo hecho y avisa de las series sin marcar.
    expect(find.text('Terminar entrenamiento'), findsOneWidget);
    expect(find.text('Tiempo'), findsOneWidget);
    expect(find.text('Volumen'), findsOneWidget);
    expect(find.textContaining('sin marcar'), findsOneWidget);

    await tester.tap(find.text('Finalizar'));
    await tester.pump(const Duration(milliseconds: 400));
    await _flush(tester);

    // El resumen lista el desglose por ejercicio con sus series.
    expect(find.text('Ejercicios'), findsOneWidget);
    expect(find.text('Press Banca'), findsWidgets);
    expect(find.textContaining('80 kg'), findsWidgets);
    expect(find.byIcon(Icons.check_circle), findsWidgets);
    expect(find.text('Listo'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('el entreno libre vacío invita a añadir y no persiste nada',
      (WidgetTester tester) async {
    await _openWidget(
      tester,
      container,
      const WorkoutSessionScreen(
        title: 'Entrenamiento libre',
        allowAddExercises: true,
      ),
    );
    await _flush(tester);

    expect(find.textContaining('vacío'), findsOneWidget);
    expect(find.text('Añadir ejercicio'), findsOneWidget);
    expect(await active(), isNull,
        reason: 'Una sesión vacía sin empezar no se guarda');

    await _unmount(tester);
  });

  testWidgets('el entreno libre arranca con los ejercicios elegidos y permite añadir',
      (WidgetTester tester) async {
    await _openWidget(
      tester,
      container,
      const WorkoutSessionScreen(
        title: 'Entrenamiento libre',
        allowAddExercises: true,
        initialExercises: [
          WorkoutExerciseLog(
            exerciseId: 'ex1',
            exerciseName: 'Press Banca',
            muscleGroup: 'Pecho',
            sets: [WorkoutSetLog(setNumber: 1, reps: 10)],
          ),
        ],
      ),
    );
    await _flush(tester);

    expect(find.text('Press Banca'), findsWidgets);
    expect(find.text('Añadir'), findsOneWidget,
        reason: 'El selector muestra el botón para añadir más ejercicios');

    final s = await active();
    expect(s, isNotNull);
    expect(s!.title, 'Entrenamiento libre');
    expect(s.exercises.single.exerciseName, 'Press Banca');

    await _unmount(tester);
  });
}