import '../../profile/domain/user_profile.dart';
import 'exercise.dart';

/// Objetivo del usuario. Alineado con `UserProfile.goal`.
enum RoutineGoal {
  perderGrasa('Perder grasa'),
  mantenimiento('Mantenimiento'),
  ganarMusculo('Ganar músculo');

  final String label;
  const RoutineGoal(this.label);

  static RoutineGoal fromLabel(String? label) => values.firstWhere(
        (g) => g.label.toLowerCase() == (label ?? '').toLowerCase(),
        orElse: () => RoutineGoal.mantenimiento,
      );
}

/// Nivel de experiencia. Alineado con `Exercise.levelEs`.
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

/// Qué entra en la rutina.
class RoutineRequest {
  final RoutineGoal goal;
  final RoutineLevel level;
  final int daysPerWeek;

  /// Equipamiento disponible. Vacío = se asume que se puede todo.
  final Set<String> equipment;

  /// Catálogo del que se eligen ejercicios (biblioteca del usuario).
  final List<Exercise> catalog;

  const RoutineRequest({
    required this.goal,
    required this.level,
    required this.daysPerWeek,
    required this.catalog,
    this.equipment = const {},
  });
}

/// Un espacio a llenar dentro de un día de la rutina.
class _Slot {
  final String muscle;
  final int count;

  /// Compuesto principal: se leCréditan más series y más descanso.
  final bool priority;

  const _Slot(this.muscle, this.count, {this.priority = false});
}

class _DayPlan {
  final String title;
  final List<_Slot> slots;

  const _DayPlan(this.title, this.slots);
}

const _allDays = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// Genera una rutina de fuerza con reglas deterministas.
///
/// No usa red ni IA: el mismo pedido produce siempre la misma rutina. Es la
/// base sobre la que opcionalmente se apoya el modelo de lenguaje, y sirve
/// como respuesta cuando el modelo falla o no hay clave configurada.
List<RoutineDay> generateRoutine(RoutineRequest req) {
  final plan = _splitsFor(req.daysPerWeek);
  final days = <RoutineDay>[];
  // Se evita repetir ejercicio entre días mientras el catálogo lo permita;
  // si no queda ninguno libre, se repite antes que dejar el día vacío.
  final usedGlobally = <String>{};
  for (var i = 0; i < plan.length; i++) {
    final p = plan[i];
    final exercises = <RoutineExercise>[];
    final usedInDay = <String>{};

    for (final slot in p.slots) {
      final picked = _pickFor(req, slot, usedInDay, usedGlobally);
      for (final e in picked) {
        usedInDay.add(e.id);
        usedGlobally.add(e.id);
        exercises.add(_toRoutineExercise(e, req, slot));
      }
    }

    // Objetivo "Perder grasa": cada día termina con cardio.
    if (req.goal == RoutineGoal.perderGrasa) {
      final cardio = _pickCardio(req, usedInDay, usedGlobally);
      if (cardio != null) {
        exercises.add(_toRoutineExercise(cardio, req, const _Slot('Cardio', 1)));
      }
    }

    days.add(
      RoutineDay(
        day: _allDays[i % _allDays.length],
        title: p.title,
        description: _describe(exercises),
        duration: _estimateDuration(exercises),
        exercises: exercises,
      ),
    );
  }
  return days;
}

/// Convierte un ejercicio del catálogo en ejercicio de rutina.
RoutineExercise _toRoutineExercise(
  Exercise e,
  RoutineRequest req,
  _Slot slot,
) {
  final reps = _repsFor(req, slot);
  final sets = _setsFor(req, slot);
  return RoutineExercise(
    exerciseId: e.id,
    exerciseName: e.name,
    muscleGroup: e.muscleGroup,
    sets: sets,
    reps: reps,
    restSeconds: _restFor(e.muscleGroup, slot.priority),
    plannedSets: List.generate(
      sets,
      (_) => PlannedSet(weight: 0, reps: reps),
    ),
  );
}

int _setsFor(RoutineRequest req, _Slot slot) {
  final base = switch (req.level) {
    RoutineLevel.principiante => 3,
    RoutineLevel.intermedio => 4,
    RoutineLevel.avanzado => 5,
  };
  var sets = slot.priority ? base : base - 1;
  if (req.goal == RoutineGoal.ganarMusculo && slot.priority) {
    sets += 1;
  }
  return sets.clamp(2, 8);
}

int _repsFor(RoutineRequest req, _Slot slot) {
  final range = switch (req.goal) {
    RoutineGoal.ganarMusculo => (8, 6),
    RoutineGoal.perderGrasa => (15, 12),
    RoutineGoal.mantenimiento => (12, 8),
  };
  // El compuesto principal va siempre por debajo del aislamiento.
  final hi = slot.priority ? range.$1 - 2 : range.$1;
  final lo = slot.priority ? range.$2 : range.$2;
  return hi.clamp(lo, 20);
}

