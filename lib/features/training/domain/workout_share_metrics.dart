import '../../profile/domain/user_profile.dart';
import 'exercise.dart';

/// Región anatómica que se pinta en el mapa de músculos de las tarjetas.
/// Algunas (antebrazos, gemelos) se dibujan tanto de frente como de espaldas.
enum BodyRegion {
  chest('Pecho'),
  shoulders('Hombros'),
  biceps('Bíceps'),
  forearms('Antebrazos'),
  abs('Abdomen'),
  quadriceps('Cuádriceps'),
  calves('Gemelos'),
  traps('Trapecio'),
  lats('Dorsales'),
  lowerBack('Lumbar'),
  triceps('Tríceps'),
  glutes('Glúteos'),
  hamstrings('Isquios');

  const BodyRegion(this.label);
  final String label;
}

/// Músculos finos de free-exercise-db → región del mapa.
const _fineToRegion = <String, BodyRegion>{
  'chest': BodyRegion.chest,
  'shoulders': BodyRegion.shoulders,
  'biceps': BodyRegion.biceps,
  'triceps': BodyRegion.triceps,
  'forearms': BodyRegion.forearms,
  'abdominals': BodyRegion.abs,
  'quadriceps': BodyRegion.quadriceps,
  'hamstrings': BodyRegion.hamstrings,
  'glutes': BodyRegion.glutes,
  'lats': BodyRegion.lats,
  'middle back': BodyRegion.lats,
  'lower back': BodyRegion.lowerBack,
  'traps': BodyRegion.traps,
  'neck': BodyRegion.traps,
  'adductors': BodyRegion.quadriceps,
  'abductors': BodyRegion.glutes,
  'calves': BodyRegion.calves,
};

/// Grupo muscular grueso (el que guarda la sesión) → región del mapa.
const _groupToRegion = <String, BodyRegion>{
  'Pecho': BodyRegion.chest,
  'Espalda': BodyRegion.lats,
  'Pierna': BodyRegion.quadriceps,
  'Hombro': BodyRegion.shoulders,
  'Brazo': BodyRegion.biceps,
  'Core': BodyRegion.abs,
};

/// Orden fijo de los ejes del gráfico de radar.
const radarGroups = <String>[
  'Pecho',
  'Espalda',
  'Hombro',
  'Brazo',
  'Pierna',
  'Core',
];

/// Una fila de ejercicio como "3× Jalón al pecho".
class ExerciseShareLine {
  final String name;
  final int sets;
  final double volume;

  const ExerciseShareLine({
    required this.name,
    required this.sets,
    required this.volume,
  });
}

/// Métricas derivadas de una sesión para armar las tarjetas para compartir.
class WorkoutShareData {
  final WorkoutSession session;

  /// Volumen total en kg (sin calentamiento).
  final double volumeKg;

  /// Duración en segundos.
  final int durationSeconds;

  final int totalSets;
  final int completedSets;
  final int exerciseCount;

  /// Intensidad por región (0..1) para el mapa de músculos.
  final Map<BodyRegion, double> bodyIntensity;

  /// Volumen (kg) por grupo muscular grueso, para el radar.
  final Map<String, double> volumeByGroup;

  /// Filas de ejercicios "N× nombre".
  final List<ExerciseShareLine> exerciseLines;

  const WorkoutShareData({
    required this.session,
    required this.volumeKg,
    required this.durationSeconds,
    required this.totalSets,
    required this.completedSets,
    required this.exerciseCount,
    required this.bodyIntensity,
    required this.volumeByGroup,
    required this.exerciseLines,
  });

  double get volumeValue {
    // Si no hay peso (solo corporal), se cae al número de series para que la
    // tarjeta no muestre 0.
    if (volumeKg > 0) return volumeKg;
    return completedSets.toDouble();
  }
}

/// Regiones del mapa que trabaja un ejercicio: sus músculos principales si se
/// conoce en el catálogo o, si no, su grupo muscular grueso.
Set<BodyRegion> regionsForExercise(String exerciseId, String muscleGroup) {
  final regions = <BodyRegion>{};
  final exercise = ExerciseCatalog.byId(exerciseId);
  if (exercise != null && exercise.primaryMuscles.isNotEmpty) {
    for (final m in exercise.primaryMuscles) {
      final r = _fineToRegion[m.toLowerCase()];
      if (r != null) regions.add(r);
    }
  }
  if (regions.isEmpty) {
    final r = _groupToRegion[muscleGroup.trim()];
    if (r != null) regions.add(r);
  }
  return regions;
}

