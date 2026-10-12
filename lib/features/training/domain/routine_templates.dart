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
          _ex('Barbell_Squat', sets: 3, reps: 8),
          _ex('Barbell_Bench_Press_-_Medium_Grip', sets: 3, reps: 8),
          _ex('Bent_Over_Barbell_Row', sets: 3, reps: 8),
          _ex('Standing_Military_Press', sets: 3, reps: 10),
          _ex('Plank', sets: 3, reps: 30),
        ]),
        _day('Martes', 'Descanso', rest: true),
        _day('Miércoles', 'Full Body B', exercises: [
          _ex('Romanian_Deadlift', sets: 3, reps: 8),
          _ex('Incline_Dumbbell_Press', sets: 3, reps: 10),
          _ex('Wide-Grip_Lat_Pulldown', sets: 3, reps: 10),
          _ex('Side_Lateral_Raise', sets: 3, reps: 12),
          _ex('Barbell_Curl', sets: 2, reps: 12),
        ]),
        _day('Jueves', 'Descanso', rest: true),
        _day('Viernes', 'Full Body C', exercises: [
          _ex('Leg_Press', sets: 3, reps: 12),
          _ex('Pushups', sets: 3, reps: 12),
          _ex('Seated_Cable_Rows', sets: 3, reps: 10),
          _ex('Triceps_Pushdown', sets: 3, reps: 12),
          _ex('Crunches', sets: 3, reps: 15),
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
          _ex('Barbell_Bench_Press_-_Medium_Grip', sets: 4, reps: 8),
          _ex('Standing_Military_Press', sets: 3, reps: 8),
          _ex('Incline_Dumbbell_Press', sets: 3, reps: 10),
          _ex('Side_Lateral_Raise', sets: 3, reps: 12),
          _ex('Triceps_Pushdown', sets: 3, reps: 12),
        ]),
        _day('Martes', 'Pull', exercises: [
          _ex('Pullups', sets: 3, reps: 8),
          _ex('Bent_Over_Barbell_Row', sets: 4, reps: 8),
          _ex('Wide-Grip_Lat_Pulldown', sets: 3, reps: 10),
          _ex('Face_Pull', sets: 3, reps: 15),
          _ex('Barbell_Curl', sets: 3, reps: 10),
        ]),
        _day('Miércoles', 'Legs', exercises: [
          _ex('Barbell_Squat', sets: 4, reps: 6),
          _ex('Romanian_Deadlift', sets: 3, reps: 8),
          _ex('Leg_Press', sets: 3, reps: 12),
          _ex('Lying_Leg_Curls', sets: 3, reps: 12),
          _ex('Plank', sets: 3, reps: 30),
        ]),
        _day('Jueves', 'Push', exercises: [
          _ex('Incline_Dumbbell_Press', sets: 4, reps: 8),
          _ex('Standing_Military_Press', sets: 3, reps: 10),
          _ex('Cable_Crossover', sets: 3, reps: 12),
          _ex('Side_Lateral_Raise', sets: 3, reps: 15),
          _ex('Triceps_Pushdown', sets: 3, reps: 12),
        ]),
        _day('Viernes', 'Pull', exercises: [
          _ex('Seated_Cable_Rows', sets: 4, reps: 8),
          _ex('Wide-Grip_Lat_Pulldown', sets: 3, reps: 10),
          _ex('Bent_Over_Barbell_Row', sets: 3, reps: 10),
          _ex('Hammer_Curls', sets: 3, reps: 12),
          _ex('Face_Pull', sets: 3, reps: 15),
        ]),
        _day('Sábado', 'Legs', exercises: [
          _ex('Leg_Press', sets: 4, reps: 10),
          _ex('Bodyweight_Walking_Lunge', sets: 3, reps: 10),
          _ex('Lying_Leg_Curls', sets: 3, reps: 12),
          _ex('Crunches', sets: 3, reps: 15),
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
          _ex('Barbell_Bench_Press_-_Medium_Grip', sets: 4, reps: 8),
          _ex('Bent_Over_Barbell_Row', sets: 4, reps: 8),
          _ex('Standing_Military_Press', sets: 3, reps: 10),
          _ex('Wide-Grip_Lat_Pulldown', sets: 3, reps: 10),
          _ex('Barbell_Curl', sets: 2, reps: 12),
          _ex('Triceps_Pushdown', sets: 2, reps: 12),
        ]),
        _day('Martes', 'Lower A', exercises: [
          _ex('Barbell_Squat', sets: 4, reps: 6),
          _ex('Romanian_Deadlift', sets: 3, reps: 8),
          _ex('Leg_Press', sets: 3, reps: 12),
          _ex('Lying_Leg_Curls', sets: 3, reps: 12),
          _ex('Plank', sets: 3, reps: 30),
        ]),
        _day('Miércoles', 'Descanso', rest: true),
        _day('Jueves', 'Upper B', exercises: [
          _ex('Incline_Dumbbell_Press', sets: 4, reps: 8),
          _ex('Seated_Cable_Rows', sets: 4, reps: 8),
          _ex('Side_Lateral_Raise', sets: 3, reps: 12),
          _ex('Pullups', sets: 3, reps: 8),
          _ex('Hammer_Curls', sets: 2, reps: 12),
          _ex('Face_Pull', sets: 2, reps: 15),
        ]),
        _day('Viernes', 'Lower B', exercises: [
          _ex('Leg_Press', sets: 4, reps: 10),
          _ex('Bodyweight_Walking_Lunge', sets: 3, reps: 10),
          _ex('Lying_Leg_Curls', sets: 3, reps: 12),
          _ex('Crunches', sets: 3, reps: 15),
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
