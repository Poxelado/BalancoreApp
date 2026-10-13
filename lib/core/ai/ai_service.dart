import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/profile/domain/user_profile.dart';
import 'ai_key_store.dart';

/// Servicio de IA para generar rutinas.
///
/// La app no depende de que haya clave configurada: [RoutineAiServiceImpl]
/// cae al generador de reglas cuando no hay clave, falla la red o el modelo
/// responde algo que no se puede validar.
abstract class RoutineAiService {
  /// true si el usuario trajo su propia clave de Gemini.
  bool get hasKey;

  /// Genera una rutina. Devuelve null si la IA no pudo y hay que usar las
  /// reglas.
  Future<List<RoutineDay>?> generate({
    required RoutineAiContext context,
    required List<AiExercise> allowedExercises,
  });

  Future<void> saveKey(String key);
  Future<void> clearKey();
}

/// Datos del usuario que se envían al modelo (con aviso de privacidad).
class RoutineAiContext {
  final String goal;
  final int daysPerWeek;
  final String level;
  final List<String> equipment;
  final double? weight;
  final int? age;
  final String? sex;
  final int? streakDays;

  const RoutineAiContext({
    required this.goal,
    required this.daysPerWeek,
    required this.level,
    this.equipment = const [],
    this.weight,
    this.age,
    this.sex,
    this.streakDays,
  });
}

/// Ejercicio que el modelo puede elegir, ya validado contra el catálogo.
class AiExercise {
  final String id;
  final String name;
  final String muscleGroup;

  const AiExercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
  });

  factory AiExercise.fromMap(Map<String, dynamic> m) => AiExercise(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        muscleGroup: m['muscleGroup']?.toString() ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup,
      };
}

/// Implementación contra la API de Gemini (BYO key).
class RoutineAiServiceImpl implements RoutineAiService {
  final http.Client _client;

  /// Modelo con salida en JSON. No es el más potente, pero es el que mejor
  /// ratio tiene entre calidad de respuesta estructurada y cuota gratuita.
  static const _model = 'gemini-2.0-flash';
  static const _endpoint = 'generativelanguage.googleapis.com';

  RoutineAiServiceImpl({http.Client? client})
      : _client = client ?? http.Client();

  String? _key;

  @override
  bool get hasKey => (_key ?? '').isNotEmpty;

  @override
  Future<void> saveKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return clearKey();
    await AiKeyStore.save(trimmed);
    _key = trimmed;
  }

  @override
  Future<void> clearKey() async {
    await AiKeyStore.clear();
    _key = null;
  }

  /// Carga la clave guardada (local, no se sincroniza).
  Future<void> load() async {
    _key = await AiKeyStore.read();
  }

  @override
  Future<List<RoutineDay>?> generate({
    required RoutineAiContext context,
    required List<AiExercise> allowedExercises,
  }) async {
    if (!hasKey) return null;
    final prompt = buildRoutinePrompt(
      context: context,
      allowedExercises: allowedExercises,
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.7,
      },
    });

    final uri = Uri.https(_endpoint, '/v1beta/models/$_model:generateContent', {
      'key': _key!,
    });

    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode != 200) {
      // 429 = cuota agotada, 400 = clave inválida: en ambos casos se cae al
      // generador de reglas sin molestar al usuario con un error técnico.
      return null;
    }
    final decoded = jsonDecode(res.body);
    final text = extractFirstText(decoded);
    if (text == null) return null;
    return parseRoutineJson(text, allowedExercises);
  }
}

/// Saca el texto de la respuesta de Gemini.
String? extractFirstText(dynamic decoded) {
  if (decoded is! Map) return null;
  final candidates = decoded['candidates'];
  if (candidates is! List || candidates.isEmpty) return null;
  final content = candidates.first['content'];
  if (content is! Map) return null;
  final parts = content['parts'];
  if (parts is! List || parts.isEmpty) return null;
  final text = parts.first['text'];
  if (text is! String || text.trim().isEmpty) return null;
  return text;
}

