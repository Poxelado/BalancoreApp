class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String instructions;
  final bool isCustom;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    this.equipment = 'Gimnasio',
    this.instructions = '',
    this.isCustom = false,
  });

  static const muscleGroups = [
    'Pecho', 'Espalda', 'Pierna', 'Hombro', 'Brazo', 'Core', 'Cardio', 'Otro',
  ];

  Map<String, dynamic> toMap() => {
    'name': name,
    'muscleGroup': muscleGroup,
    'equipment': equipment,
    'instructions': instructions,
    'isCustom': isCustom,
  };

  factory Exercise.fromMap(String id, Map<String, dynamic> map) {
    return Exercise(
      id: id,
      name: map['name'] ?? '',
      muscleGroup: map['muscleGroup'] ?? 'Otro',
      equipment: map['equipment'] ?? 'Gimnasio',
      instructions: map['instructions'] ?? '',
      isCustom: map['isCustom'] ?? true,
    );
  }
}

class ExerciseCatalog {
  static const List<Exercise> builtIn = [
    Exercise(id: 'ex_bench_press', name: 'Press de banca', muscleGroup: 'Pecho'),
    Exercise(id: 'ex_incline_dumbbell', name: 'Press inclinado con mancuernas', muscleGroup: 'Pecho'),
    Exercise(id: 'ex_pushups', name: 'Flexiones', muscleGroup: 'Pecho', equipment: 'Peso corporal'),
    Exercise(id: 'ex_cable_fly', name: 'Aperturas en polea', muscleGroup: 'Pecho'),
    Exercise(id: 'ex_pullups', name: 'Dominadas', muscleGroup: 'Espalda', equipment: 'Peso corporal'),
    Exercise(id: 'ex_lat_pulldown', name: 'Jalón al pecho', muscleGroup: 'Espalda'),
    Exercise(id: 'ex_barbell_row', name: 'Remo con barra', muscleGroup: 'Espalda'),
    Exercise(id: 'ex_seated_row', name: 'Remo en máquina', muscleGroup: 'Espalda'),
    Exercise(id: 'ex_squat', name: 'Sentadilla', muscleGroup: 'Pierna'),
    Exercise(id: 'ex_romanian_deadlift', name: 'Peso muerto rumano', muscleGroup: 'Pierna'),
    Exercise(id: 'ex_leg_press', name: 'Prensa de piernas', muscleGroup: 'Pierna'),
    Exercise(id: 'ex_lunges', name: 'Zancadas', muscleGroup: 'Pierna', equipment: 'Peso corporal'),
    Exercise(id: 'ex_leg_curl', name: 'Curl femoral', muscleGroup: 'Pierna'),
    Exercise(id: 'ex_ohp', name: 'Press militar', muscleGroup: 'Hombro'),
    Exercise(id: 'ex_lateral_raise', name: 'Elevaciones laterales', muscleGroup: 'Hombro'),
    Exercise(id: 'ex_face_pull', name: 'Face pulls', muscleGroup: 'Hombro'),
    Exercise(id: 'ex_barbell_curl', name: 'Curl de bíceps con barra', muscleGroup: 'Brazo'),
    Exercise(id: 'ex_triceps_pushdown', name: 'Extensiones de tríceps en polea', muscleGroup: 'Brazo'),
    Exercise(id: 'ex_hammer_curl', name: 'Curl martillo', muscleGroup: 'Brazo'),
    Exercise(id: 'ex_plank', name: 'Plancha', muscleGroup: 'Core', equipment: 'Peso corporal'),
    Exercise(id: 'ex_crunch', name: 'Crunch', muscleGroup: 'Core', equipment: 'Peso corporal'),
    Exercise(id: 'ex_hanging_knee_raise', name: 'Elevación de rodillas colgado', muscleGroup: 'Core'),
    Exercise(id: 'ex_treadmill', name: 'Cinta / trote', muscleGroup: 'Cardio'),
    Exercise(id: 'ex_bike', name: 'Bicicleta estática', muscleGroup: 'Cardio'),
    Exercise(id: 'ex_jump_rope', name: 'Cuerda', muscleGroup: 'Cardio', equipment: 'Casa'),
  ];

  static Exercise? byId(String id) {
    try {
      return builtIn.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