int _restFor(String muscle, bool priority) {
  if (muscle == 'Core') return 45;
  if (muscle == 'Brazo' || muscle == 'Hombro') return priority ? 75 : 60;
  if (muscle == 'Pierna') return priority ? 150 : 105;
  if (muscle == 'Cardio') return 60;
  return priority ? 120 : 90;
}

String _describe(List<RoutineExercise> exercises) {
  if (exercises.isEmpty) return '';
  final groups = <String>{for (final e in exercises) e.muscleGroup};
  return groups.join(' · ');
}

/// Estimación gruesa: ~4 s por rep + el descanso de cada serie.
String _estimateDuration(List<RoutineExercise> exercises) {
  var seconds = 0;
  for (final e in exercises) {
    final sets = e.effectiveSets;
    for (final s in sets) {
      seconds += s.reps * 4 + e.restSeconds;
    }
  }
  final m = (seconds / 60).round();
  return m < 60 ? '$m min' : '${m ~/ 60} h ${(m % 60)} min';
}

/// Elige los ejercicios de un slot, ordenados de mejor a peor opción.
///
/// [usedInDay] es excluyente (no se repite dentro del mismo día);
/// [usedGlobally] solo se respeta mientras queden alternativas.
List<Exercise> _pickFor(
  RoutineRequest req,
  _Slot slot,
  Set<String> usedInDay,
  Set<String> usedGlobally,
) {
  List<Exercise> candidates(Set<String> exclude) => req.catalog
      .where((e) => e.muscleGroup == slot.muscle)
      .where((e) => !usedInDay.contains(e.id))
      .where((e) => !exclude.contains(e.id))
      .where((e) => _equipmentOk(req, e))
      .where((e) => _levelOk(req, e))
      .toList();

  var pool = candidates(usedGlobally);
  // Se relaja el nivel antes que dejar el día sin nada: es preferible
  // proponer un ejercicio de nivel superior a proponer una rutina vacía.
  if (pool.isEmpty) {
    pool = candidates(const {});
    pool.addAll(req.catalog
        .where((e) => e.muscleGroup == slot.muscle)
        .where((e) => !usedInDay.contains(e.id))
        .where((e) => !usedGlobally.contains(e.id))
        .where((e) => _equipmentOk(req, e)));
  }
  if (pool.isEmpty) {
    pool = req.catalog
        .where((e) => e.muscleGroup == slot.muscle)
        .where((e) => !usedInDay.contains(e.id))
        .where((e) => _equipmentOk(req, e))
        .toList();
  }

  pool.sort((a, b) {
    final score = _score(b, slot).compareTo(_score(a, slot));
    if (score != 0) return score;
    return a.id.compareTo(b.id); // desempate estable
  });

  return pool.take(slot.count).toList();
}

/// Cardio: hay pocas opciones (trotadora y bici), así que se repiten entre
/// días antes que dejar la sesión sin cierre cardiovascular.
Exercise? _pickCardio(
  RoutineRequest req,
  Set<String> usedInDay,
  Set<String> usedGlobally,
) {
  final options = [
    ...ExerciseCatalog.extras.where((e) => e.muscleGroup == 'Cardio'),
    ...req.catalog.where((e) => e.muscleGroup == 'Cardio'),
  ];
  final free = options
      .where((e) => !usedInDay.contains(e.id) && !usedGlobally.contains(e.id));
  for (final e in free) {
    return e;
  }
  for (final e in options) {
    if (!usedInDay.contains(e.id)) return e;
  }
  return null;
}

bool _equipmentOk(RoutineRequest req, Exercise e) {
  if (req.equipment.isEmpty) return true;
  return req.equipment.contains(e.equipment);
}

bool _levelOk(RoutineRequest req, Exercise e) {
  final level = e.levelEs ?? e.level;
  switch (req.level) {
    case RoutineLevel.principiante:
      return level == null || level.toLowerCase() == 'principiante';
    case RoutineLevel.intermedio:
      return level == null ||
          level.toLowerCase() == 'principiante' ||
          level.toLowerCase() == 'intermedio';
    case RoutineLevel.avanzado:
      return true;
  }
}

