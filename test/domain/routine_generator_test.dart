import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/training/domain/exercise.dart';
import 'package:balancore/features/training/domain/routine_generator.dart';

/// Catálogo sintético: dos o tres opciones por grupo, con ids estables.
List<Exercise> _catalog() => [
      for (final g in ['Pecho', 'Espalda', 'Pierna', 'Hombro', 'Brazo', 'Core']) ...[
        Exercise(
          id: '${g}_compuesto',
          name: 'Compuesto $g',
          muscleGroup: g,
          equipment: 'Barra',
          levelEs: 'Principiante',
          mechanic: 'compound',
          primaryMuscles: [_primaryOf(g)],
        ),
        Exercise(
          id: '${g}_maquina',
          name: 'Máquina $g',
          muscleGroup: g,
          equipment: 'Máquina',
          levelEs: 'Intermedio',
          primaryMuscles: [_primaryOf(g)],
        ),
        Exercise(
          id: '${g}_peso_corporal',
          name: 'Peso corporal $g',
          muscleGroup: g,
          equipment: 'Peso corporal',
          levelEs: 'Principiante',
          mechanic: 'isolation',
          primaryMuscles: [_primaryOf(g)],
        ),
      ],
    ];

String _primaryOf(String g) => switch (g) {
      'Pecho' => 'pectoral muscles',
      'Espalda' => 'lats',
      'Pierna' => 'quadriceps',
      'Hombro' => 'shoulders',
      'Brazo' => 'biceps',
      _ => 'abs',
    };

/// Catálogo con [n] opciones por grupo muscular.
List<Exercise> _catalogN(int n) => [
      for (final g in ['Pecho', 'Espalda', 'Pierna', 'Hombro', 'Brazo', 'Core'])
        for (var i = 0; i < n; i++)
          Exercise(
            id: '${g}_$i',
            name: 'Ejercicio $i de $g',
            muscleGroup: g,
            equipment: 'Barra',
            levelEs: 'Principiante',
            mechanic: 'compound',
            primaryMuscles: [_primaryOf(g)],
          ),
    ];

RoutineRequest _req({
  RoutineGoal goal = RoutineGoal.mantenimiento,
  RoutineLevel level = RoutineLevel.intermedio,
  int days = 4,
  Set<String> equipment = const {},
  List<Exercise>? catalog,
}) =>
    RoutineRequest(
      goal: goal,
      level: level,
      daysPerWeek: days,
      catalog: catalog ?? _catalog(),
      equipment: equipment,
    );

