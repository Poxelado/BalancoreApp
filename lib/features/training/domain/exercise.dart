/// Modelo de ejercicio Balancore (compatible con free-exercise-db).
library;

class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String instructions;
  final String instructionsEs;
  final bool isCustom;

  final String? nameEn;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String? force;
  final String? level;
  final String? levelEs;
  final String? mechanic;
  final String? category;
  final String? imagePath;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.equipment = 'Gimnasio',
    this.instructions = '',
    this.instructionsEs = '',
    this.isCustom = false,
    this.nameEn,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.force,
    this.level,
    this.levelEs,
    this.mechanic,
    this.category,
    this.imagePath,
  });

  static const muscleGroups = [
    'Pecho',
    'Espalda',
    'Pierna',
    'Hombro',
    'Brazo',
    'Core',
    'Cardio',
    'Otro',
  ];

  String? get imageUrl {
    if (imagePath == null || imagePath!.isEmpty) return null;
    return 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/$imagePath';
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'muscleGroup': muscleGroup,
        'equipment': equipment,
        'instructions': instructions,
        'isCustom': isCustom,
        if (nameEn != null) 'nameEn': nameEn,
        if (instructionsEs.isNotEmpty) 'instructionsEs': instructionsEs,
        if (primaryMuscles.isNotEmpty) 'primaryMuscles': primaryMuscles,
        if (secondaryMuscles.isNotEmpty) 'secondaryMuscles': secondaryMuscles,
        if (force != null) 'force': force,
        if (level != null) 'level': level,
        if (levelEs != null) 'levelEs': levelEs,
        if (mechanic != null) 'mechanic': mechanic,
        if (category != null) 'category': category,
        if (imagePath != null) 'imagePath': imagePath,
      };

  factory Exercise.fromMap(String id, Map<String, dynamic> map) {
    List<String> strList(dynamic v) {
      if (v is! List) return const [];
      return v.map((e) => e.toString()).toList();
    }

    return Exercise(
      id: id,
      name: map['name']?.toString() ?? '',
      muscleGroup: map['muscleGroup']?.toString() ?? 'Otro',
      equipment: map['equipment']?.toString() ?? 'Gimnasio',
      instructions: map['instructions']?.toString() ?? '',
      isCustom: map['isCustom'] == true,
      nameEn: map['nameEn']?.toString(),
      instructionsEs: map['instructionsEs']?.toString() ?? '',
      primaryMuscles: strList(map['primaryMuscles']),
      secondaryMuscles: strList(map['secondaryMuscles']),
      force: map['force']?.toString(),
      level: map['level']?.toString(),
      levelEs: map['levelEs']?.toString(),
      mechanic: map['mechanic']?.toString(),
      category: map['category']?.toString(),
      imagePath: map['imagePath']?.toString() ?? map['image']?.toString(),
    );
  }

  factory Exercise.fromFedbAsset(Map<String, dynamic> map) {
    List<String> strList(dynamic v) {
      if (v is! List) return const [];
      return v.map((e) => e.toString()).toList();
    }

    final name = map['name']?.toString() ?? '';
    final nameEn = map['nameEn']?.toString();
    return Exercise(
      id: map['id']?.toString() ?? '',
      name: name,
      muscleGroup: map['muscleGroup']?.toString() ?? 'Otro',
      equipment: map['equipment']?.toString() ?? 'Gimnasio',
      instructions: map['instructions']?.toString() ?? '',
      isCustom: false,
      nameEn: (nameEn == null || nameEn.isEmpty) ? name : nameEn,
      instructionsEs: map['instructionsEs']?.toString() ?? '',
      primaryMuscles: strList(map['primaryMuscles']),
      secondaryMuscles: strList(map['secondaryMuscles']),
      force: map['force']?.toString(),
      level: map['level']?.toString(),
      levelEs: map['levelEs']?.toString(),
      mechanic: map['mechanic']?.toString(),
      category: map['category']?.toString(),
      imagePath: map['image']?.toString(),
    );
  }
}

/// Caché del catálogo cargado desde assets/exercises_fedb.json.
class ExerciseCatalog {
  static List<Exercise>? cache;

  static const List<Exercise> fallback = [
    Exercise(
      id: 'ex_bench_press',
      name: 'Press de banca',
      muscleGroup: 'Pecho',
      equipment: 'Barra',
      instructions:
          'Acuéstate en el banco, pies firmes. Baja la barra al pecho y empuja.',
    ),
  ];

  /// Síncrono: usa caché si ya se cargó; si no, fallback mínimo.
  static List<Exercise> get builtIn => cache ?? fallback;

  /// Cardio que no existe en free-exercise-db (filtro strength/powerlifting).
  /// Se resuelven por id (plantillas de rutina) pero no aparecen en la biblioteca.
  static const List<Exercise> _extras = [
    Exercise(
      id: 'ex_treadmill',
      name: 'Cinta / trote',
      muscleGroup: 'Cardio',
      equipment: 'Gimnasio',
      instructions:
          'Mantén postura erguida. Ajusta velocidad e inclinación según tu nivel.',
    ),
    Exercise(
      id: 'ex_bike',
      name: 'Bicicleta estática',
      muscleGroup: 'Cardio',
      equipment: 'Gimnasio',
      instructions:
          'Ajusta el asiento. Pedalea con cadencia cómoda; aumenta resistencia de forma gradual.',
    ),
  ];

  /// Cardio/extra públicos (para el selector de ejercicios).
  static List<Exercise> get extras => _extras;

  /// Catálogo para el selector: base + cardio extra, sin duplicar ids.
  static List<Exercise> forPicker([List<Exercise> base = const []]) {
    final seen = <String>{};
    final out = <Exercise>[];
    for (final e in [...base, ..._extras]) {
      if (seen.add(e.id)) out.add(e);
    }
    return out;
  }

  static Exercise? byId(String id) {
    for (final e in builtIn) {
      if (e.id == id) return e;
    }
    for (final e in _extras) {
      if (e.id == id) return e;
    }
    return null;
  }

  static Exercise resolve({
    required String id,
    required String name,
    String muscleGroup = '',
  }) {
    return byId(id) ??
        Exercise(
          id: id,
          name: name,
          muscleGroup: muscleGroup.isEmpty ? 'Otro' : muscleGroup,
        );
  }
}
