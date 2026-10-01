
// ─── Helpers anti-null (Firestore) ─────────────────────────
String _str(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  if (v is String) {
    return DateTime.tryParse(v) ?? DateTime.now();
  }
  // Firestore Timestamp
  try {
    final d = v.toDate();
    if (d is DateTime) return d;
  } catch (_) {}
  return DateTime.now();
}

class UserProfile {
  final String uid;
  final String? email;
  final String? displayName;
  final String? username; // sin el @
  final String? bio;
  final String? photoUrl;
  final String sex; // "Masculino" | "Femenino"
  final double currentWeight; // kg
  final double height; // cm
  final int age;
  final String activityLevel;
  /// "Perder grasa" | "Mantenimiento" | "Ganar músculo"
  final String goal;
  final int targetCalories;
  final int targetProtein; // g
  final int targetCarbs; // g
  final int targetFat; // g
  final bool onboardingCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.uid,
    this.username,
    this.bio,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.sex,
    required this.currentWeight,
    required this.height,
    required this.age,
    required this.activityLevel,
    this.goal = 'Mantenimiento',
    required this.targetCalories,
    this.targetProtein = 0,
    this.targetCarbs = 0,
    this.targetFat = 0,
    this.onboardingCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  static const activityLevels = [
    'Sedentario',
    'Ligero',
    'Moderado',
    'Activo',
    'Muy activo',
  ];

