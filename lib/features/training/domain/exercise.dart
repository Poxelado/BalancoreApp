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
      name: map['name']?.toString() ?? '',
      muscleGroup: map['muscleGroup']?.toString() ?? 'Otro',
      equipment: map['equipment']?.toString() ?? 'Gimnasio',
      instructions: map['instructions']?.toString() ?? '',
      isCustom: map['isCustom'] == true,
    );
  }
}

class ExerciseCatalog {
  static const List<Exercise> builtIn = [
    Exercise(
      id: 'ex_bench_press',
      name: 'Press de banca',
      muscleGroup: 'Pecho',
      instructions:
      'Acuéstate en el banco, pies firmes. Baja la barra al pecho controlando y empuja hasta extender los brazos sin bloquear del todo los codos.',
    ),
    Exercise(
      id: 'ex_incline_dumbbell',
      name: 'Press inclinado con mancuernas',
      muscleGroup: 'Pecho',
      instructions:
      'Banco inclinado 30–45°. Baja las mancuernas a la altura del pecho y empuja hacia arriba juntándolas ligeramente arriba.',
    ),
    Exercise(
      id: 'ex_pushups',
      name: 'Flexiones',
      muscleGroup: 'Pecho',
      equipment: 'Peso corporal',
      instructions:
      'Cuerpo en línea recta. Baja el pecho hacia el suelo y empuja hasta extender los brazos. Rodillas al suelo si necesitas regresión.',
    ),
    Exercise(
      id: 'ex_cable_fly',
      name: 'Aperturas en polea',
      muscleGroup: 'Pecho',
      instructions:
      'Poleas a altura media o alta. Abraza el movimiento juntando las manos al frente con leve flexión de codos.',
    ),
    Exercise(
      id: 'ex_pullups',
      name: 'Dominadas',
      muscleGroup: 'Espalda',
      equipment: 'Peso corporal',
      instructions:
      'Agarre prono, hombros activos. Sube la barbilla por encima de la barra y baja con control.',
    ),
    Exercise(
      id: 'ex_lat_pulldown',
      name: 'Jalón al pecho',
      muscleGroup: 'Espalda',
      instructions:
      'Tira la barra al pecho alto, codos hacia abajo. No te balancees; controla la subida.',
    ),
    Exercise(
      id: 'ex_barbell_row',
      name: 'Remo con barra',
      muscleGroup: 'Espalda',
      instructions:
      'Bisagra de cadera, espalda neutra. Tira la barra al abdomen bajo y controla la bajada.',
    ),
    Exercise(
      id: 'ex_seated_row',
      name: 'Remo en máquina',
      muscleGroup: 'Espalda',
      instructions:
      'Sentado, pecho estable. Tira el agarre hacia el abdomen y junta omóplatos.',
    ),
    Exercise(
      id: 'ex_squat',
      name: 'Sentadilla',
      muscleGroup: 'Pierna',
      instructions:
      'Pies al ancho de hombros. Baja como si te sentaras, rodillas en línea con los pies, pecho arriba.',
    ),
    Exercise(
      id: 'ex_romanian_deadlift',
      name: 'Peso muerto rumano',
      muscleGroup: 'Pierna',
      instructions:
      'Bisagra de cadera, barra cerca de las piernas. Baja hasta sentir el isquiotibial y vuelve extendiendo cadera.',
    ),
    Exercise(
      id: 'ex_leg_press',
      name: 'Prensa de piernas',
      muscleGroup: 'Pierna',
      instructions:
      'Pies en la plataforma. Baja controlado y empuja sin bloquear por completo las rodillas.',
    ),
    Exercise(
      id: 'ex_lunges',
      name: 'Zancadas',
      muscleGroup: 'Pierna',
      equipment: 'Peso corporal',
      instructions:
      'Da un paso largo, baja la rodilla trasera hacia el suelo y vuelve. Alterna piernas.',
    ),
    Exercise(
      id: 'ex_leg_curl',
      name: 'Curl femoral',
      muscleGroup: 'Pierna',
      instructions:
      'Ajusta el rodillo sobre los tobillos. Flexiona llevando talones hacia el glúteo con control.',
    ),
    Exercise(
      id: 'ex_ohp',
      name: 'Press militar',
      muscleGroup: 'Hombro',
      instructions:
      'Barra a la altura de hombros. Empuja vertical hasta arriba y baja con control a clavículas.',
    ),
    Exercise(
      id: 'ex_lateral_raise',
      name: 'Elevaciones laterales',
      muscleGroup: 'Hombro',
      instructions:
      'Codos levemente flexionados. Eleva a los lados hasta la altura de hombros y baja lento.',
    ),
    Exercise(
      id: 'ex_face_pull',
      name: 'Face pulls',
      muscleGroup: 'Hombro',
      instructions:
      'Cuerda a la cara. Tira separando las manos hacia las orejas, codos altos.',
    ),
    Exercise(
      id: 'ex_barbell_curl',
      name: 'Curl de bíceps con barra',
      muscleGroup: 'Brazo',
      instructions:
      'Codos fijos al costado. Sube la barra sin balancear el tronco y baja controlado.',
    ),
    Exercise(
      id: 'ex_triceps_pushdown',
      name: 'Extensiones de tríceps en polea',
      muscleGroup: 'Brazo',
      instructions:
      'Codos pegados al cuerpo. Extiende antebrazos hacia abajo sin mover los hombros.',
    ),
    Exercise(
      id: 'ex_hammer_curl',
      name: 'Curl martillo',
      muscleGroup: 'Brazo',
      instructions:
      'Agarre neutro. Sube las mancuernas sin girar muñecas y baja con control.',
    ),
    Exercise(
      id: 'ex_plank',
      name: 'Plancha',
      muscleGroup: 'Core',
      equipment: 'Peso corporal',
      instructions:
      'Antebrazos y puntas de pies. Cuerpo en línea, abdomen activo. Respira de forma constante.',
    ),
    Exercise(
      id: 'ex_crunch',
      name: 'Crunch',
      muscleGroup: 'Core',
      equipment: 'Peso corporal',
      instructions:
      'Manos en sienes o pecho. Eleva omóplatos del suelo contrayendo abdomen; no tires del cuello.',
    ),
    Exercise(
      id: 'ex_hanging_knee_raise',
      name: 'Elevación de rodillas colgado',
      muscleGroup: 'Core',
      instructions:
      'Colgado, sube rodillas hacia el pecho sin balanceo excesivo y baja controlado.',
    ),
    Exercise(
      id: 'ex_treadmill',
      name: 'Cinta / trote',
      muscleGroup: 'Cardio',
      instructions:
      'Mantén postura erguida. Ajusta velocidad e inclinación según tu nivel.',
    ),
    Exercise(
      id: 'ex_bike',
      name: 'Bicicleta estática',
      muscleGroup: 'Cardio',
      instructions:
      'Ajusta el asiento. Pedalea con cadencia cómoda; aumenta resistencia de forma gradual.',
    ),
    Exercise(
      id: 'ex_jump_rope',
      name: 'Cuerda',
      muscleGroup: 'Cardio',
      equipment: 'Casa',
      instructions:
      'Saltos bajos, muñecas activas. Empieza por intervalos cortos si eres principiante.',
    ),
  ];

  static Exercise? byId(String id) {
    try {
      return builtIn.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
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
