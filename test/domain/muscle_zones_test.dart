import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/training/domain/exercise.dart';
import 'package:balancore/features/training/domain/muscle_zones.dart';

void main() {
  group('primaryZonesOf', () {
    test('mapea muscles finos a etiquetas ES', () {
      const e = Exercise(
        id: 'x',
        name: 'Curl de muñeca',
        muscleGroup: 'Brazo',
        primaryMuscles: ['forearms'],
      );
      expect(primaryZonesOf(e), ['Antebrazos']);
    });

    test('cae al grupo grueso si no hay músculos finos', () {
      const e = Exercise(id: 'x', name: 'Custom', muscleGroup: 'Pecho');
      expect(primaryZonesOf(e), ['Pecho']);
    });

    test('"Otro" si tampoco hay grupo', () {
      const e = Exercise(id: 'x', name: 'Custom', muscleGroup: '');
      expect(primaryZonesOf(e), ['Otro']);
    });
  });

  group('availableZones', () {
    test('respeta el orden canónico y agrega las presentes', () {
      const list = [
        Exercise(id: 'a', name: 'A', muscleGroup: 'Pierna', primaryMuscles: ['calves']),
        Exercise(id: 'b', name: 'B', muscleGroup: 'Pecho', primaryMuscles: ['chest']),
        Exercise(id: 'c', name: 'C', muscleGroup: 'Brazo', primaryMuscles: ['forearms']),
      ];
      expect(availableZones(list), ['Pecho', 'Antebrazos', 'Gemelos']);
    });
  });

  group('primaryZoneLabelFor (catálogo)', () {
    setUp(() {
      ExerciseCatalog.cache = [
        const Exercise(
          id: 'Cable_Wrist_Curl',
          name: 'Curl de muñeca',
          muscleGroup: 'Brazo',
          primaryMuscles: ['forearms'],
        ),
      ];
    });
    tearDown(() => ExerciseCatalog.cache = null);

    test('usa la zona fina del catálogo por id', () {
      expect(primaryZoneLabelFor('Cable_Wrist_Curl', 'Brazo'), 'Antebrazos');
    });

    test('cae al grupo si el id no está en el catálogo', () {
      expect(primaryZoneLabelFor('desconocido', 'Espalda'), 'Espalda');
    });
  });

  group('catálogo real (assets/exercises_fedb.json)', () {
    test('incluye ejercicios de antebrazo clasificados como "Antebrazos"', () {
      final raw = File('assets/exercises_fedb.json').readAsStringSync();
      final list = (jsonDecode(raw) as List)
          .map((m) => Exercise.fromFedbAsset((m as Map).cast<String, dynamic>()))
          .toList();
      final forearms = list
          .where((e) => primaryZonesOf(e).contains('Antebrazos'))
          .toList();
      expect(forearms, isNotEmpty,
          reason: 'Debe haber ejercicios cuya zona principal sea Antebrazos');
      expect(availableZones(list), contains('Antebrazos'));
    });
  });
}
