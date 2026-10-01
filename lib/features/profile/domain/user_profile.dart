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
      'onboardingCompleted': onboardingCompleted,
      'createdAt':
      createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      username: map['username'],
      bio: map['bio'],
      email: map['email'],
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      sex: map['sex'] ?? map['gender'] ?? 'Masculino',
      currentWeight: (map['currentWeight'] as num?)?.toDouble() ??
          (map['weight'] as num?)?.toDouble() ??
          65,
      height: (map['height'] as num?)?.toDouble() ?? 170,
      age: map['age'] ?? 25,
      activityLevel: map['activityLevel'] ?? 'Sedentario',
      goal: map['goal'] ?? 'Mantenimiento',
      targetCalories: map['targetCalories'] ?? 2000,
      targetProtein: map['targetProtein'] ?? 0,
      targetCarbs: map['targetCarbs'] ?? 0,
      targetFat: map['targetFat'] ?? 0,
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
    required int calories,
    required String goal,
  }) {
    final proteinPerKg = switch (goal) {
      'Perder grasa' => 2.2,
      'Ganar músculo' => 2.0,
      _ => 1.8,
    };
    final protein = (weight * proteinPerKg).round();
    final fatPct = goal == 'Perder grasa' ? 0.25 : 0.28;
    final fat = ((calories * fatPct) / 9).round();
    final proteinKcal = protein * 4;
    final fatKcal = fat * 9;
    final carbs =
    ((calories - proteinKcal - fatKcal) / 4).round().clamp(0, 1000);
    return (protein: protein, carbs: carbs, fat: fat);
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
      weight: (map['weight'] as num).toDouble(),
      date: DateTime.parse(map['date']),
    );
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

  RoutineDay({
    required this.day,
    required this.title,
    this.duration = '',
    this.calories = 0,
    this.isRestDay = false,
    this.description,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() => {
    'day': day,
    'title': title,
    'duration': duration,
    'calories': calories,
    'isRestDay': isRestDay,
    'description': description,
    'imageUrl': imageUrl,
  };

  factory RoutineDay.fromMap(Map<String, dynamic> map) {
    return RoutineDay(
      day: map['day'] ?? '',
      title: map['title'] ?? '',
      duration: map['duration'] ?? '',
      calories: map['calories'] ?? 0,
      isRestDay: map['isRestDay'] ?? false,
      description: map['description'],
      imageUrl: map['imageUrl'],
    );
  }
}

class MealEntry {
  final String id;
  final String name;
  final String mealType; // Desayuno | Almuerzo | Cena | Snack
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final String createdAt;

  MealEntry({
    required this.id,
    required this.name,
    required this.mealType,
    required this.calories,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  static const mealTypes = ['Desayuno', 'Almuerzo', 'Cena', 'Snack'];

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'mealType': mealType,
    'calories': calories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    'createdAt': createdAt,
  };

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    return MealEntry(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      mealType: map['mealType'] ?? 'Snack',
      calories: map['calories'] ?? 0,
      proteinGrams: map['proteinGrams'] ?? 0,
      carbsGrams: map['carbsGrams'] ?? 0,
      fatGrams: map['fatGrams'] ?? 0,
      createdAt: map['createdAt']?.toString(),
    );
  }
}

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
        date: map['date'] ?? '',
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
      date: map['date'] ?? '',
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