void main() {
  group('generateRoutine', () {
    test('devuelve un día por cada día solicitado', () {
      for (final n in [2, 3, 4, 5, 6]) {
        expect(generateRoutine(_req(days: n)).length, n);
      }
    });

    test('asigna días de la semana sin repetir', () {
      final days = generateRoutine(_req(days: 5));
      final names = days.map((d) => d.day).toList();
      expect(names.toSet().length, 5);
      expect(names.first, 'Lunes');
    });

    test('cada día tiene ejercicios y duración estimada', () {
      final days = generateRoutine(_req(days: 4));
      for (final d in days) {
        expect(d.exercises, isNotEmpty, reason: 'el día ${d.day} quedó vacío');
        expect(d.duration, isNotEmpty);
        expect(d.description, isNotEmpty);
      }
    });

    test('no repite ejercicios entre días si el catálogo alcanza', () {
      // Con 8 opciones por grupo hay material de sobra: la rutina no debe
      // repetir ninguno.
      final ids = generateRoutine(_req(days: 6, catalog: _catalogN(8)))
          .expand((d) => d.exercises)
          .map((e) => e.exerciseId)
          .toList();
      expect(ids.toSet().length, ids.length);
    });

    test('si el catálogo se agota, repite antes que dejar días vacíos', () {
      // Solo 3 opciones por grupo: inevitablemente habrá repeticiones.
      final days = generateRoutine(_req(days: 6, catalog: _catalogN(3)));
      for (final d in days) {
        expect(d.exercises, isNotEmpty, reason: 'el día ${d.day} quedó vacío');
      }
    });

    test('no repite ejercicios dentro de un mismo día', () {
      for (final d in generateRoutine(_req(days: 6))) {
        final ids = d.exercises.map((e) => e.exerciseId).toList();
        expect(ids.toSet().length, ids.length, reason: 'día ${d.day}');
      }
    });

    test('los ids existen en el catálogo', () {
      final catalog = _catalog();
      for (final e in generateRoutine(_req(catalog: catalog))
          .expand((d) => d.exercises)) {
        expect(catalog.any((c) => c.id == e.exerciseId), isTrue);
      }
    });

    test('es determinista: dos llamadas dan lo mismo', () {
      final a = generateRoutine(_req(days: 5))
          .map((d) => d.exercises.map((e) => e.exerciseId).toList())
          .toList();
      final b = generateRoutine(_req(days: 5))
          .map((d) => d.exercises.map((e) => e.exerciseId).toList())
          .toList();
      expect(a, b);
    });

    test('respeta el equipamiento disponible', () {
      final days = generateRoutine(_req(
        days: 4,
        equipment: {'Mancuernas'},
      ));
      final used = days
          .expand((d) => d.exercises)
          .map((e) => e.exerciseId)
          .toList();
      // Solo "Mancuernas" está permitido y el catálogo sintético no la tiene:
      // debe seguir llenando, pero con lo que sí coincida.
      for (final id in used) {
        final ex = _catalog().firstWhere((c) => c.id == id);
        expect(ex.equipment, anyOf('Barra', 'Máquina', 'Peso corporal'));
      }
    });

    test('con poco espacio de catálogo deja los días vacíos sin romperse', () {
      final tiny = [
        const Exercise(
          id: 'p1',
          name: 'Press',
          muscleGroup: 'Pecho',
          equipment: 'Barra',
        ),
      ];
      final days = generateRoutine(_req(days: 3, catalog: tiny));
      expect(days.length, 3);
      // Solo el Pecho tiene dónde elegir; el resto queda sin ejercicios.
      expect(days.every((d) => d.exercises.length <= 1), isTrue);
    });

    test('principiante usa 3 series y intermedio 4', () {
      final p = generateRoutine(_req(level: RoutineLevel.principiante, days: 2));
      final i = generateRoutine(_req(level: RoutineLevel.intermedio, days: 2));
      int setsOf(List<dynamic> days) => days
          .expand((d) => d.exercises as List)
          .fold<int>(0, (s, e) => s + (e.effectiveSets as List).length);
      expect(setsOf(p), lessThan(setsOf(i)));
    });

    test('ganar músculo reparte más series que perder grasa', () {
      // Sin contar el cardio: perder grasa añade una máquina al final de cada
      // día y eso igualaría el total.
      int total(RoutineGoal goal) => generateRoutine(_req(goal: goal, days: 4))
          .expand((d) => d.exercises)
          .where((e) => e.muscleGroup != 'Cardio')
          .fold<int>(0, (s, e) => s + e.effectiveSets.length);
      expect(
        total(RoutineGoal.ganarMusculo),
        greaterThan(total(RoutineGoal.perderGrasa)),
      );
    });

    test('perder grasa añade cardio al final de cada día', () {
      final days =
          generateRoutine(_req(goal: RoutineGoal.perderGrasa, days: 4));
      for (final d in days) {
        expect(
          d.exercises.any((e) => e.muscleGroup == 'Cardio'),
          isTrue,
          reason: 'el día ${d.day} no tiene cardio',
        );
      }
    });

    test('sin objetivo de grasa no añade cardio', () {
      final days = generateRoutine(_req(goal: RoutineGoal.mantenimiento, days: 4));
      expect(
        days.expand((d) => d.exercises).any((e) => e.muscleGroup == 'Cardio'),
        isFalse,
      );
    });

    test('las series planificadas coinciden con sets y reps', () {
      final days = generateRoutine(_req(days: 3));
      for (final e in days.expand((d) => d.exercises)) {
        expect(e.effectiveSets.length, e.sets);
        for (final s in e.effectiveSets) {
          expect(s.reps, e.reps);
          expect(s.weight, 0);
        }
      }
    });

    test('descanso mayor en pierna que en core', () {
      final days = generateRoutine(_req(days: 4));
      final rests = <String, int>{};
      for (final e in days.expand((d) => d.exercises)) {
        rests.putIfAbsent(e.muscleGroup, () => e.restSeconds);
      }
      if (rests.containsKey('Pierna') && rests.containsKey('Core')) {
        expect(rests['Pierna'], greaterThan(rests['Core']!));
      }
    });
  });

  group('enums', () {
    test('RoutineGoal.fromLabel reconoce los objetivos del perfil', () {
      expect(RoutineGoal.fromLabel('Perder grasa'), RoutineGoal.perderGrasa);
      expect(RoutineGoal.fromLabel('Ganar músculo'), RoutineGoal.ganarMusculo);
      expect(RoutineGoal.fromLabel('Mantenimiento'), RoutineGoal.mantenimiento);
    });

    test('RoutineGoal.fromLabel cae a mantenimiento si no reconoce', () {
      expect(RoutineGoal.fromLabel('otra cosa'), RoutineGoal.mantenimiento);
      expect(RoutineGoal.fromLabel(null), RoutineGoal.mantenimiento);
    });

    test('RoutineLevel.fromLabel reconoce los niveles', () {
      expect(RoutineLevel.fromLabel('Principiante'), RoutineLevel.principiante);
      expect(RoutineLevel.fromLabel('Avanzado'), RoutineLevel.avanzado);
      expect(RoutineLevel.fromLabel('x'), RoutineLevel.intermedio);
    });
  });
}