/// Puntúa un ejercicio como candidato.heurística explicable:
/// Se prioriza el movimiento compuesto y el trabajo del músculo principal
/// sobre el secundario.
int _score(Exercise e, _Slot slot) {
  var score = 0;
  final primary = e.primaryMuscles
      .map((m) => m.toLowerCase())
      .join(' ')
      .toLowerCase();
  final group = slot.muscle.toLowerCase();

  if (primary.contains(group.split(' ').first)) score += 40;
  if (primary.contains('pector') && group.contains('pecho')) score += 10;
  if (primary.contains('back') && group.contains('espalda')) score += 10;
  if (primary.contains('quad') && group.contains('pierna')) score += 10;
  if (primary.contains('hamstring') && group.contains('pierna')) score += 5;

  // Barra, máquina y polea son la mejor base para los compuestos.
  switch (e.equipment) {
    case 'Barra':
    case 'Máquina':
    case 'Polea':
      score += 25;
      break;
    case 'Mancuernas':
      score += 15;
      break;
    case 'Peso corporal':
    case 'Bandas':
      score += 8;
      break;
  }

  if (e.mechanic?.toLowerCase() == 'compound') score += slot.priority ? 22 : 0;

  // En los huecos de aislamiento se busca justamente lo contrario: si no, los
  // brazos se llenan de prensas y las piernas de sentadillas.
  if (!slot.priority && e.mechanic?.toLowerCase() == 'isolation') score += 14;
  if (!slot.priority && e.mechanic == null) score += 4;

  if (e.instructionsEs.trim().isEmpty && e.instructions.trim().isEmpty) {
    score -= 5;
  }
  return score;
}

/// Reparto de grupos musculares según los días por semana.
List<_DayPlan> _splitsFor(int days) {
  switch (days.clamp(2, 6)) {
    case 2:
      return const [
        _DayPlan('Tren superior', [
          _Slot('Pecho', 2, priority: true),
          _Slot('Espalda', 2, priority: true),
          _Slot('Hombro', 1),
          _Slot('Brazo', 2),
        ]),
        _DayPlan('Tren inferior', [
          _Slot('Pierna', 3, priority: true),
          _Slot('Core', 2),
          _Slot('Espalda', 1),
        ]),
      ];
    case 3:
      return const [
        _DayPlan('Full body · fuerza', [
          _Slot('Pierna', 1, priority: true),
          _Slot('Espalda', 1, priority: true),
          _Slot('Pecho', 1, priority: true),
          _Slot('Hombro', 1),
          _Slot('Brazo', 1),
        ]),
        _DayPlan('Full body · hipertrofia', [
          _Slot('Pecho', 1, priority: true),
          _Slot('Pierna', 1, priority: true),
          _Slot('Espalda', 1, priority: true),
          _Slot('Brazo', 2),
        ]),
        _DayPlan('Full body · conditioner', [
          _Slot('Pierna', 1, priority: true),
          _Slot('Espalda', 1),
          _Slot('Hombro', 1, priority: true),
          _Slot('Core', 2),
        ]),
      ];
    case 4:
      return const [
        _DayPlan('Tren superior A', [
          _Slot('Pecho', 2, priority: true),
          _Slot('Espalda', 2, priority: true),
          _Slot('Hombro', 1),
          _Slot('Brazo', 2),
        ]),
        _DayPlan('Tren inferior A', [
          _Slot('Pierna', 3, priority: true),
          _Slot('Core', 2),
        ]),
        _DayPlan('Tren superior B', [
          _Slot('Espalda', 2, priority: true),
          _Slot('Pecho', 2, priority: true),
          _Slot('Brazo', 2),
        ]),
        _DayPlan('Tren inferior B', [
          _Slot('Pierna', 3, priority: true),
          _Slot('Core', 2),
          _Slot('Hombro', 1),
        ]),
      ];
    case 5:
      return const [
        _DayPlan('Pecho y tríceps', [
          _Slot('Pecho', 3, priority: true),
          _Slot('Brazo', 1),
        ]),
        _DayPlan('Espalda y bíceps', [
          _Slot('Espalda', 3, priority: true),
          _Slot('Brazo', 1),
        ]),
        _DayPlan('Piernas', [
          _Slot('Pierna', 3, priority: true),
          _Slot('Core', 1),
        ]),
        _DayPlan('Hombros y core', [
          _Slot('Hombro', 3, priority: true),
          _Slot('Core', 2),
        ]),
        _DayPlan('Full body', [
          _Slot('Pierna', 1, priority: true),
          _Slot('Espalda', 1),
          _Slot('Pecho', 1),
          _Slot('Brazo', 1),
        ]),
      ];
    default:
      return const [
        _DayPlan('Pecho', [
          _Slot('Pecho', 3, priority: true),
          _Slot('Brazo', 1),
        ]),
        _DayPlan('Espalda', [
          _Slot('Espalda', 3, priority: true),
          _Slot('Brazo', 1),
        ]),
        _DayPlan('Piernas', [
          _Slot('Pierna', 3, priority: true),
          _Slot('Core', 1),
        ]),
        _DayPlan('Hombros', [
          _Slot('Hombro', 3, priority: true),
        ]),
        _DayPlan('Bíceps y tríceps', [
          _Slot('Brazo', 3, priority: true),
        ]),
        _DayPlan('Core y movilidad', [
          _Slot('Core', 3, priority: true),
          _Slot('Espalda', 1),
        ]),
      ];
  }
}