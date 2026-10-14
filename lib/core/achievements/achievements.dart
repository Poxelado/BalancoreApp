import 'package:flutter/material.dart';

import '../../features/profile/domain/user_profile.dart';

/// Dificultad de un logro. Define el color con el que se muestra una vez
/// desbloqueado (los bloqueados van en gris).
enum AchievementTier {
  bronce('Bronce', Color(0xFFCD7F32)),
  plata('Plata', Color(0xFF90A4AE)),
  oro('Oro', Color(0xFFFFC107)),
  platino('Platino', Color(0xFF00BCD4));

  const AchievementTier(this.label, this.color);

  final String label;
  final Color color;
}

enum AchievementCategory {
  entrenamiento('Entrenamiento'),
  racha('Racha'),
  nutricion('Nutrición'),
  peso('Peso'),
  hidratacion('Hidratación'),
  sueno('Sueño'),
  volumen('Volumen'),
  constancia('Constancia'),
  especial('Especial');

  const AchievementCategory(this.label);

  final String label;
}

/// Foto de todos los datos que alimentan los logros. Es pura (se construye a
/// partir del historial) para poder calcularla y testearla sin Firestore.
class AchievementStats {
  final int workouts;
  final int currentStreak;
  final int longestStreak;
  final int meals;
  final int weightEntries;
  final int waterGlasses;
  final int sleepNights;
  final int activeDays;
  final int perfectDays;
  final double totalVolumeKg;
  final int totalSets;
  final int bestWaterDay;
  final int customRoutines;
  final bool morningWorkout;
  final bool nightWorkout;

  const AchievementStats({
    this.workouts = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.meals = 0,
    this.weightEntries = 0,
    this.waterGlasses = 0,
    this.sleepNights = 0,
    this.activeDays = 0,
    this.perfectDays = 0,
    this.totalVolumeKg = 0,
    this.totalSets = 0,
    this.bestWaterDay = 0,
    this.customRoutines = 0,
    this.morningWorkout = false,
    this.nightWorkout = false,
  });

