class UserProfile {
  final String uid;
  final String? email;
  final String gender;
  final double weight; // kg
  final double height; // cm
  final int age;
  final String activityLevel;
  final int targetCalories;
  final bool onboardingCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.uid,
    this.email,
    required this.gender,
    required this.weight,
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
      'email': email,
      'gender': gender,
      'weight': weight,
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
      email: map['email'],
      gender: map['gender'] ?? 'Masculino',
      weight: (map['weight'] as num?)?.toDouble() ?? 65,
      height: (map['height'] as num?)?.toDouble() ?? 170,
      age: map['age'] ?? 25,
      activityLevel: map['activityLevel'] ?? 'Sedentario',
      targetCalories: map['targetCalories'] ?? 2000,
      onboardingCompleted: map['onboardingCompleted'] ?? false,
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt']) : null,
    );
  }

  /// Fórmula Mifflin-St Jeor
  static int calculateTMB({
    required String gender,
    required double weight,
    required double height,
    required int age,
    required String activityLevel,
  }) {
    double tmb;
    if (gender == 'Masculino') {
      tmb = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      tmb = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    double multiplier = switch (activityLevel) {
      'Moderado' => 1.55,
      'Experto' => 1.9,
      _ => 1.2, // Sedentario
    };

    return (tmb * multiplier).round();
  }
}