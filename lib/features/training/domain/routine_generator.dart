import 'dart:math';

import '../../profile/domain/user_profile.dart';
import 'exercise.dart';

enum RoutineGoal {
  perderGrasa('Perder grasa'),
  mantenimiento('Mantenimiento'),
  ganarMusculo('Ganar músculo');

  final String label;
  const RoutineGoal(this.label);

  static RoutineGoal fromLabel(String? label) {
    final v = (label ?? '').toLowerCase();
    if (v.contains('fuerza') || v.contains('rendimiento')) return ganarMusculo;
    for (final g in values) {
      if (g.label.toLowerCase() == v) return g;
    }
    return RoutineGoal.mantenimiento;
  }
}

enum RoutineLevel {
  principiante('Principiante'),
  intermedio('Intermedio'),
  avanzado('Avanzado');

  final String label;
  const RoutineLevel(this.label);

  static RoutineLevel fromLabel(String? label) => values.firstWhere(
        (l) => l.label.toLowerCase() == (label ?? '').toLowerCase(),
        orElse: () => RoutineLevel.intermedio,
      );
}

class RoutineRequest {
  final RoutineGoal goal;
  final RoutineLevel level;
  final int daysPerWeek;
  final Set<String> equipment;
  final int? minutesAvailable;
  final List<Exercise> catalog;
  final int? seed;

  const RoutineRequest({
    required this.goal,
    required this.level,
    required this.daysPerWeek,
    required this.catalog,
    this.equipment = const {},
    this.minutesAvailable,
    this.seed,
  });
}

const _allDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

const _bannedWords = ['arrancada', 'cargada', 'envión', 'envion', 'snatch', 'clean', 'otis', 'aleteo', 'plié', 'plie', 'pallof', 'turco', 'renegado'];

/// Ejercicio canónico permitido. Nunca se inventa un nombre: cada canónico se
/// resuelve contra el catálogo real y, si no existe, ese hueco no se rellena.
class _Canon {
  final String name;
  final String muscle;
  final String equip;
  final bool compound;
  final List<String> all;
  final List<String> any;
  final List<String> none;
  final List<String> prefer;

  const _Canon({
    required this.name,
    required this.muscle,
    required this.equip,
    required this.compound,
    this.all = const [],
    this.any = const [],
    this.none = const [],
    this.prefer = const [],
  });

  bool matches(String raw) {
    final n = raw.toLowerCase();
    for (final a in all) {
      if (!n.contains(a)) return false;
    }
    if (any.isNotEmpty && !any.any(n.contains)) return false;
    for (final x in none) {
      if (n.contains(x)) return false;
    }
    return true;
  }
}

// ---------------- Upper / Push ----------------
const _pressBancaM = _Canon(name: 'Press banca con mancuernas', muscle: 'Pecho', equip: 'Mancuernas', compound: true, all: ['press de banca'], none: ['inclinado', 'declinado', 'una mano', 'neutro', 'cerrado', 'invertido']);
const _pressBancaB = _Canon(name: 'Press banca con barra', muscle: 'Pecho', equip: 'Barra', compound: true, all: ['press de banca'], none: ['inclinado', 'declinado', 'cerrado', 'invertido', 'smith', 'máquina', 'maquina', 'cadenas', 'bandas', 'powerlifting', 'guillotina', 'mancuerna', 'una mano']);
const _pressInclinadoM = _Canon(name: 'Press inclinado con mancuernas', muscle: 'Pecho', equip: 'Mancuernas', compound: true, all: ['press inclinado'], none: ['bent press', 'smith', 'barra', 'kettlebell', 'pesa rusa']);
const _fondos = _Canon(name: 'Fondos en paralelas', muscle: 'Pecho', equip: 'Peso corporal', compound: true, all: ['fondos'], none: ['banco', 'máquina', 'maquina'], prefer: ['Fondos en paralelas']);
const _pressMilitarM = _Canon(name: 'Press militar con mancuernas', muscle: 'Hombro', equip: 'Mancuernas', compound: true, any: ['press militar', 'press de hombros'], none: ['barra', 'pesa rusa', 'máquina', 'maquina', 'una mano', 'smith', 'polea', 'banda', 'alterno'], prefer: ['Press de hombros con mancuernas']);
const _pressMilitarB = _Canon(name: 'Press militar con barra', muscle: 'Hombro', equip: 'Barra', compound: true, any: ['press militar', 'press de hombros'], none: ['mancuerna', 'pesa rusa', 'máquina', 'maquina', 'una mano', 'smith', 'polea', 'banda', 'alterno'], prefer: ['Press militar de pie', 'Press de hombros con barra']);
const _laterales = _Canon(name: 'Elevaciones laterales', muscle: 'Hombro', equip: 'Mancuernas', compound: false, all: ['elevaci', 'lateral'], none: ['posterior', 'inclinado', 'tumbado', 'polea', 'banda', 'frontal'], prefer: ['Elevación lateral', 'Elevaciones laterales a una mano']);
const _tricepsPolea = _Canon(name: 'Extensiones de tríceps en polea', muscle: 'Brazo', equip: 'Polea', compound: false, all: ['extensión de tríceps'], none: ['inclinado'], prefer: ['Extensión de tríceps sobre la cabeza en polea con cuerda', 'Extensión de tríceps tumbado en polea']);
const _pressFrances = _Canon(name: 'Press francés', muscle: 'Brazo', equip: 'Barra', compound: false, all: ['press francés'], none: ['banda'], prefer: ['Press francés con barra EZ']);

