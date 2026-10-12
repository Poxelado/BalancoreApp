import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/training/domain/exercise.dart';

void main() {
  group('ExerciseCatalog', () {
    test('no tiene ids duplicados', () {
      final ids = ExerciseCatalog.builtIn.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('todos los ejercicios built-in tienen nombre y grupo válido', () {
      for (final e in ExerciseCatalog.builtIn) {
        expect(e.name, isNotEmpty);
        expect(Exercise.muscleGroups, contains(e.muscleGroup));
      }
    });

    test('byId encuentra un ejercicio existente', () {
      expect(ExerciseCatalog.byId('ex_bench_press')?.name, 'Press de banca');
    });

    test('byId devuelve null si no existe', () {
      expect(ExerciseCatalog.byId('no_existe'), isNull);
    });

    test('resolve prioriza el catálogo por id', () {
      final e = ExerciseCatalog.resolve(id: 'ex_bench_press', name: 'X');
      expect(e.name, 'Press de banca');
    });

    test('resolve crea uno nuevo con grupo "Otro" si no está en el catálogo', () {
      final e = ExerciseCatalog.resolve(id: 'custom_1', name: 'Mi ejercicio');
      expect(e.id, 'custom_1');
      expect(e.name, 'Mi ejercicio');
      expect(e.muscleGroup, 'Otro');
    });

    test('resolve respeta el grupo indicado', () {
      final e = ExerciseCatalog.resolve(
        id: 'custom_1',
        name: 'Mi ejercicio',
        muscleGroup: 'Pecho',
      );
      expect(e.muscleGroup, 'Pecho');
    });
  });

  group('Exercise serialización', () {
    test('toMap/fromMap conserva los campos', () {
      const original = Exercise(
        id: 'ex_1',
        name: 'Remo',
        muscleGroup: 'Espalda',
        equipment: 'Casa',
        instructions: 'Tira',
        isCustom: true,
      );
      final restored = Exercise.fromMap('ex_1', original.toMap());
      expect(restored.name, 'Remo');
      expect(restored.muscleGroup, 'Espalda');
      expect(restored.equipment, 'Casa');
      expect(restored.isCustom, isTrue);
    });

    test('fromMap usa valores por defecto con datos vacíos', () {
      final e = Exercise.fromMap('id', const {});
      expect(e.muscleGroup, 'Otro');
      expect(e.equipment, 'Gimnasio');
      expect(e.isCustom, isFalse);
    });
  });
}
