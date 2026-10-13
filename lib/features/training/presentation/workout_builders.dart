import 'package:flutter/foundation.dart';

import '../../profile/data/profile_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../domain/exercise.dart';

/// Construye el registro de un ejercicio para una sesión de entrenamiento
/// (libre o de rutina extra). Si el usuario tiene valores por defecto
/// guardados para ese ejercicio (peso/reps por serie, descanso y notas), se
/// respetan; si no, arranca con 3 series de 10 reps y 60 s de descanso.
Future<WorkoutExerciseLog> buildWorkoutExerciseLog({
  required ProfileRepository repo,
  required Exercise exercise,
  String? uid,
}) async {
  var rest = 60;
  var notes = '';
  var planned = <PlannedSet>[
    const PlannedSet(weight: 0, reps: 10),
    const PlannedSet(weight: 0, reps: 10),
    const PlannedSet(weight: 0, reps: 10),
  ];

  if (uid != null && uid.isNotEmpty) {
    try {
      final data = await repo.getExerciseDefault(uid, exercise.id);
      if (data != null) {
        rest = (data['restSeconds'] as num?)?.toInt() ?? 60;
        notes = (data['notes'] as String?) ?? '';
        final raw = data['plannedSets'];
        if (raw is List && raw.isNotEmpty) {
          final parsed = [
            for (final item in raw)
              if (item is Map)
                PlannedSet.fromMap(Map<String, dynamic>.from(item)),
          ];
          if (parsed.isNotEmpty) planned = parsed;
        }
      }
    } catch (e) {
      debugPrint(
        'workout_builders: sin valores por defecto para ${exercise.id}: $e',
      );
    }
  }

  return WorkoutExerciseLog(
    exerciseId: exercise.id,
    exerciseName: exercise.name,
    muscleGroup: exercise.muscleGroup,
    notes: notes,
    restSeconds: rest <= 0 ? 60 : rest,
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
}
