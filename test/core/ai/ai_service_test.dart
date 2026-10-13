import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/core/ai/ai_key_store.dart';
import 'package:balancore/core/ai/ai_service.dart';

const _allowed = [
  AiExercise(id: 'a1', name: 'Press banca', muscleGroup: 'Pecho'),
  AiExercise(id: 'a2', name: 'Sentadilla', muscleGroup: 'Pierna'),
  AiExercise(id: 'a3', name: 'Remo', muscleGroup: 'Espalda'),
];

void main() {
  group('parseRoutineJson', () {
    test('convierte una respuesta válida', () {
      final days = parseRoutineJson(
        jsonEncode({
          'days': [
            {
              'day': 'Lunes',
              'title': 'Pecho',
              'exercises': [
                {'id': 'a1', 'sets': 4, 'reps': 8, 'restSeconds': 90},
                {'id': 'a2', 'sets': 3, 'reps': 12, 'restSeconds': 60},
              ],
            },
          ],
        }),
        _allowed,
      );
      expect(days, isNotNull);
      expect(days!.length, 1);
      expect(days.first.title, 'Pecho');
      expect(days.first.exercises.length, 2);
      expect(days.first.exercises.first.exerciseId, 'a1');
      expect(days.first.exercises.first.exerciseName, 'Press banca');
      expect(days.first.exercises.first.sets, 4);
      expect(days.first.exercises.first.reps, 8);
      expect(days.first.exercises.first.restSeconds, 90);
    });

    test('descarta ids que no existen en el catálogo', () {
      final days = parseRoutineJson(
        jsonEncode({
          'days': [
            {
              'title': 'X',
              'exercises': [
                {'id': 'inventado', 'sets': 3, 'reps': 10},
                {'id': 'a1', 'sets': 3, 'reps': 10},
              ],
            },
          ],
        }),
        _allowed,
      );
      expect(days!.first.exercises.length, 1);
      expect(days.first.exercises.single.exerciseId, 'a1');
    });

    test('elimina ids repetidos dentro de un mismo día', () {
      final days = parseRoutineJson(
        jsonEncode({
          'days': [
            {
              'title': 'X',
              'exercises': [
                {'id': 'a1', 'sets': 3, 'reps': 10},
                {'id': 'a1', 'sets': 3, 'reps': 10},
              ],
            },
          ],
        }),
        _allowed,
      );
      expect(days!.first.exercises.length, 1);
    });

    test('permite repetir un ejercicio entre días distintos', () {
      // Un tren superior A y un B comparten press de banca: es correcto.
      final days = parseRoutineJson(
        jsonEncode({
          'days': [
            {
              'title': 'Superior A',
              'exercises': [
                {'id': 'a1'},
              ],
            },
            {
              'title': 'Superior B',
              'exercises': [
                {'id': 'a1'},
              ],
            },
          ],
        }),
        _allowed,
      );
      expect(days!.length, 2);
      expect(days.map((d) => d.exercises.single.exerciseId), ['a1', 'a1']);
    });

    test('JSON roto devuelve null en vez de lanzar', () {
      expect(parseRoutineJson('{esto no es json', _allowed), isNull);
    });

    test('respuesta sin días devuelve null', () {
      expect(parseRoutineJson(jsonEncode({'days': []}), _allowed), isNull);
      expect(parseRoutineJson(jsonEncode({'otra': 1}), _allowed), isNull);
    });

    test('un día sin ejercicios válidos se descarta', () {
      final days = parseRoutineJson(
        jsonEncode({
          'days': [
            {
              'title': 'Vacío',
              'exercises': [
                {'id': 'no_existe', 'sets': 3, 'reps': 10},
              ],
            },
          ],
        }),
        _allowed,
      );
      expect(days, isNull);
    });

    test('acepta la respuesta envuelta en bloque de código', () {
      final days = parseRoutineJson(
        '```json\n${jsonEncode({
          'days': [
            {
              'title': 'Pecho',
              'exercises': [
                {'id': 'a1', 'sets': 3, 'reps': 10},
              ],
            },
          ],
        })}\n```',
        _allowed,
      );
      expect(days, isNotNull);
      expect(days!.first.exercises.single.exerciseId, 'a1');
    });

    test('normaliza los días a los nombres de la semana', () {
      final days = parseRoutineJson(
        jsonEncode({
          'days': [
            {
              'day': 'Lo que el modelo quiera',
              'title': 'A',
              'exercises': [
                {'id': 'a1', 'sets': 3, 'reps': 10},
              ],
            },
            {
              'day': 'otro',
              'title': 'B',
              'exercises': [
                {'id': 'a2', 'sets': 3, 'reps': 10},
              ],
            },
          ],
        }),
        _allowed,
      );
      expect(days!.map((d) => d.day), ['Lunes', 'Martes']);
    });

    test('acota series, reps y descanso a rangos sensatos', () {
      final days = parseRoutineJson(
        jsonEncode({
          'days': [
            {
              'title': 'X',
              'exercises': [
                {'id': 'a1', 'sets': 999, 'reps': 999, 'restSeconds': 5},
                {'id': 'a2', 'sets': -3, 'reps': -1, 'restSeconds': 9999},
              ],
            },
          ],
        }),
        _allowed,
      );
      final e = days!.first.exercises;
      expect(e[0].sets, lessThanOrEqualTo(10));
      expect(e[0].reps, lessThanOrEqualTo(30));
      expect(e[0].restSeconds, greaterThanOrEqualTo(30));
      expect(e[1].sets, greaterThanOrEqualTo(1));
      expect(e[1].restSeconds, lessThanOrEqualTo(300));
    });

    test('usa valores por defecto cuando faltan', () {
      final days = parseRoutineJson(
        jsonEncode({
          'days': [
            {
              'title': 'X',
              'exercises': [
                {'id': 'a1'},
              ],
            },
          ],
        }),
        _allowed,
      );
      final e = days!.first.exercises.single;
      expect(e.sets, 3);
      expect(e.reps, 10);
      expect(e.restSeconds, 90);
    });

    test('da nombre por defecto a un día sin título', () {
      final days = parseRoutineJson(
        jsonEncode({
          'days': [
            {
              'exercises': [
                {'id': 'a1'},
              ],
            },
          ],
        }),
        _allowed,
      );
      expect(days!.first.title, 'Día 1');
    });

    test('las series planificadas cuadran con sets y reps', () {
      final days = parseRoutineJson(
        jsonEncode({
          'days': [
            {
              'title': 'X',
              'exercises': [
                {'id': 'a1', 'sets': 4, 'reps': 6},
              ],
            },
          ],
        }),
        _allowed,
      );
      final e = days!.first.exercises.single;
      expect(e.effectiveSets.length, 4);
      expect(e.effectiveSets.every((s) => s.reps == 6), isTrue);
      expect(e.effectiveSets.every((s) => s.weight == 0), isTrue);
    });

    test('no genera más de siete días', () {
      final days = parseRoutineJson(
        jsonEncode({
          'days': [
            for (var i = 0; i < 12; i++)
              {
                'title': 'Dia $i',
                'exercises': [
                  {'id': 'a1'},
                ],
              },
          ],
        }),
        _allowed,
      );
      expect(days!.length, 7);
      expect(days.map((d) => d.day).last, 'Domingo');
    });
  });

  group('extractFirstText', () {
    test('saca el texto de una respuesta bien formada', () {
      final text = extractFirstText({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '{"days":[]}'},
              ],
            },
          },
        ],
      });
      expect(text, '{"days":[]}');
    });

    test('devuelve null con respuestas raras', () {
      expect(extractFirstText(null), isNull);
      expect(extractFirstText({}), isNull);
      expect(extractFirstText({'candidates': []}), isNull);
      expect(extractFirstText({
        'candidates': [
          {'content': {}},
        ],
      }), isNull);
      expect(extractFirstText({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '   '},
              ],
            },
          },
        ],
      }), isNull);
    });
  });

  group('buildRoutinePrompt', () {
    test('incluye los datos del usuario y la lista de ejercicios', () {
      final prompt = buildRoutinePrompt(
        context: const RoutineAiContext(
          goal: 'Ganar músculo',
          daysPerWeek: 4,
          level: 'Intermedio',
          equipment: ['Barra', 'Mancuernas'],
          weight: 80,
          age: 30,
          sex: 'Masculino',
        ),
        allowedExercises: _allowed,
      );
      expect(prompt, contains('Ganar músculo'));
      expect(prompt, contains('4'));
      expect(prompt, contains('Intermedio'));
      expect(prompt, contains('Barra'));
      expect(prompt, contains('Peso: 80.0 kg'));
      expect(prompt, contains('Press banca'));
      expect(prompt, contains('a1'));
    });

    test('sin equipamiento dice gimnasio completo', () {
      final prompt = buildRoutinePrompt(
        context: const RoutineAiContext(
          goal: 'Mantenimiento',
          daysPerWeek: 3,
          level: 'Principiante',
        ),
        allowedExercises: _allowed,
      );
      expect(prompt, contains('gimnasio completo'));
      // Sin objetivo explícito pide un rango razonable, no el mínimo.
      expect(prompt, contains('entre 6 y 8 ejercicios'));
    });

    test('con tiempo y objetivo pide exactamente esos ejercicios', () {
      final prompt = buildRoutinePrompt(
        context: const RoutineAiContext(
          goal: 'Ganar músculo',
          daysPerWeek: 4,
          level: 'Intermedio',
          minutesAvailable: 60,
          targetExercisesPerDay: 6,
        ),
        allowedExercises: _allowed,
      );
      expect(prompt, contains('Tiempo por sesión: 60 min'));
      expect(prompt, contains('EXACTAMENTE 6 ejercicios'));
    });
  });

  group('AiKeyStore', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('guarda, lee y borra la clave', () async {
      expect(await AiKeyStore.read(), isNull);
      expect(await AiKeyStore.hasKey(), isFalse);

      await AiKeyStore.save('  abc123  ');
      expect(await AiKeyStore.read(), 'abc123');
      expect(await AiKeyStore.hasKey(), isTrue);

      await AiKeyStore.clear();
      expect(await AiKeyStore.read(), isNull);
    });

    test('una clave en blanco no cuenta como configurada', () async {
      await AiKeyStore.save('   ');
      expect(await AiKeyStore.read(), isNull);
    });
  });

  group('resolveAiKey', () {
    test('la clave del usuario manda sobre la incorporada', () {
      expect(resolveAiKey(userKey: 'usr', embedded: 'app'), 'usr');
    });

    test('si el usuario no tiene, se usa la incorporada', () {
      expect(resolveAiKey(userKey: null, embedded: 'app'), 'app');
      expect(resolveAiKey(userKey: '  ', embedded: 'app'), 'app');
    });

    test('sin ninguna clave no hay IA', () {
      expect(resolveAiKey(userKey: null, embedded: null), isNull);
      expect(resolveAiKey(userKey: '  ', embedded: '  '), isNull);
      expect(resolveAiKey(userKey: '', embedded: ''), isNull);
    });
  });

  group('RoutineAiServiceImpl.load', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('toma la clave del usuario guardada', () async {
      await AiKeyStore.save('AIza-user');
      final service = RoutineAiServiceImpl();
      await service.load();
      expect(service.hasKey, isTrue);
    });

    test('sin clave del usuario ni incorporada no hay IA', () async {
      final service = RoutineAiServiceImpl();
      await service.load();
      // En los tests no se compila con --dart-define, así que no hay clave.
      expect(service.hasKey, isFalse);
      expect(kEmbeddedGeminiKey, isEmpty);
    });
  });
}