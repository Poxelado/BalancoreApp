import 'exercise.dart';

/// Etiquetas en español de las zonas musculares "finas" (primaryMuscles del
/// catálogo free-exercise-db). Permiten filtrar por una zona concreta
/// (p. ej. Antebrazos, Bíceps, Cuádriceps) en vez del grupo grueso.
const kFineMuscleLabelsEs = <String, String>{
  'chest': 'Pecho',
  'shoulders': 'Hombros',
  'biceps': 'Bíceps',
  'triceps': 'Tríceps',
  'forearms': 'Antebrazos',
  'abdominals': 'Abdomen',
  'lats': 'Dorsales',
  'middle back': 'Espalda media',
  'lower back': 'Lumbar',
  'traps': 'Trapecio',
  'neck': 'Cuello',
  'quadriceps': 'Cuádriceps',
  'hamstrings': 'Isquios',
  'glutes': 'Glúteos',
  'adductors': 'Aductores',
  'abductors': 'Abductores',
  'calves': 'Gemelos',
};

/// Orden canónico de las zonas finas (para chips y agrupaciones).
const kFineMuscleOrder = <String>[
  'chest',
  'shoulders',
  'biceps',
  'triceps',
  'forearms',
  'abdominals',
  'lats',
  'middle back',
  'lower back',
  'traps',
  'neck',
  'quadriceps',
  'hamstrings',
  'glutes',
  'adductors',
  'abductors',
  'calves',
];

/// Zonas finas ordenadas, ya como etiquetas en español.
List<String> get fineMuscleLabelsOrdered =>
    [for (final k in kFineMuscleOrder) kFineMuscleLabelsEs[k]!];

/// Clave fina (inglés) de la zona principal de un ejercicio del catálogo.
String? fineMuscleKeyOf(String exerciseId) {
  final e = ExerciseCatalog.byId(exerciseId);
  final pm = e?.primaryMuscles;
  if (pm == null || pm.isEmpty) return null;
  return pm.first.trim().toLowerCase();
}

/// Etiqueta legible de la zona de un ejercicio: usa la zona fina del catálogo
/// si existe; si no, cae al grupo muscular grueso guardado en la sesión.
String primaryZoneLabelFor(String exerciseId, String fallbackGroup) {
  final fine = fineMuscleKeyOf(exerciseId);
  if (fine != null) {
    final label = kFineMuscleLabelsEs[fine];
    if (label != null) return label;
  }
  final g = fallbackGroup.trim();
  return g.isEmpty ? 'Otro' : g;
}

/// Zonas finas (etiquetas ES) en las que participa un ejercicio como músculo
/// PRINCIPAL. Si no tiene datos finos, devuelve su grupo muscular grueso.
List<String> primaryZonesOf(Exercise e) {
  final out = <String>{};
  for (final m in e.primaryMuscles) {
    final label = kFineMuscleLabelsEs[m.trim().toLowerCase()];
    if (label != null) out.add(label);
  }
  if (out.isEmpty) {
    final g = e.muscleGroup.trim();
    out.add(g.isEmpty ? 'Otro' : g);
  }
  return out.toList();
}

/// Zonas finas presentes en una lista de ejercicios, en orden canónico.
List<String> availableZones(List<Exercise> list) {
  final present = <String>{};
  for (final e in list) {
    present.addAll(primaryZonesOf(e));
  }
  final known = fineMuscleLabelsOrdered.where(present.contains).toList();
  final others = present
      .where((z) => !fineMuscleLabelsOrdered.contains(z))
      .toList()
    ..sort();
  return [...known, ...others];
}