// ---------------- Pull ----------------
const _dominadas = _Canon(name: 'Dominadas', muscle: 'Espalda', equip: 'Peso corporal', compound: true, all: ['dominada'], none: ['crunch', 'asistida', 'banda', 'mixto', 'supina a una mano']);
const _jalones = _Canon(name: 'Jalones al pecho', muscle: 'Espalda', equip: 'Polea', compound: true, all: ['jal'], any: ['pecho'], none: ['brazos rectos', 'sumo'], prefer: ['Jalón al pecho de rango completo', 'Jalón al pecho con agarre amplio']);
const _remoBarra = _Canon(name: 'Remo con barra', muscle: 'Espalda', equip: 'Barra', compound: true, all: ['remo'], none: ['mancuerna', 'pesa rusa', 'polea', 'máquina', 'maquina', 'una mano', 'banda', 'kettlebell', 'renegado'], prefer: ['Remo con barra inclinado']);
const _remoMancuerna = _Canon(name: 'Remo a una mano con mancuerna', muscle: 'Espalda', equip: 'Mancuernas', compound: true, all: ['remo'], none: ['barra', 'polea', 'máquina', 'maquina', 'banda', 'kettlebell', 'renegado'], prefer: ['Remo inclinado a una mano con mancuerna', 'Remo con mancuerna']);
const _facePulls = _Canon(name: 'Face pulls', muscle: 'Hombro', equip: 'Polea', compound: false, any: ['face pull', 'a la cara']);
const _curlBarra = _Canon(name: 'Curl con barra', muscle: 'Brazo', equip: 'Barra', compound: false, all: ['curl'], any: ['barra'], none: ['mancuerna', 'polea', 'máquina', 'maquina', 'martillo', 'femoral', 'muñeca', 'predicador', 'inclinado', 'tumbado'], prefer: ['Curl con barra']);
const _curlMancuernas = _Canon(name: 'Curl con mancuernas', muscle: 'Brazo', equip: 'Mancuernas', compound: false, all: ['curl'], any: ['mancuerna'], none: ['barra', 'polea', 'máquina', 'maquina', 'femoral', 'muñeca', 'predicador', 'inclinado', 'tumbado', 'martillo'], prefer: ['Curl de bíceps con mancuernas']);