  static const goals = [
    'Perder grasa',
    'Mantenimiento',
    'Ganar músculo',
  ];

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'bio': bio,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'sex': sex,
      'currentWeight': currentWeight,
      'height': height,
      'age': age,
      'activityLevel': activityLevel,
      'goal': goal,
      'targetCalories': targetCalories,
      'targetProtein': targetProtein,
      'targetCarbs': targetCarbs,
      'targetFat': targetFat,
      'onboardingCompleted': onboardingCompleted,
      'createdAt':
      createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: _str(map['uid']),
      username: map['username'],
      bio: map['bio'],
      email: map['email'],
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      sex: _str(map['sex'] ?? map['gender'], 'Masculino'),
      currentWeight: (map['currentWeight'] as num?)?.toDouble() ??
          (map['weight'] as num?)?.toDouble() ??
          65,
      height: (map['height'] as num?)?.toDouble() ?? 170,
      age: map['age'] ?? 25,
      activityLevel: _str(map['activityLevel'], 'Sedentario'),
      goal: _str(map['goal'], 'Mantenimiento'),
      targetCalories: map['targetCalories'] ?? 2000,
      targetProtein: map['targetProtein'] ?? 0,
      targetCarbs: map['targetCarbs'] ?? 0,
      targetFat: map['targetFat'] ?? 0,
      onboardingCompleted: map['onboardingCompleted'] ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'])
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'])
          : null,
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? username,
    String? bio,
    String? photoUrl,
    String? sex,
    double? currentWeight,
    double? height,
    int? age,
    String? activityLevel,
    String? goal,
    int? targetCalories,
    int? targetProtein,
    int? targetCarbs,
    int? targetFat,
    bool? onboardingCompleted,
  }) {
    return UserProfile(
      uid: uid,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      sex: sex ?? this.sex,
      currentWeight: currentWeight ?? this.currentWeight,
      height: height ?? this.height,
      age: age ?? this.age,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      targetFat: targetFat ?? this.targetFat,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Mifflin-St Jeor × actividad × objetivo.
  static int calculateTMB({
    required String sex,
    required double weight,
    required double height,
    required int age,
    required String activityLevel,
    String goal = 'Mantenimiento',
  }) {
    final tmb = sex == 'Masculino'
        ? (10 * weight) + (6.25 * height) - (5 * age) + 5
        : (10 * weight) + (6.25 * height) - (5 * age) - 161;

    final multiplier = switch (activityLevel) {
      'Ligero' => 1.375,
      'Moderado' => 1.55,
      'Activo' => 1.725,
      'Muy activo' || 'Experto' => 1.9,
      _ => 1.2,
    };

    final tdee = tmb * multiplier;
    final adjusted = switch (goal) {
      'Perder grasa' => tdee * 0.85,
      'Ganar músculo' => tdee * 1.10,
      _ => tdee,
    };
    return adjusted.round().clamp(1200, 6000);
  }

  static ({int protein, int carbs, int fat}) calculateMacros({
    required double weight,
    required int calories,
    required String goal,
  }) {
    final proteinPerKg = switch (goal) {
      'Perder grasa' => 2.2,
      'Ganar músculo' => 2.0,
      _ => 1.8,
    };
    final protein = (weight * proteinPerKg).round();
    final fatPct = goal == 'Perder grasa' ? 0.25 : 0.28;
    final fat = ((calories * fatPct) / 9).round();
    final proteinKcal = protein * 4;
    final fatKcal = fat * 9;
    final carbs =
    ((calories - proteinKcal - fatKcal) / 4).round().clamp(0, 1000);
    return (protein: protein, carbs: carbs, fat: fat);
  }
}

class WeightEntry {
  final String id;
  final double weight;
  final DateTime date;

  WeightEntry({required this.id, required this.weight, required this.date});

  Map<String, dynamic> toMap() => {
    'weight': weight,
    'date': date.toIso8601String(),
    'createdAt': DateTime.now().toIso8601String(),
  };

  factory WeightEntry.fromMap(String id, Map<String, dynamic> map) {
    return WeightEntry(
      id: id,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      date: _parseDate(map['date']),
    );
  }
}

class PlannedSet {
  final double weight;
  final int reps;

  const PlannedSet({this.weight = 0, this.reps = 10});

  Map<String, dynamic> toMap() => {
    'weight': weight,
    'reps': reps,
  };

  factory PlannedSet.fromMap(Map<String, dynamic> map) {
    return PlannedSet(
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      reps: map['reps'] ?? 10,
    );
  }

  PlannedSet copyWith({double? weight, int? reps}) {
    return PlannedSet(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
    );
  }
}

class RoutineExercise {
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  /// Compatibilidad: nº de series (si plannedSets vacío se usa esto).
  final int sets;
  /// Reps por defecto al crear series nuevas.
  final int reps;
  /// Series planificadas con peso objetivo.
  final List<PlannedSet> plannedSets;
  /// Descanso entre series de ESTE ejercicio (segundos). Base: 60.
  final int restSeconds;
  final String notes;

  const RoutineExercise({
    required this.exerciseId,
    required this.exerciseName,
    this.muscleGroup = '',
    this.sets = 3,
    this.reps = 10,
    this.plannedSets = const [],
    this.restSeconds = 60,
    this.notes = '',
  });

  /// Series efectivas para entrenar / calcular duración.
  List<PlannedSet> get effectiveSets {
    if (plannedSets.isNotEmpty) return plannedSets;
    final n = sets.clamp(1, 20);
    return List.generate(n, (_) => PlannedSet(weight: 0, reps: reps));
  }

  Map<String, dynamic> toMap() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'muscleGroup': muscleGroup,
    'sets': effectiveSets.length,
    'reps': reps,
    'plannedSets': effectiveSets.map((s) => s.toMap()).toList(),
    'restSeconds': restSeconds,
    'notes': notes,
  };

  factory RoutineExercise.fromMap(Map<String, dynamic> map) {
    final raw = map['plannedSets'];
    final planned = <PlannedSet>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          planned.add(PlannedSet.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    final sets = map['sets'] ?? (planned.isNotEmpty ? planned.length : 3);
    final reps = map['reps'] ?? 10;
    return RoutineExercise(
      exerciseId: _str(map['exerciseId']),
      exerciseName: _str(map['exerciseName']),
      muscleGroup: _str(map['muscleGroup']),
      sets: sets is int ? sets : 3,
      reps: reps is int ? reps : 10,
      plannedSets: planned,
      restSeconds: map['restSeconds'] ?? 60,
      notes: _str(map['notes']),
    );
  }

  RoutineExercise copyWith({
    int? sets,
    int? reps,
    List<PlannedSet>? plannedSets,
    int? restSeconds,
    String? notes,
    String? muscleGroup,
  }) {
    return RoutineExercise(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      plannedSets: plannedSets ?? this.plannedSets,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
    );
  }

  /// Duración estimada de un día (1 min por serie + descansos entre series).
  static String estimateDayDuration(List<RoutineExercise> exercises) {
    if (exercises.isEmpty) return '';
    var totalSec = 0;
    for (final e in exercises) {
      final n = e.effectiveSets.length;
      if (n <= 0) continue;
      totalSec += n * 60; // trabajo ~1 min/serie
      if (n > 1) totalSec += (n - 1) * e.restSeconds;
    }
    if (totalSec <= 0) return '';
    final h = totalSec ~/ 3600;
    final m = (totalSec % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}min';
    return '$m min';
  }
}

class RoutineDay {
  final String day;
  final String title;
  final String duration;
  final int calories;
  final bool isRestDay;
  final String? description;
  final String? imageUrl;
  final List<RoutineExercise> exercises;

  RoutineDay({
    required this.day,
    required this.title,
    this.duration = '',
    this.calories = 0,
    this.isRestDay = false,
    this.description,
    this.imageUrl,
    this.exercises = const [],
  });

  Map<String, dynamic> toMap() => {
    'day': day,
    'title': title,
    'duration': duration,
    'calories': calories,
    'isRestDay': isRestDay,
    'description': description,
    'imageUrl': imageUrl,
    'exercises': exercises.map((e) => e.toMap()).toList(),
  };

  factory RoutineDay.fromMap(Map<String, dynamic> map) {
    final raw = map['exercises'];
    final exercises = <RoutineExercise>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          exercises.add(
            RoutineExercise.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return RoutineDay(
      day: _str(map['day']),
      title: _str(map['title']),
      duration: _str(map['duration']),
      calories: map['calories'] ?? 0,
      isRestDay: map['isRestDay'] ?? false,
      description: map['description'],
      imageUrl: map['imageUrl'],
      exercises: exercises,
    );
  }

  RoutineDay copyWith({
    String? title,
    String? duration,
    int? calories,
    bool? isRestDay,
    List<RoutineExercise>? exercises,
  }) {
    return RoutineDay(
      day: day,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      calories: calories ?? this.calories,
      isRestDay: isRestDay ?? this.isRestDay,
      description: description,
      imageUrl: imageUrl,
      exercises: exercises ?? this.exercises,
    );
  }
}

class SavedFood {
  final String id;
  final String name;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final String? defaultMealType;
  final int useCount;
  final String? updatedAt;

  SavedFood({
    required this.id,
    required this.name,
    required this.calories,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.defaultMealType,
    this.useCount = 0,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'calories': calories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    'defaultMealType': defaultMealType,
    'useCount': useCount,
    'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
  };

  factory SavedFood.fromMap(String id, Map<String, dynamic> map) {
    return SavedFood(
      id: id,
      name: _str(map['name']),
      calories: map['calories'] ?? 0,
      proteinGrams: map['proteinGrams'] ?? 0,
      carbsGrams: map['carbsGrams'] ?? 0,
      fatGrams: map['fatGrams'] ?? 0,
      defaultMealType: map['defaultMealType'],
      useCount: map['useCount'] ?? 0,
      updatedAt: map['updatedAt']?.toString(),
    );
  }

  MealEntry toMeal({required String mealType, String? mealId}) {
    return MealEntry(
      id: mealId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      mealType: mealType,
      calories: calories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
    );
  }
}

class MealEntry {
  final String id;
  final String name;
  final String mealType; // Desayuno | Almuerzo | Cena | Snack
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final String createdAt;

  MealEntry({
    required this.id,
    required this.name,
    required this.mealType,
    required this.calories,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  static const mealTypes = ['Desayuno', 'Almuerzo', 'Cena', 'Snack'];

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'mealType': mealType,
    'calories': calories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    'createdAt': createdAt,
  };

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    return MealEntry(
      id: _str(map['id']),
      name: _str(map['name']),
      mealType: _str(map['mealType'], 'Snack'),
      calories: map['calories'] ?? 0,
      proteinGrams: map['proteinGrams'] ?? 0,
      carbsGrams: map['carbsGrams'] ?? 0,
      fatGrams: map['fatGrams'] ?? 0,
      createdAt: _str(map['createdAt'], DateTime.now().toIso8601String()),
    );
  }
}

class DailyLog {
  final String date;
  final int waterGlasses;
  final double sleepHours;
  final int consumedCalories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final List<MealEntry> meals;

  DailyLog({
    required this.date,
    this.waterGlasses = 0,
    this.sleepHours = 0,
    this.consumedCalories = 0,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.meals = const [],
  });

  Map<String, dynamic> toMap() => {
    'date': date,
    'waterGlasses': waterGlasses,
    'sleepHours': sleepHours,
    'consumedCalories': consumedCalories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    'meals': meals.map((m) => m.toMap()).toList(),
  };

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    final rawMeals = map['meals'];
    final meals = <MealEntry>[];
    if (rawMeals is List) {
      for (final item in rawMeals) {
        if (item is Map) {
          meals.add(MealEntry.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    // Si hay comidas, los totales salen de la suma (fuente de verdad)
    if (meals.isNotEmpty) {
      final cal = meals.fold<int>(0, (s, m) => s + m.calories);
      final p = meals.fold<int>(0, (s, m) => s + m.proteinGrams);
      final c = meals.fold<int>(0, (s, m) => s + m.carbsGrams);
      final f = meals.fold<int>(0, (s, m) => s + m.fatGrams);
      return DailyLog(
        date: _str(map['date']),
        waterGlasses: map['waterGlasses'] ?? 0,
        sleepHours: (map['sleepHours'] as num?)?.toDouble() ?? 0,
        consumedCalories: cal,
        proteinGrams: p,
        carbsGrams: c,
        fatGrams: f,
        meals: meals,
      );
    }

    return DailyLog(
      date: _str(map['date']),
      waterGlasses: map['waterGlasses'] ?? 0,
      sleepHours: (map['sleepHours'] as num?)?.toDouble() ?? 0,
      consumedCalories: map['consumedCalories'] ?? 0,
      proteinGrams: map['proteinGrams'] ?? 0,
      carbsGrams: map['carbsGrams'] ?? 0,
      fatGrams: map['fatGrams'] ?? 0,
      meals: meals,
    );
  }

  List<MealEntry> mealsOfType(String type) =>
      meals.where((m) => m.mealType == type).toList();

  int caloriesOfType(String type) =>
      mealsOfType(type).fold(0, (s, m) => s + m.calories);
}


class WorkoutSetLog {
  final int setNumber;
  final double weight;
  final int reps;
  final bool completed;

  const WorkoutSetLog({
    required this.setNumber,
    this.weight = 0,
    this.reps = 0,
    this.completed = false,
  });

  Map<String, dynamic> toMap() => {
    'setNumber': setNumber,
    'weight': weight,
    'reps': reps,
    'completed': completed,
  };

  factory WorkoutSetLog.fromMap(Map<String, dynamic> map) {
    return WorkoutSetLog(
      setNumber: map['setNumber'] ?? 1,
      weight: (map['weight'] as num?)?.toDouble() ?? 0,
      reps: map['reps'] ?? 0,
      completed: map['completed'] ?? false,
    );
  }

  WorkoutSetLog copyWith({
    double? weight,
    int? reps,
    bool? completed,
  }) {
    return WorkoutSetLog(
      setNumber: setNumber,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      completed: completed ?? this.completed,
    );
  }
}

class WorkoutExerciseLog {
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final String notes;
  final List<WorkoutSetLog> sets;
  /// Descanso entre series de este ejercicio (segundos).
  final int restSeconds;

  const WorkoutExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    this.muscleGroup = '',
    this.notes = '',
    this.sets = const [],
    this.restSeconds = 60,
  });

  Map<String, dynamic> toMap() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'muscleGroup': muscleGroup,
    'notes': notes,
    'sets': sets.map((s) => s.toMap()).toList(),
    'restSeconds': restSeconds,
  };

  factory WorkoutExerciseLog.fromMap(Map<String, dynamic> map) {
    final raw = map['sets'];
    final sets = <WorkoutSetLog>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          sets.add(WorkoutSetLog.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    return WorkoutExerciseLog(
      exerciseId: _str(map['exerciseId']),
      exerciseName: _str(map['exerciseName']),
      muscleGroup: _str(map['muscleGroup']),
      notes: _str(map['notes']),
      sets: sets,
      restSeconds: map['restSeconds'] ?? 60,
    );
  }

  WorkoutExerciseLog copyWith({
    List<WorkoutSetLog>? sets,
    String? notes,
    int? restSeconds,
  }) {
    return WorkoutExerciseLog(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      muscleGroup: muscleGroup,
      notes: notes ?? this.notes,
      sets: sets ?? this.sets,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }

  int get completedSets => sets.where((s) => s.completed).length;
}

class WorkoutSession {
  final String id; // yyyy-MM-dd
  final String dayName;
  final String title;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final bool completed;
  final bool isPaused;
  final int elapsedSeconds;
  final String notes;
  final List<WorkoutExerciseLog> exercises;

  const WorkoutSession({
    required this.id,
    required this.dayName,
    required this.title,
    required this.startedAt,
    this.finishedAt,
    this.completed = false,
    this.isPaused = false,
    this.elapsedSeconds = 0,
    this.notes = '',
    this.exercises = const [],
  });

  static String dateKey([DateTime? d]) {
    final n = d ?? DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static String weekdayName([DateTime? d]) {
    const names = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    final n = d ?? DateTime.now();
    return names[n.weekday - 1];
  }

  factory WorkoutSession.fromRoutine(RoutineDay routine, {DateTime? date}) {
    final d = date ?? DateTime.now();
    final exercises = routine.exercises.map((e) {
      final planned = e.effectiveSets;
      return WorkoutExerciseLog(
        exerciseId: e.exerciseId,
        exerciseName: e.exerciseName,
        muscleGroup: e.muscleGroup,
        notes: e.notes,
        restSeconds: e.restSeconds, // ← ESTA LÍNEA NUEVA
        sets: [
          for (var i = 0; i < planned.length; i++)
            WorkoutSetLog(
              setNumber: i + 1,
              weight: planned[i].weight,
              reps: planned[i].reps,
              completed: false,
            ),
        ],
      );
    }).toList();

    return WorkoutSession(
      id: dateKey(d),
      dayName: routine.day,
      title: routine.title,
      startedAt: DateTime.now(),
      isPaused: false,
      elapsedSeconds: 0,
      exercises: exercises,
    );
  }

  /// Fecha del día de la semana dentro de la semana actual.
  static DateTime dateOfWeekday(String dayName) {
    const names = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo'
    ];
    final target = names.indexOf(dayName) + 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (target < 1) return today;
    return today.add(Duration(days: target - now.weekday));
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'dayName': dayName,
    'title': title,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'completed': completed,
    'isPaused': isPaused,
    'elapsedSeconds': elapsedSeconds,
    'notes': notes,
    'exercises': exercises.map((e) => e.toMap()).toList(),
  };

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    final raw = map['exercises'];
    final exercises = <WorkoutExerciseLog>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          exercises.add(
            WorkoutExerciseLog.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return WorkoutSession(
      id: _str(map['id']),
      dayName: _str(map['dayName']),
      title: _str(map['title']),
      startedAt: _parseDate(map['startedAt']),
      finishedAt: map['finishedAt'] != null
          ? _parseDate(map['finishedAt'])
          : null,
      completed: map['completed'] ?? false,
      isPaused: map['isPaused'] ?? false,
      elapsedSeconds: map['elapsedSeconds'] ?? 0,
      notes: _str(map['notes']),
      exercises: exercises,
    );
  }

  WorkoutSession copyWith({
    DateTime? finishedAt,
    bool? completed,
    bool? isPaused,
    int? elapsedSeconds,
    String? notes,
    List<WorkoutExerciseLog>? exercises,
  }) {
    return WorkoutSession(
      id: id,
      dayName: dayName,
      title: title,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      completed: completed ?? this.completed,
      isPaused: isPaused ?? this.isPaused,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      notes: notes ?? this.notes,
      exercises: exercises ?? this.exercises,
    );
  }

  int get totalSets =>
      exercises.fold(0, (s, e) => s + e.sets.length);
  int get completedSets =>
      exercises.fold(0, (s, e) => s + e.completedSets);
}
