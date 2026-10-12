part of 'user_profile.dart';

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