// ---------------- Lower ----------------
const _sentadillaBarra = _Canon(name: 'Sentadilla con barra', muscle: 'Pierna', equip: 'Barra', compound: true, all: ['sentadilla'], none: ['goblet', 'búlgara', 'bulgara', 'hack', 'lateral', 'sissy', 'pistol', 'banco', 'cajón', 'cajon', 'turco', 'smith', 'mancuerna', 'kettlebell', 'una pierna', 'olímpica'], prefer: ['Sentadilla con barra']);
const _sentadillaCajon = _Canon(name: 'Sentadilla de cajón', muscle: 'Pierna', equip: 'Barra', compound: true, all: ['sentadilla'], any: ['cajón', 'cajon']);
const _prensa = _Canon(name: 'Prensa de piernas', muscle: 'Pierna', equip: 'Máquina', compound: true, all: ['prensa de piernas'], none: ['gemelo', 'estrecha', 'smith'], prefer: ['Prensa de piernas']);
const _pesoMuertoRumano = _Canon(name: 'Peso muerto rumano', muscle: 'Pierna', equip: 'Barra', compound: true, all: ['peso muerto rumano'], none: ['déficit'], prefer: ['Peso muerto rumano']);
const _hipThrust = _Canon(name: 'Hip thrust', muscle: 'Pierna', equip: 'Barra', compound: true, any: ['hip thrust', 'puente de glúteos'], none: ['una pierna', 'pelota'], prefer: ['Hip thrust', 'Puente de glúteos con barra']);
const _zancadas = _Canon(name: 'Zancadas con mancuernas', muscle: 'Pierna', equip: 'Mancuernas', compound: true, all: ['zancada'], any: ['mancuerna'], none: ['barra', 'turco'], prefer: ['Zancadas con mancuernas']);
const _bulgara = _Canon(name: 'Sentadilla búlgara', muscle: 'Pierna', equip: 'Mancuernas', compound: true, all: ['búlgara'], none: ['smith', 'suspensión'], prefer: ['Sentadilla búlgara con mancuernas']);
const _femoral = _Canon(name: 'Curl femoral', muscle: 'Pierna', equip: 'Máquina', compound: false, all: ['curl femoral'], none: ['pelota', 'banda', 'manual'], prefer: ['Curl femoral tumbado', 'Curl femoral sentado']);
const _gemelos = _Canon(name: 'Elevaciones de gemelos', muscle: 'Pierna', equip: 'Máquina', compound: false, all: ['gemelos'], none: ['encogimientos', 'prensa'], prefer: ['Elevación de gemelos de pie', 'Elevación de gemelos sentado con barra']);

// ---------------- Core ----------------
const _plancha = _Canon(name: 'Plancha', muscle: 'Core', equip: 'Peso corporal', compound: false, all: ['plancha'], none: ['lateral', 'flexión', 'caminando'], prefer: ['Plancha']);
const _crunch = _Canon(name: 'Crunch', muscle: 'Core', equip: 'Peso corporal', compound: false, all: ['crunch'], none: ['polea', 'bosu', 'máquina', 'maquina', 'inverso', 'cruzando'], prefer: ['Crunch']);
const _elevacionPiernas = _Canon(name: 'Elevación de piernas', muscle: 'Core', equip: 'Peso corporal', compound: false, all: ['elevación de piernas'], none: ['colgado', 'banco', 'bottoms'], prefer: ['Elevación de piernas']);

const _upperPlan = [
  [_pressBancaM, _pressBancaB, _pressInclinadoM],
  [_dominadas, _jalones],
  [_pressInclinadoM, _pressBancaM],
  [_remoBarra, _remoMancuerna],
  [_pressMilitarM, _pressMilitarB],
  [_facePulls, _laterales],
  [_curlBarra, _curlMancuernas],
  [_tricepsPolea, _pressFrances],
];

const _pushPlan = [
  [_pressBancaM, _pressBancaB, _fondos],
  [_pressInclinadoM, _pressBancaM],
  [_pressMilitarM, _pressMilitarB],
  [_laterales],
  [_tricepsPolea, _pressFrances],
  [_fondos, _pressBancaM],
  [_pressFrances, _tricepsPolea],
  [_laterales, _pressMilitarM],
];

const _pullPlan = [
  [_dominadas, _jalones],
  [_remoBarra, _remoMancuerna],
  [_remoMancuerna, _remoBarra],
  [_facePulls],
  [_curlBarra, _curlMancuernas],
  [_curlMancuernas, _curlBarra],
  [_jalones, _dominadas],
  [_facePulls],
];

const _lowerPlan = [
  [_sentadillaBarra, _sentadillaCajon, _prensa],
  [_pesoMuertoRumano, _hipThrust],
  [_zancadas, _bulgara],
  [_femoral],
  [_gemelos],
  [_prensa, _sentadillaBarra],
  [_hipThrust, _pesoMuertoRumano],
  [_bulgara, _zancadas],
];

const _fullBodyPlan = [
  [_sentadillaBarra, _sentadillaCajon, _prensa],
  [_pressBancaM, _pressInclinadoM, _fondos],
  [_remoBarra, _dominadas, _jalones],
  [_pesoMuertoRumano, _hipThrust],
  [_pressMilitarM, _pressMilitarB, _laterales],
  [_plancha, _crunch, _elevacionPiernas],
  [_curlBarra, _tricepsPolea],
  [_gemelos],
];

