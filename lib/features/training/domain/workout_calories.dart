/// Estimación del gasto calórico de un entrenamiento.
///
/// Usa la fórmula estándar de equivalentes metabólicos (MET):
///
///   kcal = MET × 3,5 × peso(kg) / 200 × minutos
///
/// El MET se estima a partir del RPE medio registrado (si existe) y del tipo
/// de sesión (fuerza vs. cardio). Es una estimación orientativa, no médica.
library;

import '../../profile/domain/user_profile.dart';

/// MET por defecto para entrenamiento de fuerza sin RPE registrado
/// (Compendio de Actividades Físicas: fuerza, esfuerzo vigoroso).
const double _defaultStrengthMet = 5.0;

/// MET para sesiones reconocidas como cardio/HIIT.
const double _cardioMet = 8.0;

const List<String> _cardioKeywords = [
  'cardio',
  'hiit',
  'correr',
  'carrera',
  'trote',
  'bici',
  'cicl',
  'elípt',
  'elipt',
  'remo',
  'salt',
  'burpee',
  'cuerda',
  'natac',
  'nadar',
  'tabata',
  'circuito',
  'aerob',
  'spinning',
  'funcional',
  'caminata',
];

bool _looksLikeCardio(WorkoutSession s) {
  final hay = '${s.title} ${s.dayName} '
          '${s.exercises.map((e) => e.muscleGroup).join(' ')}'
      .toLowerCase();
  return _cardioKeywords.any(hay.contains);
}

/// MET estimado de la sesión.
double estimateWorkoutMet(WorkoutSession s) {
  if (_looksLikeCardio(s)) return _cardioMet;
  final rpes = s.exercises.map((e) => e.rpe).whereType<int>().toList();
  if (rpes.isEmpty) return _defaultStrengthMet;
  final avg = rpes.reduce((a, b) => a + b) / rpes.length;
  // RPE 6 ≈ esfuerzo moderado (MET 4). Cada punto extra de RPE suma ~0,7 MET.
  return (4.0 + (avg - 6) * 0.7).clamp(3.5, 8.0);
}

/// Kcal quemadas en la sesión. Devuelve 0 si no hay duración o peso válidos.
int estimateWorkoutCalories(WorkoutSession s, {required double weightKg}) {
  final minutes = s.elapsedSeconds / 60.0;
  if (minutes <= 0 || weightKg <= 0) return 0;
  final met = estimateWorkoutMet(s);
  final kcal = met * 3.5 * weightKg / 200.0 * minutes;
  return kcal.round();
}
