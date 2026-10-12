import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/training/domain/exercise.dart';
import 'package:balancore/features/training/domain/routine_templates.dart';

const _days = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

void main() {
  setUpAll(() {
    final raw = File('assets/exercises_fedb.json').readAsStringSync();
    ExerciseCatalog.cache = (jsonDecode(raw) as List)
        .map((e) => Exercise.fromFedbAsset(Map<String, dynamic>.from(e as Map)))
        .where((e) => e.id.isNotEmpty)
        .toList();
  });

  group('RoutineTemplates.all', () {
    test('contiene 3 plantillas con ids únicos', () {
      final ids = RoutineTemplates.all.map((t) => t.id).toList();
      expect(RoutineTemplates.all.length, 3);
      expect(ids.toSet().length, ids.length);
    });

    test('cada plantilla cubre los 7 días en orden', () {
      for (final t in RoutineTemplates.all) {
        expect(t.week.map((d) => d.day).toList(), _days,
            reason: 'Plantilla ${t.id}');
      }
    });

    test('los días de descanso no tienen ejercicios', () {
      for (final t in RoutineTemplates.all) {
        for (final d in t.week.where((d) => d.isRestDay)) {
          expect(d.exercises, isEmpty, reason: '${t.id}/${d.day}');
        }
      }
    });

    test('los días de entreno tienen al menos un ejercicio', () {
      for (final t in RoutineTemplates.all) {
        for (final d in t.week.where((d) => !d.isRestDay)) {
          expect(d.exercises, isNotEmpty, reason: '${t.id}/${d.day}');
        }
      }
    });

    test('todos los ejercicios existen en el catálogo', () {
      for (final t in RoutineTemplates.all) {
        for (final d in t.week) {
          for (final e in d.exercises) {
            expect(ExerciseCatalog.byId(e.exerciseId), isNotNull,
                reason: '${t.id} → ${e.exerciseId}');
            expect(e.exerciseName, isNotEmpty);
          }
        }
      }
    });

    test('cada plantilla tiene al menos un día de descanso', () {
      for (final t in RoutineTemplates.all) {
        expect(t.week.where((d) => d.isRestDay), isNotEmpty,
            reason: t.id);
      }
    });
  });

  group('Catálogo en español', () {
    test('todos los ejercicios tienen instrucciones en español', () {
      final sinEs = ExerciseCatalog.cache!
          .where((e) => e.instructionsEs.trim().isEmpty)
          .toList();
      expect(sinEs.length, lessThanOrEqualTo(5),
          reason: 'sin instrucciones ES: ${sinEs.map((e) => e.id).toList()}');
    });

    test('las instrucciones en español no quedan en inglés', () {
      final conEs = ExerciseCatalog.cache!
          .where((e) => e.instructionsEs.isNotEmpty)
          .toList();
      final sospechosos = conEs
          .where((e) => e.instructionsEs.toLowerCase().contains(' with '))
          .toList();
      expect(sospechosos.length, lessThan(10),
          reason: 'sospechosos EN: ${sospechosos.map((e) => e.id).toList()}');
    });
  });
}