/// Prompt de generación de rutina.
String buildRoutinePrompt({
  required RoutineAiContext context,
  required List<AiExercise> allowedExercises,
}) {
  final ctx = context;
  final userGoalLabel = ctx.goal;
  final buf = StringBuffer()
    ..writeln('Eres un entrenador de fuerza. Diseña una rutina de musculación.')
    ..writeln('')
    ..writeln('DATOS DEL USUARIO:')
    ..writeln('- Objetivo: $userGoalLabel')
    ..writeln('- Días por semana: ${ctx.daysPerWeek}')
    ..writeln('- Nivel: ${ctx.level}')
    ..writeln('- Equipamiento: ${ctx.equipment.isEmpty ? 'gimnasio completo' : ctx.equipment.join(', ')}');
  if (ctx.weight != null) buf.writeln('- Peso: ${ctx.weight} kg');
  if (ctx.age != null) buf.writeln('- Edad: ${ctx.age}');
  if (ctx.sex != null) buf.writeln('- Sexo: ${ctx.sex}');
  buf
    ..writeln('')
    ..writeln('REGLAS:')
    ..writeln('- Usa SOLO los ids de ejercicio de la lista EXERCICIOS.')
    ..writeln('- No repitas el mismo id dentro de un mismo día.')
    ..writeln('- Cada día entre 4 y 7 ejercicios.')
    ..writeln('- Prioriza ejercicios compuestos al inicio del día.')
    ..writeln('- Respeta el número de días indicado.')
    ..writeln('')
    ..writeln('Responde SOLO con este JSON, sin texto antes ni después:')
    ..writeln('''{
  "days": [
    {
      "day": "Lunes",
      "title": "Pecho y tríceps",
      "exercises": [
        {"id": "...", "sets": 4, "reps": 10, "restSeconds": 90}
      ]
    }
  ]
}''')
    ..writeln('')
    ..writeln('EJERCICIOS:');
  for (final e in allowedExercises) {
    buf.writeln('${e.id} | ${e.name} | ${e.muscleGroup}');
  }
  return buf.toString();
}

/// Convierte la respuesta del modelo en una rutina válida.
///
/// Es la red de seguridad del sistema: descarta lo que no se pueda validar
/// (ids inventados, JSON roto) para que un error del modelo nunca rompa la
/// app ni proponga ejercicios que no existen.
List<RoutineDay>? parseRoutineJson(
  String text,
  List<AiExercise> allowedExercises,
) {
  final cleaned = _stripCodeFence(text);
  dynamic decoded;
  try {
    decoded = jsonDecode(cleaned);
  } catch (_) {
    return null;
  }
  if (decoded is! Map) return null;
  final rawDays = decoded['days'];
  if (rawDays is! List || rawDays.isEmpty) return null;

  final byId = {for (final e in allowedExercises) e.id: e};
  final days = <RoutineDay>[];
  const names = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  for (var i = 0; i < rawDays.length && i < names.length; i++) {
    final raw = rawDays[i];
    if (raw is! Map) continue;
    final rawEx = raw['exercises'];
    if (rawEx is! List) continue;

    final exercises = <RoutineExercise>[];
    // Solo dentro del mismo día: repetir un ejercicio entre días es normal
    // (un tren superior A y un B comparten press de banca).
    final seenInDay = <String>{};
    for (final item in rawEx) {
      if (item is! Map) continue;
      final id = item['id']?.toString() ?? '';
      final ex = byId[id];
      // Id que no existe en el catálogo → se descarta, no se inventa.
      if (ex == null || !seenInDay.add(id)) continue;
      final sets = _clampInt(item['sets'], 1, 10, 3);
      final reps = _clampInt(item['reps'], 1, 30, 10);
      final rest = _clampInt(item['restSeconds'], 30, 300, 90);
      exercises.add(
        RoutineExercise(
          exerciseId: ex.id,
          exerciseName: ex.name,
          muscleGroup: ex.muscleGroup,
          sets: sets,
          reps: reps,
          restSeconds: rest,
          plannedSets: List.generate(
            sets,
            (_) => PlannedSet(weight: 0, reps: reps),
          ),
        ),
      );
    }
    if (exercises.isEmpty) continue;
    days.add(
      RoutineDay(
        day: names[i],
        title: raw['title']?.toString().trim().isNotEmpty == true
            ? raw['title'].toString().trim()
            : 'Día ${i + 1}',
        description: exercises.map((e) => e.muscleGroup).toSet().join(' · '),
        exercises: exercises,
      ),
    );
  }

  if (days.isEmpty) return null;
  return days;
}

String _stripCodeFence(String text) {
  var t = text.trim();
  if (!t.startsWith('```')) return t;
  t = t.substring(3);
  final nl = t.indexOf('\n');
  if (nl >= 0 && !t.substring(0, nl).trim().contains('{')) {
    t = t.substring(nl + 1);
  }
  return t.replaceAll(RegExp(r'```\s*$'), '').trim();
}

int _clampInt(dynamic value, int min, int max, int fallback) {
  final n = value is num ? value.round() : int.tryParse('$value');
  if (n == null) return fallback;
  return n.clamp(min, max);
}