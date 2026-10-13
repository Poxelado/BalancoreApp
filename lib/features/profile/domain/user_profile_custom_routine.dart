part of 'user_profile.dart';

/// Un entrenamiento dentro de una rutina extra (p. ej. "Día 1 · Pecho").
/// Agrupa una lista de ejercicios con sus series planificadas.
class CustomWorkout {
  final String id;
  final String name;
  final List<RoutineExercise> exercises;

  const CustomWorkout({
    this.id = '',
    required this.name,
    this.exercises = const [],
  });

  static String newId() => 'cw_${DateTime.now().microsecondsSinceEpoch}';

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.effectiveSets.length);

  String get estimatedDuration => RoutineExercise.estimateDayDuration(exercises);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  factory CustomWorkout.fromMap(Map<String, dynamic> map) {
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
    return CustomWorkout(
      id: _str(map['id']),
      name: _str(map['name']),
      exercises: exercises,
    );
  }

  CustomWorkout copyWith({
    String? id,
    String? name,
    List<RoutineExercise>? exercises,
  }) {
    return CustomWorkout(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
    );
  }
}

/// Rutina extra creada por el usuario, además de la rutina semanal.
/// Contiene uno o varios entrenamientos, cada uno con sus ejercicios.
/// Se guarda en `users/{uid}/customRoutines/{id}` y puede lanzarse en
/// cualquier momento sin ocupar un día de la semana.
class CustomRoutine {
  final String id;
  final String name;
  final List<CustomWorkout> workouts;
  final DateTime? createdAt;

  const CustomRoutine({
    this.id = '',
    required this.name,
    this.workouts = const [],
    this.createdAt,
  });

  static String newId() => 'cr_${DateTime.now().millisecondsSinceEpoch}';

  int get workoutCount => workouts.length;

  int get exerciseCount =>
      workouts.fold(0, (sum, w) => sum + w.exercises.length);

  int get totalSets => workouts.fold(0, (sum, w) => sum + w.totalSets);

  String get estimatedDuration =>
      RoutineExercise.estimateDayDuration(
        [for (final w in workouts) ...w.exercises],
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'workouts': workouts.map((w) => w.toMap()).toList(),
        'createdAt': createdAt?.toIso8601String(),
      };

  factory CustomRoutine.fromMap(Map<String, dynamic> map) {
    final workouts = <CustomWorkout>[];
    final rawWorkouts = map['workouts'];
    if (rawWorkouts is List) {
      for (final item in rawWorkouts) {
        if (item is Map) {
          workouts.add(
            CustomWorkout.fromMap(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    // Compatibilidad con el formato anterior (lista plana de ejercicios).
    if (workouts.isEmpty) {
      final raw = map['exercises'];
      if (raw is List && raw.isNotEmpty) {
        final exercises = <RoutineExercise>[];
        for (final item in raw) {
          if (item is Map) {
            exercises.add(
              RoutineExercise.fromMap(Map<String, dynamic>.from(item)),
            );
          }
        }
        workouts.add(
          CustomWorkout(name: 'Entrenamiento 1', exercises: exercises),
        );
      }
    }
    return CustomRoutine(
      id: _str(map['id']),
      name: _str(map['name']),
      workouts: workouts,
      createdAt:
          map['createdAt'] != null ? _parseDate(map['createdAt']) : null,
    );
  }

  CustomRoutine copyWith({
    String? id,
    String? name,
    List<CustomWorkout>? workouts,
    DateTime? createdAt,
  }) {
    return CustomRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      workouts: workouts ?? this.workouts,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