  /// Deriva las estadísticas del historial. `todayLog` y `trainedToday` cubren
  /// el día en curso, que puede no venir aún en [logs].
  factory AchievementStats.from({
    required List<DailyLog> logs,
    required List<WorkoutSession> sessions,
    required List<WeightEntry> weights,
    int customRoutines = 0,
    DailyLog? todayLog,
    bool trainedToday = false,
  }) {
    final completed =
        sessions.where((s) => s.completed).toList(growable: false);

    final logByDate = <String, DailyLog>{};
    for (final l in logs) {
      if (l.date.isNotEmpty) logByDate[l.date] = l;
    }
    if (todayLog != null && todayLog.date.isNotEmpty) {
      logByDate[todayLog.date] = todayLog;
    }

    final trainDates = <String>{};
    var morning = false;
    var night = false;
    var volume = 0.0;
    var sets = 0;
    for (final s in completed) {
      final d = s.startedAt.toLocal();
      trainDates.add(_key(d));
      if (d.hour < 7) morning = true;
      if (d.hour >= 21) night = true;
      volume += s.exercises.fold<double>(0, (a, e) => a + e.volume);
      sets += s.completedSets;
    }
    if (trainedToday) trainDates.add(WorkoutSession.dateKey());

    var meals = 0;
    var water = 0;
    var sleepNights = 0;
    var activeDays = 0;
    var perfectDays = 0;
    var bestWaterDay = 0;
    final allDays = <String>{...logByDate.keys, ...trainDates};
    for (final key in allDays) {
      final l = logByDate[key];
      final hasFood =
          l != null && (l.meals.isNotEmpty || l.consumedCalories > 0);
      final hasWater = l != null && l.waterGlasses > 0;
      final hasSleep = l != null && l.sleepHours > 0;
      final trained = trainDates.contains(key);
      var n = 0;
      if (trained) n++;
      if (hasWater) n++;
      if (hasFood) n++;
      if (hasSleep) n++;
      if (n >= 1) activeDays++;
      if (n >= 4) perfectDays++;
      if (l != null) {
        meals += l.meals.length;
        water += l.waterGlasses;
        if (l.sleepHours > 0) sleepNights++;
        if (l.waterGlasses > bestWaterDay) bestWaterDay = l.waterGlasses;
      }
    }

    bool qualifies(String key) {
      final l = logByDate[key];
      var n = 0;
      if (trainDates.contains(key)) n++;
      if (l != null && l.waterGlasses > 0) n++;
      if (l != null && (l.meals.isNotEmpty || l.consumedCalories > 0)) n++;
      if (l != null && l.sleepHours > 0) n++;
      return n >= 3;
    }

    final (current, longest) = _streaks(allDays, qualifies);

    return AchievementStats(
      workouts: completed.length,
      currentStreak: current,
      longestStreak: longest,
      meals: meals,
      weightEntries: weights.length,
      waterGlasses: water,
      sleepNights: sleepNights,
      activeDays: activeDays,
      perfectDays: perfectDays,
      totalVolumeKg: volume,
      totalSets: sets,
      bestWaterDay: bestWaterDay,
      customRoutines: customRoutines,
      morningWorkout: morning,
      nightWorkout: night,
    );
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Devuelve (racha actual, racha más larga). La racha actual tolera que hoy
  /// todavía no se cumpla (se cuenta desde ayer hacia atrás).
  static (int, int) _streaks(
    Set<String> days,
    bool Function(String) qualifies,
  ) {
    final today = DateTime.now();
    var current = 0;
    for (var i = 0; i < 400; i++) {
      final key = _key(today.subtract(Duration(days: i)));
      if (qualifies(key)) {
        current++;
      } else {
        if (i == 0) continue; // hoy aún puede completarse
        break;
      }
    }

    final sorted = days.where(qualifies).toList()..sort();
    var longest = 0;
    var run = 0;
    DateTime? prev;
    for (final d in sorted) {
      final date = DateTime.tryParse(d);
      if (date == null) continue;
      if (prev != null && date.difference(prev).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
      prev = date;
    }
    if (current > longest) longest = current;
    return (current, longest);
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final AchievementTier tier;
  final AchievementCategory category;
  final int target;
  final int Function(AchievementStats) count;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tier,
    required this.category,
    required this.target,
    required this.count,
  });

  bool isUnlocked(AchievementStats s) => count(s) >= target;

  double progress(AchievementStats s) =>
      target <= 0 ? 1 : (count(s) / target).clamp(0.0, 1.0);
}

/// Catálogo completo de logros: todos los hitos posibles de la app.
class AchievementsCatalog {
  AchievementsCatalog._();

