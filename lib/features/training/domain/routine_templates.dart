import '../../profile/domain/user_profile.dart';
import 'exercise.dart';

class RoutineTemplate {
  final String id;
  final String name;
  final String description;
  final List<RoutineDay> week;

  const RoutineTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.week,
  });
}

RoutineExercise _ex(String id, {int sets = 3, int reps = 10}) {
  final e = ExerciseCatalog.byId(id);
  return RoutineExercise(
    exerciseId: id,
    exerciseName: e?.name ?? id,
    muscleGroup: e?.muscleGroup ?? '',
    sets: sets,
    reps: reps,
  );
}

RoutineDay _day(
    String day,
    String title, {
      bool rest = false,
      List<RoutineExercise> exercises = const [],
      String duration = '45–60 min',
    }) {
  return RoutineDay(
    day: day,
    title: title,
    isRestDay: rest,
    exercises: exercises,
    duration: rest ? '' : duration,
    calories: rest ? 0 : 350,
  );
}

class RoutineTemplates {
  static final List<RoutineTemplate> all = [
    RoutineTemplate(
      id: 'full_body_3',
      name: 'Full Body (3 días)',
      description: 'Cuerpo completo lunes, miércoles y viernes. Ideal para empezar.',
      week: [
        _day('Lunes', 'Full Body A', exercises: [
          _ex('ex_squat', sets: 3, reps: 8),
          _ex('ex_bench_press', sets: 3, reps: 8),
          _ex('ex_barbell_row', sets: 3, reps: 8),
          _ex('ex_ohp', sets: 3, reps: 10),
          _ex('ex_plank', sets: 3, reps: 30),
        ]),
        _day('Martes', 'Descanso', rest: true),
        _day('Miércoles', 'Full Body B', exercises: [
          _ex('ex_romanian_deadlift', sets: 3, reps: 8),
          _ex('ex_incline_dumbbell', sets: 3, reps: 10),
          _ex('ex_lat_pulldown', sets: 3, reps: 10),
          _ex('ex_lateral_raise', sets: 3, reps: 12),
          _ex('ex_barbell_curl', sets: 2, reps: 12),
        ]),
        _day('Jueves', 'Descanso', rest: true),
        _day('Viernes', 'Full Body C', exercises: [
          _ex('ex_leg_press', sets: 3, reps: 12),
          _ex('ex_pushups', sets: 3, reps: 12),
          _ex('ex_seated_row', sets: 3, reps: 10),
          _ex('ex_triceps_pushdown', sets: 3, reps: 12),
          _ex('ex_crunch', sets: 3, reps: 15),
        ]),
        _day('Sábado', 'Cardio ligero', exercises: [
          _ex('ex_treadmill', sets: 1, reps: 20),
        ], duration: '20–30 min'),
        _day('Domingo', 'Descanso', rest: true),
      ],
    ),
    RoutineTemplate(
      id: 'ppl',
      name: 'Push / Pull / Legs',
      description: 'Empuje, jalón y pierna. 6 días con un descanso.',
      week: [
        _day('Lunes', 'Push', exercises: [
          _ex('ex_bench_press', sets: 4, reps: 8),
          _ex('ex_ohp', sets: 3, reps: 8),
          _ex('ex_incline_dumbbell', sets: 3, reps: 10),
          _ex('ex_lateral_raise', sets: 3, reps: 12),
          _ex('ex_triceps_pushdown', sets: 3, reps: 12),
        ]),
        _day('Martes', 'Pull', exercises: [
          _ex('ex_pullups', sets: 3, reps: 8),
          _ex('ex_barbell_row', sets: 4, reps: 8),
          _ex('ex_lat_pulldown', sets: 3, reps: 10),
          _ex('ex_face_pull', sets: 3, reps: 15),
          _ex('ex_barbell_curl', sets: 3, reps: 10),
        ]),
        _day('Miércoles', 'Legs', exercises: [
          _ex('ex_squat', sets: 4, reps: 6),
          _ex('ex_romanian_deadlift', sets: 3, reps: 8),
          _ex('ex_leg_press', sets: 3, reps: 12),
          _ex('ex_leg_curl', sets: 3, reps: 12),
          _ex('ex_plank', sets: 3, reps: 30),
        ]),
        _day('Jueves', 'Push', exercises: [
          _ex('ex_incline_dumbbell', sets: 4, reps: 8),
          _ex('ex_ohp', sets: 3, reps: 10),
          _ex('ex_cable_fly', sets: 3, reps: 12),
          _ex('ex_lateral_raise', sets: 3, reps: 15),
          _ex('ex_triceps_pushdown', sets: 3, reps: 12),
        ]),
        _day('Viernes', 'Pull', exercises: [
          _ex('ex_seated_row', sets: 4, reps: 8),
          _ex('ex_lat_pulldown', sets: 3, reps: 10),
          _ex('ex_barbell_row', sets: 3, reps: 10),
          _ex('ex_hammer_curl', sets: 3, reps: 12),
          _ex('ex_face_pull', sets: 3, reps: 15),
        ]),
        _day('Sábado', 'Legs', exercises: [
          _ex('ex_leg_press', sets: 4, reps: 10),
          _ex('ex_lunges', sets: 3, reps: 10),
          _ex('ex_leg_curl', sets: 3, reps: 12),
          _ex('ex_crunch', sets: 3, reps: 15),
        ]),
        _day('Domingo', 'Descanso', rest: true),
      ],
    ),
    RoutineTemplate(
      id: 'upper_lower',
      name: 'Upper / Lower',
      description: 'Superior e inferior alternados. Buen equilibrio volumen/descanso.',
      week: [
        _day('Lunes', 'Upper A', exercises: [
          _ex('ex_bench_press', sets: 4, reps: 8),
          _ex('ex_barbell_row', sets: 4, reps: 8),
          _ex('ex_ohp', sets: 3, reps: 10),
          _ex('ex_lat_pulldown', sets: 3, reps: 10),
          _ex('ex_barbell_curl', sets: 2, reps: 12),
          _ex('ex_triceps_pushdown', sets: 2, reps: 12),
        ]),
        _day('Martes', 'Lower A', exercises: [
          _ex('ex_squat', sets: 4, reps: 6),
          _ex('ex_romanian_deadlift', sets: 3, reps: 8),
          _ex('ex_leg_press', sets: 3, reps: 12),
          _ex('ex_leg_curl', sets: 3, reps: 12),
          _ex('ex_plank', sets: 3, reps: 30),
        ]),
        _day('Miércoles', 'Descanso', rest: true),
        _day('Jueves', 'Upper B', exercises: [
          _ex('ex_incline_dumbbell', sets: 4, reps: 8),
          _ex('ex_seated_row', sets: 4, reps: 8),
          _ex('ex_lateral_raise', sets: 3, reps: 12),
          _ex('ex_pullups', sets: 3, reps: 8),
          _ex('ex_hammer_curl', sets: 2, reps: 12),
          _ex('ex_face_pull', sets: 2, reps: 15),
        ]),
        _day('Viernes', 'Lower B', exercises: [
          _ex('ex_leg_press', sets: 4, reps: 10),
          _ex('ex_lunges', sets: 3, reps: 10),
          _ex('ex_leg_curl', sets: 3, reps: 12),
          _ex('ex_crunch', sets: 3, reps: 15),
          _ex('ex_treadmill', sets: 1, reps: 15),
        ]),
        _day('Sábado', 'Descanso activo', exercises: [
          _ex('ex_bike', sets: 1, reps: 25),
        ], duration: '25 min'),
        _day('Domingo', 'Descanso', rest: true),
      ],
    ),
  ];
}
