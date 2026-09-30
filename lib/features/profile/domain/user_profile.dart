class UserProfile {
  final String uid;
  final String? email;
  final String? displayName;
  final String? username;  // sin el @, ej: "mrextremista"
  final String? bio;
  final String? photoUrl;
  final String sex; // "Masculino" | "Femenino"
  final double currentWeight; // kg
  final double height; // cm
  final int age;
  final String activityLevel;
  final int targetCalories;
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
    required this.targetCalories,
    this.onboardingCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

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
      'targetCalories': targetCalories,
      'onboardingCompleted': onboardingCompleted,
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
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
      targetCalories: map['targetCalories'] ?? 2000,
      onboardingCompleted: map['onboardingCompleted'] ?? false,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
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
    int? targetCalories,
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
      targetCalories: targetCalories ?? this.targetCalories,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static int calculateTMB({
    required String sex,
    required double weight,
    required double height,
    required int age,
    required String activityLevel,
  }) {
    double tmb = sex == 'Masculino'
        ? (10 * weight) + (6.25 * height) - (5 * age) + 5
        : (10 * weight) + (6.25 * height) - (5 * age) - 161;

    double multiplier = switch (activityLevel) {
      'Moderado' => 1.55,
      'Experto' => 1.9,
      _ => 1.2,
    };

    return (tmb * multiplier).round();
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
  final String day; // lunes, martes, ...
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

class DailyLog {
  final String date; // yyyy-MM-dd
  final int waterGlasses;
  final double sleepHours;
  final int consumedCalories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;

  DailyLog({
    required this.date,
    this.waterGlasses = 0,
    this.sleepHours = 0,
    this.consumedCalories = 0,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
  });

  Map<String, dynamic> toMap() => {
    'date': date,
    'waterGlasses': waterGlasses,
    'sleepHours': sleepHours,
    'consumedCalories': consumedCalories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
  };

  factory DailyLog.fromMap(Map<String, dynamic> map) {
    return DailyLog(
      date: map['date'] ?? '',
      waterGlasses: map['waterGlasses'] ?? 0,
      sleepHours: (map['sleepHours'] as num?)?.toDouble() ?? 0,
      consumedCalories: map['consumedCalories'] ?? 0,
      proteinGrams: map['proteinGrams'] ?? 0,
      carbsGrams: map['carbsGrams'] ?? 0,
      fatGrams: map['fatGrams'] ?? 0,
    );
  }
}