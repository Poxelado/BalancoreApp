part of 'user_profile.dart';

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
  /// ml de agua recomendados al día (~35 ml/kg).
  final int targetWaterMl;
  /// Fechas ISO de cambios de username (para límite 3/mes).
  final List<String> usernameChangeDates;
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
    this.targetWaterMl = 0,
    this.usernameChangeDates = const [],
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
      'targetWaterMl': targetWaterMl,
      'usernameChangeDates': usernameChangeDates,
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
      targetWaterMl: map['targetWaterMl'] ?? 0,
      usernameChangeDates: (map['usernameChangeDates'] is List)
          ? (map['usernameChangeDates'] as List).map((e) => e.toString()).toList()
          : const [],
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
    int? targetWaterMl,
    List<String>? usernameChangeDates,
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
      targetWaterMl: targetWaterMl ?? this.targetWaterMl,
      usernameChangeDates: usernameChangeDates ?? this.usernameChangeDates,
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
    double height = 0,
    required int calories,
    required String goal,
  }) {
    final proteinPerKg = switch (goal) {
      'Perder grasa' => 2.2,
      'Ganar músculo' => 2.0,
      _ => 1.8,
    };
    final cal = calories < 0 ? 0 : calories;

    // Peso de referencia: con IMC alto se usa peso ajustado en vez del total,
    // para no pedir una proteína desproporcionada por la grasa corporal.
    final ref = _proteinReferenceWeight(weightKg: weight, heightCm: height);

    var protein = (ref * proteinPerKg).round();
    final fatPct = goal == 'Perder grasa' ? 0.25 : 0.28;
    var fat = ((cal * fatPct) / 9).round();

    // La proteína y la grasa nunca deben superar el presupuesto calórico:
    // si lo hacen (p. ej. con una meta manual muy baja), se recorta primero
    // la proteína y, si aún no cabe, la grasa. Los carbos son el resto.
    if (protein * 4 + fat * 9 > cal) {
      final room = cal - fat * 9;
      protein = room > 0 ? (room / 4).floor() : 0;
    }
    if (protein * 4 + fat * 9 > cal) {
      final room = cal - protein * 4;
      fat = room > 0 ? (room / 9).floor() : 0;
    }

    final carbs =
    ((cal - protein * 4 - fat * 9) / 4).round().clamp(0, 1000);
    return (protein: protein, carbs: carbs, fat: fat);
  }

  /// Peso de referencia para el cálculo de proteína.
  /// Con IMC > 30 usa el peso ajustado (peso ideal + 25 % del exceso);
  /// con IMC normal usa el peso total.
  static double _proteinReferenceWeight({
    required double weightKg,
    double heightCm = 0,
  }) {
    if (heightCm <= 0 || weightKg <= 0) return weightKg;
    final m = heightCm / 100;
    final bmi = weightKg / (m * m);
    if (bmi <= 30) return weightKg;
    final ideal = 25 * m * m;
    return ideal + 0.25 * (weightKg - ideal);
  }

  /// ~35 ml por kg de peso corporal (guía habitual de hidratación).
  static int calculateWaterMl({required double weightKg}) {
    if (weightKg <= 0) return 2000;
    return (weightKg * 35).round().clamp(1500, 5000);
  }

  /// Vasos de 250 ml.
  static int waterGlassesFromMl(int ml) =>
      (ml / 250).round().clamp(6, 20);


  /// Nivel de actividad según entrenos completados en los últimos 7 días.
  static String activityFromWeeklyWorkouts(int sessionsLast7Days) {
    if (sessionsLast7Days <= 0) return 'Sedentario';
    if (sessionsLast7Days <= 2) return 'Ligero';
    if (sessionsLast7Days <= 4) return 'Moderado';
    if (sessionsLast7Days <= 5) return 'Activo';
    return 'Muy activo';
  }

  /// Nivel de actividad sugerido por los entrenos de la semana, sin bajar el
  /// que eligió el usuario: solo sube si entrena más de lo que declaró, para no
  /// recortarle calorías por no registrar sesiones.
  String refinedActivityLevel(int sessionsLast7Days) {
    final suggested = activityFromWeeklyWorkouts(sessionsLast7Days);
    return _activityRank(suggested) > _activityRank(activityLevel)
        ? suggested
        : activityLevel;
  }

  static int _activityRank(String level) => switch (level) {
    'Ligero' => 1,
    'Moderado' => 2,
    'Activo' => 3,
    'Muy activo' || 'Experto' => 4,
    _ => 0,
  };

  /// Cambios de username en los últimos 30 días.
  int usernameChangesLast30Days({DateTime? now}) {
    final n = now ?? DateTime.now();
    final cutoff = n.subtract(const Duration(days: 30));
    var count = 0;
    for (final s in usernameChangeDates) {
      final d = DateTime.tryParse(s);
      if (d != null && !d.isBefore(cutoff)) count++;
    }
    return count;
  }

  bool get canChangeUsername => usernameChangesLast30Days() < 3;

  /// Metas efectivas de calorías y macros: usa lo guardado y recalcula lo que
  /// falte (p. ej. cuentas sin macros), para que todas las pantallas muestren
  /// los mismos objetivos.
  ({int calories, int protein, int carbs, int fat}) get effectiveTargets {
    final cal = targetCalories > 0 ? targetCalories : 2000;
    if (targetProtein > 0 && targetCarbs > 0 && targetFat > 0) {
      return (
        calories: cal,
        protein: targetProtein,
        carbs: targetCarbs,
        fat: targetFat,
      );
    }
    final m = calculateMacros(
      weight: currentWeight,
      height: height,
      calories: cal,
      goal: goal,
    );
    return (
      calories: cal,
      protein: targetProtein > 0 ? targetProtein : m.protein,
      carbs: targetCarbs > 0 ? targetCarbs : m.carbs,
      fat: targetFat > 0 ? targetFat : m.fat,
    );
  }

  int get targetWaterGlasses {
    final ml = targetWaterMl > 0
        ? targetWaterMl
        : calculateWaterMl(weightKg: currentWeight);
    return UserProfile.waterGlassesFromMl(ml);
  }

  static String waterLabel(double weightKg) {
    final ml = calculateWaterMl(weightKg: weightKg);
    final glasses = waterGlassesFromMl(ml);
    return '$ml ml/día (~$glasses vasos de 250 ml)';
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