  static final List<Achievement> all = [
    // ── Entrenamiento ──
    _a('first_workout', 'Primer paso', 'Completa tu primer entrenamiento.',
        Icons.fitness_center, AchievementTier.bronce,
        AchievementCategory.entrenamiento, 1, (s) => s.workouts),
    _a('w5', 'Calentando motores', 'Completa 5 entrenamientos.',
        Icons.fitness_center, AchievementTier.bronce,
        AchievementCategory.entrenamiento, 5, (s) => s.workouts),
    _a('w10', 'Constante', 'Completa 10 entrenamientos.',
        Icons.fitness_center, AchievementTier.plata,
        AchievementCategory.entrenamiento, 10, (s) => s.workouts),
    _a('w25', 'Veterano', 'Completa 25 entrenamientos.',
        Icons.fitness_center, AchievementTier.plata,
        AchievementCategory.entrenamiento, 25, (s) => s.workouts),
    _a('w50', 'Imparable', 'Completa 50 entrenamientos.',
        Icons.fitness_center, AchievementTier.oro,
        AchievementCategory.entrenamiento, 50, (s) => s.workouts),
    _a('w100', 'Centenario', 'Completa 100 entrenamientos.',
        Icons.fitness_center, AchievementTier.platino,
        AchievementCategory.entrenamiento, 100, (s) => s.workouts),

    // ── Racha ──
    _a('streak3', 'Racha encendida', '3 días seguidos de hábitos.',
        Icons.local_fire_department, AchievementTier.bronce,
        AchievementCategory.racha, 3, (s) => s.longestStreak),
    _a('streak7', 'Semana perfecta', '7 días seguidos de hábitos.',
        Icons.local_fire_department, AchievementTier.plata,
        AchievementCategory.racha, 7, (s) => s.longestStreak),
    _a('streak14', 'Quincena de hierro', '14 días seguidos de hábitos.',
        Icons.local_fire_department, AchievementTier.plata,
        AchievementCategory.racha, 14, (s) => s.longestStreak),
    _a('streak30', 'Mes de fuego', '30 días seguidos de hábitos.',
        Icons.local_fire_department, AchievementTier.oro,
        AchievementCategory.racha, 30, (s) => s.longestStreak),
    _a('streak100', 'Leyenda', '100 días seguidos de hábitos.',
        Icons.local_fire_department, AchievementTier.platino,
        AchievementCategory.racha, 100, (s) => s.longestStreak),

    // ── Nutrición ──
    _a('m1', 'Primer bocado', 'Registra tu primera comida.',
        Icons.restaurant, AchievementTier.bronce,
        AchievementCategory.nutricion, 1, (s) => s.meals),
    _a('m10', 'Anotador', 'Registra 10 comidas.',
        Icons.restaurant, AchievementTier.bronce,
        AchievementCategory.nutricion, 10, (s) => s.meals),
    _a('m50', 'Nutricionista', 'Registra 50 comidas.',
        Icons.restaurant, AchievementTier.plata,
        AchievementCategory.nutricion, 50, (s) => s.meals),
    _a('m100', 'Chef de macros', 'Registra 100 comidas.',
        Icons.restaurant, AchievementTier.oro,
        AchievementCategory.nutricion, 100, (s) => s.meals),
    _a('m250', 'Maestro de la dieta', 'Registra 250 comidas.',
        Icons.restaurant, AchievementTier.platino,
        AchievementCategory.nutricion, 250, (s) => s.meals),

    // ── Peso ──
    _a('p1', 'Primer pesaje', 'Registra tu peso por primera vez.',
        Icons.monitor_weight, AchievementTier.bronce,
        AchievementCategory.peso, 1, (s) => s.weightEntries),
    _a('p5', 'Siguiendo la línea', 'Registra tu peso 5 veces.',
        Icons.monitor_weight, AchievementTier.bronce,
        AchievementCategory.peso, 5, (s) => s.weightEntries),
    _a('p10', 'Décimo registro', 'Registra tu peso 10 veces.',
        Icons.monitor_weight, AchievementTier.plata,
        AchievementCategory.peso, 10, (s) => s.weightEntries),
    _a('p25', 'Analista de tendencia', 'Registra tu peso 25 veces.',
        Icons.monitor_weight, AchievementTier.oro,
        AchievementCategory.peso, 25, (s) => s.weightEntries),

    // ── Hidratación ──
    _a('h1', 'Primer sorbo', 'Registra tu primer vaso de agua.',
        Icons.water_drop, AchievementTier.bronce,
        AchievementCategory.hidratacion, 1, (s) => s.waterGlasses),
    _a('h100', 'Bien hidratado', 'Suma 100 vasos de agua.',
        Icons.water_drop, AchievementTier.plata,
        AchievementCategory.hidratacion, 100, (s) => s.waterGlasses),
    _a('h500', 'Fuente viviente', 'Suma 500 vasos de agua.',
        Icons.water_drop, AchievementTier.oro,
        AchievementCategory.hidratacion, 500, (s) => s.waterGlasses),
    _a('h1000', 'Océano', 'Suma 1000 vasos de agua.',
        Icons.water_drop, AchievementTier.platino,
        AchievementCategory.hidratacion, 1000, (s) => s.waterGlasses),
    _a('h10day', 'Día bien regado', 'Toma 10 vasos de agua en un día.',
        Icons.water_drop, AchievementTier.plata,
        AchievementCategory.hidratacion, 10, (s) => s.bestWaterDay),

    // ── Sueño ──
    _a('s1', 'Primera noche', 'Registra tus horas de sueño.',
        Icons.bedtime, AchievementTier.bronce,
        AchievementCategory.sueno, 1, (s) => s.sleepNights),
    _a('s7', 'Descanso reparador', 'Registra el sueño 7 noches.',
        Icons.bedtime, AchievementTier.plata,
        AchievementCategory.sueno, 7, (s) => s.sleepNights),
    _a('s30', 'Dormilón saludable', 'Registra el sueño 30 noches.',
        Icons.bedtime, AchievementTier.oro,
        AchievementCategory.sueno, 30, (s) => s.sleepNights),

    // ── Volumen ──
    _a('v1t', 'Una tonelada', 'Levanta 1.000 kg en total.',
        Icons.trending_up, AchievementTier.bronce,
        AchievementCategory.volumen, 1000, (s) => s.totalVolumeKg.round()),
    _a('v10t', 'Diez toneladas', 'Levanta 10.000 kg en total.',
        Icons.trending_up, AchievementTier.plata,
        AchievementCategory.volumen, 10000, (s) => s.totalVolumeKg.round()),
    _a('v100t', 'Cien toneladas', 'Levanta 100.000 kg en total.',
        Icons.trending_up, AchievementTier.oro,
        AchievementCategory.volumen, 100000, (s) => s.totalVolumeKg.round()),
    _a('v1000t', 'Mil toneladas', 'Levanta 1.000.000 kg en total.',
        Icons.trending_up, AchievementTier.platino,
        AchievementCategory.volumen, 1000000,
        (s) => s.totalVolumeKg.round()),

    // ── Constancia ──
    _a('active7', 'Semana activa', 'Registra algo 7 días distintos.',
        Icons.calendar_month, AchievementTier.bronce,
        AchievementCategory.constancia, 7, (s) => s.activeDays),
    _a('active30', 'Mes activo', 'Registra algo 30 días distintos.',
        Icons.calendar_month, AchievementTier.plata,
        AchievementCategory.constancia, 30, (s) => s.activeDays),
    _a('active100', 'Cien días', 'Registra algo 100 días distintos.',
        Icons.calendar_month, AchievementTier.oro,
        AchievementCategory.constancia, 100, (s) => s.activeDays),
    _a('perfect1', 'Día perfecto', 'Completa los 4 hábitos en un día.',
        Icons.verified, AchievementTier.plata,
        AchievementCategory.constancia, 1, (s) => s.perfectDays),
    _a('perfect10', 'Diez días perfectos', 'Completa los 4 hábitos 10 días.',
        Icons.verified, AchievementTier.oro,
        AchievementCategory.constancia, 10, (s) => s.perfectDays),
    _a('perfect30', 'Mes perfecto', 'Completa los 4 hábitos 30 días.',
        Icons.verified, AchievementTier.platino,
        AchievementCategory.constancia, 30, (s) => s.perfectDays),

    // ── Especial ──
    _a('morning', 'Madrugador', 'Entrena antes de las 7:00.',
        Icons.wb_twilight, AchievementTier.plata,
        AchievementCategory.especial, 1, (s) => s.morningWorkout ? 1 : 0),
    _a('night', 'Noctámbulo', 'Entrena después de las 21:00.',
        Icons.nights_stay, AchievementTier.plata,
        AchievementCategory.especial, 1, (s) => s.nightWorkout ? 1 : 0),
    _a('sets1000', 'Mil series', 'Completa 1.000 series en total.',
        Icons.repeat, AchievementTier.oro,
        AchievementCategory.especial, 1000, (s) => s.totalSets),
    _a('routines1', 'Diseñador', 'Crea tu primera rutina personalizada.',
        Icons.construction, AchievementTier.bronce,
        AchievementCategory.especial, 1, (s) => s.customRoutines),
  ];

  static Achievement _a(
    String id,
    String title,
    String description,
    IconData icon,
    AchievementTier tier,
    AchievementCategory category,
    int target,
    int Function(AchievementStats) count,
  ) =>
      Achievement(
        id: id,
        title: title,
        description: description,
        icon: icon,
        tier: tier,
        category: category,
        target: target,
        count: count,
      );

  static List<Achievement> unlockedBy(AchievementStats stats) =>
      all.where((a) => a.isUnlocked(stats)).toList(growable: false);
}
