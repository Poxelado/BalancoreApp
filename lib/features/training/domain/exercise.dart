class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment; // Gimnasio | Casa | Peso corporal
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
    'Pecho',
    'Espalda',
    'Pierna',
    'Hombro',
    'Brazo',
    'Core',
    'Cardio',
    'Otro',
  ];

  static const equipmentTypes = [
    'Gimnasio',
    'Casa',
    'Peso corporal',
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

  Exercise copyWith({
    String? name,
    String? muscleGroup,
    String? equipment,
    String? instructions,
  }) {
    return Exercise(
      id: id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      instructions: instructions ?? this.instructions,
      isCustom: isCustom,
    );
  }
}

/// Catálogo base (sin red). Los personalizados van a Firestore.
class ExerciseCatalog {
  static const List<Exercise> builtIn = [
    // Pecho
    Exercise(
      id: 'ex_bench_press',
      name: 'Press de banca',
      muscleGroup: 'Pecho',
      equipment: 'Gimnasio',
      instructions:
          'Acostado en banco, baja la barra al pecho controlando y empuja hacia arriba sin bloquear codos de golpe.',
    ),
    Exercise(
      id: 'ex_incline_dumbbell',
      name: 'Press inclinado con mancuernas',
      muscleGroup: 'Pecho',
      equipment: 'Gimnasio',
      instructions:
          'Banco a 30–45°. Baja las mancuernas con control y empuja hacia arriba juntando ligeramente al final.',
    ),
    Exercise(
      id: 'ex_pushups',
      name: 'Flexiones',
      muscleGroup: 'Pecho',
      equipment: 'Peso corporal',
      instructions:
          'Cuerpo recto, manos al ancho de hombros. Baja el pecho cerca del suelo y empuja sin arquear la espalda.',
    ),
    Exercise(
      id: 'ex_cable_fly',
      name: 'Aperturas en polea',
      muscleGroup: 'Pecho',
      equipment: 'Gimnasio',
      instructions:
          'Brazos ligeramente flexionados, junta las manos al frente contrayendo el pecho y vuelve con control.',
    ),
    // Espalda
    Exercise(
      id: 'ex_pullups',
      name: 'Dominadas',
      muscleGroup: 'Espalda',
      equipment: 'Peso corporal',
      instructions:
          'Agarre prono, sube hasta que la barbilla pase la barra y baja controlado hasta extensión casi completa.',
    ),
    Exercise(
      id: 'ex_lat_pulldown',
      name: 'Jalón al pecho',
      muscleGroup: 'Espalda',
      equipment: 'Gimnasio',
      instructions:
          'Tira de la barra hacia la parte alta del pecho, codos hacia abajo, sin balancear el torso.',
    ),
    Exercise(
      id: 'ex_barbell_row',
      name: 'Remo con barra',
      muscleGroup: 'Espalda',
      equipment: 'Gimnasio',
      instructions:
          'Torso inclinado, espalda neutra. Tira de la barra hacia el abdomen bajo y baja con control.',
    ),
    Exercise(
      id: 'ex_seated_row',
      name: 'Remo en máquina',
      muscleGroup: 'Espalda',
      equipment: 'Gimnasio',
      instructions:
          'Pecho apoyado o torso estable. Lleva los agarres hacia ti apretando omóplatos.',
    ),
    // Pierna
    Exercise(
      id: 'ex_squat',
      name: 'Sentadilla',
      muscleGroup: 'Pierna',
      equipment: 'Gimnasio',
      instructions:
          'Pies al ancho de hombros, baja flexionando cadera y rodillas manteniendo pecho alto. Sube empujando el suelo.',
    ),
    Exercise(
      id: 'ex_romanian_deadlift',
      name: 'Peso muerto rumano',
      muscleGroup: 'Pierna',
      equipment: 'Gimnasio',
      instructions:
          'Bisagra de cadera, espalda neutra. Baja la barra rozando piernas y sube apretando glúteos.',
    ),
    Exercise(
      id: 'ex_leg_press',
      name: 'Prensa de piernas',
      muscleGroup: 'Pierna',
      equipment: 'Gimnasio',
      instructions:
          'Pies a mitad de la plataforma. Baja controlado sin despegar lumbar y empuja sin bloquear rodillas.',
    ),
    Exercise(
      id: 'ex_lunges',
      name: 'Zancadas',
      muscleGroup: 'Pierna',
      equipment: 'Peso corporal',
      instructions:
          'Da un paso largo, baja la rodilla trasera hacia el suelo y empuja con la pierna delantera para volver.',
    ),
    Exercise(
      id: 'ex_leg_curl',
      name: 'Curl femoral',
      muscleGroup: 'Pierna',
      equipment: 'Gimnasio',
      instructions:
          'Flexiona rodillas llevando el relleno hacia los glúteos y extiende con control.',
    ),
    // Hombro
    Exercise(
      id: 'ex_ohp',
      name: 'Press militar',
      muscleGroup: 'Hombro',
      equipment: 'Gimnasio',
      instructions:
          'Barra a la altura de clavícula, empuja arriba sin arquear lumbar en exceso.',
    ),
    Exercise(
      id: 'ex_lateral_raise',
      name: 'Elevaciones laterales',
      muscleGroup: 'Hombro',
      equipment: 'Gimnasio',
      instructions:
          'Codos ligeramente flexionados, eleva mancuernas a los lados hasta altura de hombros.',
    ),
    Exercise(
      id: 'ex_face_pull',
      name: 'Face pulls',
      muscleGroup: 'Hombro',
      equipment: 'Gimnasio',
      instructions:
          'Tira de la cuerda hacia la cara separando manos, enfocado en deltoides posteriores.',
    ),
    // Brazo
    Exercise(
      id: 'ex_barbell_curl',
      name: 'Curl de bíceps con barra',
      muscleGroup: 'Brazo',
      equipment: 'Gimnasio',
      instructions:
          'Codos fijos al torso, sube la barra sin balancear y baja controlado.',
    ),
    Exercise(
      id: 'ex_triceps_pushdown',
      name: 'Extensiones de tríceps en polea',
      muscleGroup: 'Brazo',
      equipment: 'Gimnasio',
      instructions:
          'Codos pegados al cuerpo, extiende hasta abajo apretando tríceps y vuelve sin mover hombros.',
    ),
    Exercise(
      id: 'ex_hammer_curl',
      name: 'Curl martillo',
      muscleGroup: 'Brazo',
      equipment: 'Gimnasio',
      instructions:
          'Agarre neutro (palmas enfrentadas), sube mancuernas sin balancear el cuerpo.',
    ),
    // Core
    Exercise(
      id: 'ex_plank',
      name: 'Plancha',
      muscleGroup: 'Core',
      equipment: 'Peso corporal',
      instructions:
          'Antebrazos y puntas de pies, cuerpo en línea. Activa abdomen y glúteos sin hundir la cadera.',
    ),
    Exercise(
      id: 'ex_crunch',
      name: 'Crunch',
      muscleGroup: 'Core',
      equipment: 'Peso corporal',
      instructions:
          'Eleva omóplatos del suelo contrayendo abdomen, sin tirar del cuello.',
    ),
    Exercise(
      id: 'ex_hanging_knee_raise',
      name: 'Elevación de rodillas colgado',
      muscleGroup: 'Core',
      equipment: 'Gimnasio',
      instructions:
          'Colgado de la barra, sube rodillas hacia el pecho sin balancear en exceso.',
    ),
    // Cardio
    Exercise(
      id: 'ex_treadmill',
      name: 'Cinta / trote',
      muscleGroup: 'Cardio',
      equipment: 'Gimnasio',
      instructions:
          'Mantén postura erguida y ritmo sostenible según tu objetivo (grasa o resistencia).',
    ),
    Exercise(
      id: 'ex_bike',
      name: 'Bicicleta estática',
      muscleGroup: 'Cardio',
      equipment: 'Gimnasio',
      instructions:
          'Ajusta asiento a altura de cadera. Pedalea con cadencia controlada.',
    ),
    Exercise(
      id: 'ex_jump_rope',
      name: 'Cuerda',
      muscleGroup: 'Cardio',
      equipment: 'Casa',
      instructions:
          'Saltos bajos, muñecas girando la cuerda. Empieza por intervalos cortos.',
    ),
  ];
}
