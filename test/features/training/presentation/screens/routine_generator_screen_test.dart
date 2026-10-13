import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balancore/core/ai/ai_key_store.dart';
import 'package:balancore/features/auth/presentation/providers/auth_provider.dart';
import 'package:balancore/features/profile/presentation/providers/profile_provider.dart';
import 'package:balancore/features/training/domain/exercise.dart';
import 'package:balancore/features/training/domain/routine_generator.dart';
import 'package:balancore/features/training/presentation/providers/exercise_provider.dart';
import 'package:balancore/features/training/presentation/screens/routine_generator_screen.dart';

const _uid = 'u9';

/// Texto real: con la fuente por defecto de los tests ("Ahem") el layout de
/// los chips se desborda y los toques fallan.
Future<void> _loadRealFont() async {
  const candidates = [
    '/home/deck/Applications/android-studio/plugins/design-tools/resources/layoutlib/data/fonts/Roboto-Regular.ttf',
    '/usr/share/fonts/liberation/LiberationSans-Regular.ttf',
  ];
  for (final path in candidates) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    await loader.load();
    return;
  }
}

List<Exercise> _catalog() => [
      for (final g in ['Pecho', 'Espalda', 'Pierna', 'Hombro', 'Brazo', 'Core'])
        for (var i = 0; i < 4; i++)
          Exercise(
            id: '${g}_$i',
            name: 'Ejercicio $i de $g',
            muscleGroup: g,
            equipment: 'Barra',
            levelEs: 'Principiante',
            mechanic: i == 0 ? 'compound' : 'isolation',
            primaryMuscles: const ['pectoral muscles'],
          ),
    ];

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
        exercisesProvider.overrideWith((ref) async => _catalog()),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1236, 2745);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _loadRealFont();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: RoutineGeneratorScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Desplaza hasta que el botón quede visible: el resumen queda bajo el
  /// pliegue en el viewport del test.
  Future<void> scrollToApply(WidgetTester tester) async {
    final f = find.text('Aplicar a mi semana');
    // El botón queda tras las tarjetas de los días: el ListView aún no lo
    // construyó, así que hay que desplazarlo antes de poder tocarlo.
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('sin clave de IA genera con el motor de reglas',
      (WidgetTester tester) async {
    expect(await AiKeyStore.hasKey(), isFalse);

    await open(tester);

    await tester.tap(find.text('Generar rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Generada con el motor de reglas'), findsOneWidget);
    // El aviso de "sin clave" se comprueba antes de desplazarse: el resumen
    // lo empuja fuera de la pantalla.
    expect(find.textContaining('Sin clave de IA'), findsOneWidget);
    await scrollToApply(tester);
    expect(find.text('Aplicar a mi semana'), findsOneWidget);
  });

  testWidgets('con clave de IA configurada lo anuncia',
      (WidgetTester tester) async {
    await AiKeyStore.save('AIzaTEST');
    await open(tester);
    expect(find.textContaining('Se enviará tu objetivo'), findsOneWidget);
  });

  testWidgets('aplicar guarda la rutina generada en Firestore',
      (WidgetTester tester) async {
    await open(tester);
    await tester.tap(find.text('Generar rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await scrollToApply(tester);
    await tester.tap(find.text('Aplicar a mi semana'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Aplicar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final saved = await repo.getRoutines(_uid);
    expect(saved, isNotEmpty);
    expect(saved.length, 4, reason: '4 días por defecto');
    expect(saved.first.exercises, isNotEmpty);
  });

  testWidgets('cambiar los días por semana cambia la rutina',
      (WidgetTester tester) async {
    await open(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, '5'));
    await tester.pump();
    await tester.tap(find.text('Generar rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await scrollToApply(tester);
    await tester.tap(find.text('Aplicar a mi semana'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Aplicar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect((await repo.getRoutines(_uid)).length, 5);
  });

  testWidgets('el tiempo por sesión ajusta el volumen de la rutina',
      (WidgetTester tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, '90+ min'));
    await tester.pump();
    await tester.tap(find.text('Generar rutina'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await scrollToApply(tester);
    await tester.tap(find.text('Aplicar a mi semana'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Aplicar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    int totalOf(int? minutes) => generateRoutine(
          RoutineRequest(
            goal: RoutineGoal.mantenimiento,
            level: RoutineLevel.intermedio,
            daysPerWeek: 4,
            catalog: _catalog(),
            minutesAvailable: minutes,
          ),
        ).fold<int>(0, (s, d) => s + d.exercises.length);

    final saved = await repo.getRoutines(_uid);
    final total = saved.expand((d) => d.exercises).length;
    expect(total, totalOf(90), reason: 'usa el tiempo elegido (90 min)');
    expect(total, greaterThan(totalOf(30)));
  });
}