List<String> splitFor(int days) {
  switch (days) {
    case 2:
      return ['Full Body A', 'Full Body B'];
    case 3:
      return ['Full Body A', 'Full Body B', 'Full Body C'];
    case 4:
      return ['Upper', 'Lower', 'Upper', 'Lower'];
    case 5:
      return ['Push', 'Pull', 'Legs', 'Upper', 'Lower'];
    case 6:
      return ['Push', 'Pull', 'Legs', 'Push', 'Pull', 'Legs'];
    default:
      return ['Push', 'Pull', 'Legs', 'Push', 'Pull', 'Legs', 'Full Body'];
  }
}

String normalizeFocus(String focus) {
  if (focus.contains('Full Body')) return 'Full Body';
  if (focus == 'Upper') return 'Upper';
  if (focus == 'Lower') return 'Lower';
  if (focus == 'Push') return 'Push';
  if (focus == 'Pull') return 'Pull';
  if (focus == 'Legs') return 'Legs';
  return 'Full Body';
}

List<List<_Canon>> _planFor(String focus) {
  switch (normalizeFocus(focus)) {
    case 'Upper':
      return _upperPlan;
    case 'Push':
      return _pushPlan;
    case 'Pull':
      return _pullPlan;
    case 'Lower':
    case 'Legs':
      return _lowerPlan;
    default:
      return _fullBodyPlan;
  }
}

bool _banned(String raw) => _bannedWords.any(raw.toLowerCase().contains);

bool _isDeadliftLikeName(String raw) {
  final n = raw.toLowerCase();
  if (n.contains('peso muerto') || n.contains('deadlift')) return true;
  if (n.contains('sumo') || n.contains('stiff')) return true;
  return false;
}

bool _isSquatLikeName(String raw) {
  final n = raw.toLowerCase();
  if (n.contains('sentadilla') || n.contains('squat')) return true;
  if (n.contains('prensa')) return true;
  if (n.contains('zancada') || n.contains('lunge') || n.contains('búlgar') || n.contains('bulgar')) return true;
  return false;
}

bool _isHipThrustLikeName(String raw) {
  final n = raw.toLowerCase();
  return n.contains('hip thrust') || (n.contains('puente') && n.contains('glúte')) || n.contains('glute bridge');
}

bool _isAllowedName(String raw, String focus) {
  final n = raw.toLowerCase();
  if (_banned(n)) return false;
  final f = normalizeFocus(focus);
  if (f == 'Upper' || f == 'Push' || f == 'Pull') {
    if (_isDeadliftLikeName(n) || _isSquatLikeName(n) || _isHipThrustLikeName(n)) return false;
  }
  return true;
}

Exercise? _resolve(_Canon canon, List<Exercise> catalog, Set<String> equipment) {
  final matches = catalog.where((e) => canon.matches(e.name) && !_banned(e.name)).toList();
  if (matches.isEmpty) return null;

  bool equipmentOk(Exercise e) {
    if (equipment.isEmpty) return true;
    if (e.equipment == 'Peso corporal') return true;
    if (e.equipment == 'Gimnasio') return true;
    return equipment.contains(e.equipment);
  }

  final withEquipment = matches.where(equipmentOk).toList();
  final pool = withEquipment.isNotEmpty ? withEquipment : matches;
  pool.sort((a, b) {
    final ap = canon.prefer.contains(a.name) ? 0 : 1;
    final bp = canon.prefer.contains(b.name) ? 0 : 1;
    if (ap != bp) return ap.compareTo(bp);
    final ae = a.equipment == canon.equip ? 0 : 1;
    final be = b.equipment == canon.equip ? 0 : 1;
    if (ae != be) return ae.compareTo(be);
    return a.name.length.compareTo(b.name.length);
  });
  return pool.first;
}

bool _hasCanonicalCatalog(List<Exercise> catalog) {
  for (final plan in [_upperPlan, _pushPlan, _pullPlan, _lowerPlan, _fullBodyPlan]) {
    for (final tier in plan) {
      for (final canon in tier) {
        if (catalog.any((e) => canon.matches(e.name) && !_banned(e.name))) {
          return true;
        }
      }
    }
  }
  return false;
}

bool _isCompoundExercise(Exercise e) {
  if (e.mechanic == 'compound') return true;
  for (final plan in [_upperPlan, _pushPlan, _pullPlan, _lowerPlan, _fullBodyPlan]) {
    for (final tier in plan) {
      for (final canon in tier) {
        if (canon.compound && canon.matches(e.name)) return true;
      }
    }
  }
  return false;
}

