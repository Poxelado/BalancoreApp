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
}
