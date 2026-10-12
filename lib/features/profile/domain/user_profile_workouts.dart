part of 'user_profile.dart';

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
  final int? rpe;

  const WorkoutExerciseLog({
    required this.exerciseId,
    required this.exerciseName,
    this.muscleGroup = '',
    this.notes = '',
    this.sets = const [],
    this.restSeconds = 60,
    this.rpe,
  });

  Map<String, dynamic> toMap() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'muscleGroup': muscleGroup,
    'notes': notes,
    'sets': sets.map((s) => s.toMap()).toList(),
    'restSeconds': restSeconds,
    'rpe': rpe,
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
      rpe: map['rpe'] as int?,
    );
  }

  WorkoutExerciseLog copyWith({
    List<WorkoutSetLog>? sets,
    String? notes,
    int? restSeconds,
    int? rpe,
  }) {
    return WorkoutExerciseLog(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      muscleGroup: muscleGroup,
      notes: notes ?? this.notes,
      sets: sets ?? this.sets,
      restSeconds: restSeconds ?? this.restSeconds,
      rpe: rpe ?? this.rpe,
    );
  }

  int get completedSets => sets.where((s) => s.completed).length;
}

class WorkoutSession {
  final String id; // único por sesión (no solo la fecha)
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

  static String newSessionId([DateTime? at]) {
    final n = at ?? DateTime.now();
    final date = dateKey(n);
    final h = n.hour.toString().padLeft(2, '0');
    final m = n.minute.toString().padLeft(2, '0');
    final s = n.second.toString().padLeft(2, '0');
    final ms = n.millisecond.toString().padLeft(3, '0');
    return '${date}_$h$m${s}_$ms';
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
      id: newSessionId(),
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