int _targetCount(int? minutes) {
  final m = minutes ?? 60;
  if (m <= 30) return 4;
  if (m <= 45) return 5;
  if (m <= 60) return 6;
  if (m <= 75) return 7;
  return 8;
}

int _restSeconds(String s) {
  final matches = RegExp(r'(\d+)').allMatches(s);
  if (matches.isEmpty) return 90;
  var sum = 0;
  for (final m in matches) {
    sum += int.parse(m.group(1)!);
  }
  return (sum / matches.length).round();
}

int _setsFor(RoutineGoal goal, RoutineLevel level, bool compound) {
  var sets = level == RoutineLevel.principiante ? 3 : (compound ? 4 : 3);
  if (goal == RoutineGoal.ganarMusculo) sets += 1;
  if (goal == RoutineGoal.perderGrasa) sets -= 1;
  return sets.clamp(2, 5);
}

RoutineExercise _toRoutineExercise(Exercise e, RoutineRequest req) {
  final compound = _isCompoundExercise(e);
  final sets = _setsFor(req.goal, req.level, compound);
  final range = compound ? '8-10' : '10-12';
  final reps = compound ? 8 : 10;
  final rest = compound
      ? (e.muscleGroup == 'Pierna' ? '120-150s' : '90-120s')
      : (e.muscleGroup == 'Pierna' ? '75-90s' : '45-60s');
  return RoutineExercise(
    exerciseId: e.id,
    exerciseName: e.name,
    muscleGroup: e.muscleGroup,
    sets: sets,
    reps: reps,
    restSeconds: _restSeconds(rest),
    notes: '${sets}x$range ($rest)',
    plannedSets: List.generate(sets, (_) => PlannedSet(weight: 0, reps: reps)),
  );
}

/// Elige de un plan de tiers: un ejercicio por tier, en orden estable, saltando
/// los que ya están en el día. Añade variedad con [rng] pero sin perder la
/// estructura (compuestos grandes primero).
List<Exercise> _pickFromPlan(
  List<List<_Canon>> plan,
  RoutineRequest req,
  String focus,
  int want,
  Set<String> usedInDay,
  Random rng,
) {
  final out = <Exercise>[];
  for (var tierIndex = 0; tierIndex < plan.length; tierIndex++) {
    if (out.length >= want) break;
    final tier = plan[tierIndex];
    final options = <Exercise>[];
    for (final canon in tier) {
      final ex = _resolve(canon, req.catalog, req.equipment);
      if (ex == null) continue;
      if (usedInDay.contains(ex.id)) continue;
      if (options.any((o) => o.id == ex.id)) continue;
      if (!_isAllowedName(ex.name, focus)) continue;
      options.add(ex);
    }
    if (options.isEmpty) continue;
    // El primer tier es el ejercicio principal: se respeta el orden de
    // preferencia (sentadilla/press antes que la variante). El resto varía.
    final chosen =
        tierIndex == 0 ? options.first : options[rng.nextInt(options.length)];
    out.add(chosen);
    usedInDay.add(chosen.id);
  }
  return out;
}

bool _genericAllowed(Exercise e, String focus) {
  if (_banned(e.name)) return false;
  if (!_isAllowedName(e.name, focus)) return false;
  switch (normalizeFocus(focus)) {
    case 'Push':
      return e.muscleGroup == 'Pecho' || e.muscleGroup == 'Hombro' || e.muscleGroup == 'Brazo';
    case 'Pull':
      return e.muscleGroup == 'Espalda' || e.muscleGroup == 'Brazo';
    case 'Upper':
      return e.muscleGroup == 'Pecho' || e.muscleGroup == 'Espalda' || e.muscleGroup == 'Hombro' || e.muscleGroup == 'Brazo';
    case 'Lower':
    case 'Legs':
      return e.muscleGroup == 'Pierna' || e.muscleGroup == 'Core';
    default:
      return e.muscleGroup != 'Cardio';
  }
}

