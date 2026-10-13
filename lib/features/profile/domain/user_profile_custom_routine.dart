part of 'user_profile.dart';

/// Rutina extra creada por el usuario, además de la rutina semanal.
/// Se guarda en `users/{uid}/customRoutines/{id}` y puede lanzarse en
/// cualquier momento sin ocupar un día de la semana.
class CustomRoutine {
  final String id;
  final String name;
  final List<RoutineExercise> exercises;
  final DateTime? createdAt;

  const CustomRoutine({
    this.id = '',
    required this.name,
    this.exercises = const [],
    this.createdAt,
  });

  static String newId() => 'cr_${DateTime.now().millisecondsSinceEpoch}';

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.effectiveSets.length);

  String get estimatedDuration =>
      RoutineExercise.estimateDayDuration(exercises);

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'createdAt': createdAt?.toIso8601String(),
      };

  factory CustomRoutine.fromMap(Map<String, dynamic> map) {
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
    return CustomRoutine(
      id: _str(map['id']),
      name: _str(map['name']),
      exercises: exercises,
      createdAt:
          map['createdAt'] != null ? _parseDate(map['createdAt']) : null,
    );
  }

  CustomRoutine copyWith({
    String? id,
    String? name,
    List<RoutineExercise>? exercises,
    DateTime? createdAt,
  }) {
    return CustomRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