/// Normaliza a 0..1 (con un mínimo visible) para pintar el mapa de músculos.
Map<BodyRegion, double> _normalizeIntensity(Map<BodyRegion, double> raw) {
  final max = raw.values.fold<double>(0, (a, b) => a > b ? a : b);
  if (max <= 0) return const {};
  return {
    for (final e in raw.entries) e.key: (e.value / max).clamp(0.2, 1.0),
  };
}

WorkoutShareData buildWorkoutShareData(WorkoutSession session) {
  var volume = 0.0;
  final byGroup = <String, double>{};
  final intensity = <BodyRegion, double>{};

  for (final ex in session.exercises) {
    var exVolume = 0.0;
    final done = ex.sets.where((s) => s.completed);
    for (final s in done) {
      if (s.isWarmup) continue;
      exVolume += s.weight * s.reps;
    }
    volume += exVolume;

    final group = ex.muscleGroup.trim().isEmpty ? 'Otro' : ex.muscleGroup.trim();
    if (exVolume > 0) {
      byGroup[group] = (byGroup[group] ?? 0) + exVolume;
    }

    // El mapa de músculos pesa por series hechas (para que el entreno a peso
    // corporal también resalte).
    final regionWeight =
        exVolume > 0 ? exVolume : done.length.toDouble();
    final regions = regionsForExercise(ex.exerciseId, ex.muscleGroup);
    for (final r in regions) {
      intensity[r] = (intensity[r] ?? 0) + regionWeight / regions.length;
    }
  }

  final normalized = _normalizeIntensity(intensity);

  final lines = <ExerciseShareLine>[
    for (final ex in session.exercises)
      ExerciseShareLine(
        name: ex.exerciseName,
        sets: ex.sets.where((s) => s.completed).isNotEmpty
            ? ex.sets.where((s) => s.completed).length
            : ex.sets.length,
        volume: ex.sets
            .where((s) => s.completed && !s.isWarmup)
            .fold<double>(0, (sum, s) => sum + s.weight * s.reps),
      ),
  ];

  return WorkoutShareData(
    session: session,
    volumeKg: volume,
    durationSeconds: session.elapsedSeconds,
    totalSets: session.totalSets,
    completedSets: session.completedSets,
    exerciseCount: session.exercises.length,
    bodyIntensity: normalized,
    volumeByGroup: byGroup,
    exerciseLines: lines,
  );
}

/// Intensidad por región (0..1) de una rutina planificada —para previsualizar
/// el día antes de entrenar—, pesando cada ejercicio por sus series efectivas.
Map<BodyRegion, double> buildRoutineIntensity(RoutineDay day) {
  final intensity = <BodyRegion, double>{};
  for (final e in day.exercises) {
    final regions = regionsForExercise(e.exerciseId, e.muscleGroup);
    if (regions.isEmpty) continue;
    final sets = e.effectiveSets.length;
    final weight = sets > 0 ? sets.toDouble() : 1.0;
    for (final r in regions) {
      intensity[r] = (intensity[r] ?? 0) + weight / regions.length;
    }
  }
  return _normalizeIntensity(intensity);
}

/// Comparación divertida del volumen levantado con algo cotidiano.
class WeightEquivalence {
  /// Cuántas veces [item] equivalen al volumen.
  final double count;
  final String item;
  final String emoji;

  const WeightEquivalence(this.count, this.item, this.emoji);
}

const _equivalents = <(double massKg, String item, String emoji)>[
  (15, 'una silla de oficina', '🪑'),
  (30, 'una mochila cargada', '🎒'),
  (50, 'una maleta de viaje', '🧳'),
  (80, 'un panda gigante', '🐼'),
  (160, 'una persona adulta', '🧍'),
  (250, 'una moto', '🏍️'),
  (400, 'un piano de cola', '🎹'),
  (600, 'un caballo', '🐴'),
  (900, 'una vaca', '🐄'),
  (1600, 'un hipopótamo', '🦛'),
  (2500, 'un coche pequeño', '🚗'),
  (6000, 'un elefante', '🐘'),
  (15000, 'un camión', '🚚'),
  (30000, 'una ballena jorobada', '🐋'),
];

WeightEquivalence equivalenceFor(double volumeKg) {
  if (volumeKg <= 0) {
    return const WeightEquivalence(1, 'una mochila cargada', '🎒');
  }
  var chosen = _equivalents.first;
  for (final e in _equivalents) {
    if (volumeKg >= e.$1) chosen = e;
  }
  final count = (volumeKg / chosen.$1).clamp(1.0, double.infinity);
  return WeightEquivalence(count, chosen.$2, chosen.$3);
}