List<Exercise> _pickGeneric(
  RoutineRequest req,
  String focus,
  int want,
  Set<String> usedInDay,
  Set<String> usedGlobally,
  Random rng,
) {
  List<Exercise> build({required bool enforceEquipment, required bool allowRepeats}) {
    return req.catalog
        .where((e) => _genericAllowed(e, focus))
        .where((e) => !usedInDay.contains(e.id))
        .where((e) => allowRepeats || !usedGlobally.contains(e.id))
        .where((e) => !enforceEquipment ||
            req.equipment.isEmpty ||
            req.equipment.contains(e.equipment) ||
            e.equipment == 'Peso corporal' ||
            e.equipment == 'Gimnasio')
        .toList();
  }

  var pool = build(enforceEquipment: true, allowRepeats: false);
  if (pool.isEmpty) pool = build(enforceEquipment: false, allowRepeats: false);
  if (pool.isEmpty) pool = build(enforceEquipment: false, allowRepeats: true);
  if (pool.isEmpty) return const [];
  pool.shuffle(rng);

  final groups = <String, List<Exercise>>{};
  for (final e in pool) {
    groups.putIfAbsent(e.muscleGroup, () => []).add(e);
  }
  for (final group in groups.values) {
    group.sort((a, b) {
      final ac = a.mechanic == 'compound' ? 0 : 1;
      final bc = b.mechanic == 'compound' ? 0 : 1;
      return ac.compareTo(bc);
    });
  }

  final keys = groups.keys.toList()..shuffle(rng);
  final out = <Exercise>[];
  var exhausted = false;
  while (out.length < want && !exhausted) {
    exhausted = true;
    for (final key in keys) {
      if (out.length >= want) break;
      final group = groups[key]!;
      if (group.isEmpty) continue;
      out.add(group.removeAt(0));
      exhausted = false;
    }
  }
  return out;
}

List<RoutineDay> generateRoutine(RoutineRequest req, {int? seed}) {
  final baseSeed = seed ?? req.seed ?? 20260101;
  final splits = splitFor(req.daysPerWeek);
  final canonical = _hasCanonicalCatalog(req.catalog);
  final want = _targetCount(req.minutesAvailable);
  final usedGlobally = <String>{};
  final days = <RoutineDay>[];

  for (var i = 0; i < splits.length; i++) {
    final splitDay = splits[i];
    final focus = normalizeFocus(splitDay);
    final usedInDay = <String>{};
    final rng = Random(baseSeed + i * 7919);

    final picked = canonical
        ? _pickFromPlan(_planFor(focus), req, focus, want, usedInDay, rng)
        : _pickGeneric(req, focus, want, usedInDay, usedGlobally, rng);

    if (canonical) {
      final position = {for (var j = 0; j < picked.length; j++) picked[j].id: j};
      picked.sort((a, b) {
        final ac = _isCompoundExercise(a) ? 0 : 1;
        final bc = _isCompoundExercise(b) ? 0 : 1;
        if (ac != bc) return ac.compareTo(bc);
        return position[a.id]!.compareTo(position[b.id]!);
      });
    }

    for (final e in picked) {
      usedGlobally.add(e.id);
    }

    final exercises = picked.map((e) => _toRoutineExercise(e, req)).toList();
    final muscles = <String>{for (final e in picked) e.muscleGroup};

    days.add(RoutineDay(
      day: _allDays[i % _allDays.length],
      title: 'Día ${i + 1} – $splitDay',
      description: muscles.isEmpty ? focus : muscles.join(' · '),
      duration: RoutineExercise.estimateDayDuration(exercises),
      exercises: exercises,
    ));
  }

  return days;
}

List<RoutineDay> topUpRoutineDays(List<RoutineDay> generated, List<RoutineDay> fallback) {
  if (generated.isEmpty) return fallback;
  final out = <RoutineDay>[];
  for (var i = 0; i < fallback.length; i++) {
    if (i >= generated.length) {
      out.add(fallback[i]);
      continue;
    }
    final g = generated[i];
    final f = fallback[i];
    final items = <RoutineExercise>[...g.exercises];
    final ids = {for (final e in items) e.exerciseId};
    for (final e in f.exercises) {
      if (items.length >= f.exercises.length) break;
      if (ids.add(e.exerciseId)) items.add(e);
    }
    out.add(RoutineDay(
      day: g.day,
      title: g.title,
      description: (g.description?.isNotEmpty ?? false) ? g.description : f.description,
      duration: g.duration.isNotEmpty ? g.duration : f.duration,
      exercises: items,
    ));
  }
  return out;
}

int targetExercisesFor({
  required int minutes,
  required int daysPerWeek,
  required RoutineLevel level,
}) {
  var per = _targetCount(minutes);
  if (daysPerWeek >= 5) per -= 1;
  if (level == RoutineLevel.principiante) per -= 1;
  if (level == RoutineLevel.avanzado && minutes >= 75) per += 1;
  return per.clamp(3, 8);
}
