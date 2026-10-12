part of 'user_profile.dart';

class SavedFood {
  final String id;
  final String name;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int? portionGrams; // gramos de la porción guardada
  final String? servingLabel; // ej. "100 g", "200 ml", "1 ud"
  final String? defaultMealType;
  final int useCount;
  final String? updatedAt;

  SavedFood({
    required this.id,
    required this.name,
    required this.calories,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.portionGrams,
    this.servingLabel,
    this.defaultMealType,
    this.useCount = 0,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'calories': calories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    if (portionGrams != null) 'portionGrams': portionGrams,
    if (servingLabel != null) 'servingLabel': servingLabel,
    'defaultMealType': defaultMealType,
    'useCount': useCount,
    'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
  };

  factory SavedFood.fromMap(String id, Map<String, dynamic> map) {
    return SavedFood(
      id: id,
      name: _str(map['name']),
      calories: map['calories'] ?? 0,
      proteinGrams: map['proteinGrams'] ?? 0,
      carbsGrams: map['carbsGrams'] ?? 0,
      fatGrams: map['fatGrams'] ?? 0,
      portionGrams: map['portionGrams'] is int
          ? map['portionGrams'] as int
          : int.tryParse('${map['portionGrams'] ?? ''}'),
      servingLabel: map['servingLabel']?.toString(),
      defaultMealType: map['defaultMealType'],
      useCount: map['useCount'] ?? 0,
      updatedAt: map['updatedAt']?.toString(),
    );
  }

  MealEntry toMeal({required String mealType, String? mealId}) {
    return MealEntry(
      id: mealId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      mealType: mealType,
      calories: calories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      grams: portionGrams,
      servingLabel: servingLabel,
    );
  }
}


/// Ingrediente de una receta / plato.
class RecipeIngredient {
  final String name;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int? grams;
  final String? servingLabel;

  const RecipeIngredient({
    required this.name,
    required this.calories,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.grams,
    this.servingLabel,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'calories': calories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    if (grams != null) 'grams': grams,
    if (servingLabel != null) 'servingLabel': servingLabel,
  };

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      name: _str(map['name']),
      calories: map['calories'] ?? 0,
      proteinGrams: map['proteinGrams'] ?? 0,
      carbsGrams: map['carbsGrams'] ?? 0,
      fatGrams: map['fatGrams'] ?? 0,
      grams: map['grams'] is int
          ? map['grams'] as int
          : int.tryParse('${map['grams'] ?? ''}'),
      servingLabel: map['servingLabel']?.toString(),
    );
  }

  RecipeIngredient scaled(double factor) {
    return RecipeIngredient(
      name: name,
      calories: (calories * factor).round(),
      proteinGrams: (proteinGrams * factor).round(),
      carbsGrams: (carbsGrams * factor).round(),
      fatGrams: (fatGrams * factor).round(),
      grams: grams != null ? (grams! * factor).round() : null,
      servingLabel: servingLabel,
    );
  }
}

/// Plato / receta guardada (como una "sesión" de comida).
class SavedRecipe {
  final String id;
  final String name;
  final List<RecipeIngredient> ingredients;
  final int useCount;
  final String? updatedAt;

  const SavedRecipe({
    required this.id,
    required this.name,
    this.ingredients = const [],
    this.useCount = 0,
    this.updatedAt,
  });

  int get totalCalories =>
      ingredients.fold(0, (s, i) => s + i.calories);
  int get totalProtein =>
      ingredients.fold(0, (s, i) => s + i.proteinGrams);
  int get totalCarbs =>
      ingredients.fold(0, (s, i) => s + i.carbsGrams);
  int get totalFat =>
      ingredients.fold(0, (s, i) => s + i.fatGrams);

  Map<String, dynamic> toMap() => {
    'name': name,
    'ingredients': ingredients.map((i) => i.toMap()).toList(),
    'useCount': useCount,
    'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
  };

  factory SavedRecipe.fromMap(String id, Map<String, dynamic> map) {
    final raw = map['ingredients'];
    final list = <RecipeIngredient>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add(RecipeIngredient.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    return SavedRecipe(
      id: id,
      name: _str(map['name']),
      ingredients: list,
      useCount: map['useCount'] ?? 0,
      updatedAt: map['updatedAt']?.toString(),
    );
  }

  /// Convierte el plato en una entrada de comida del día (con escala).
  MealEntry toMealEntry({
    required String mealType,
    double scale = 1.0,
    String? mealId,
  }) {
    final factor = scale <= 0 ? 1.0 : scale;
    final scaled = ingredients.map((i) => i.scaled(factor)).toList();
    final scaleLabel = factor == 1.0
        ? null
        : factor == 0.5
        ? '½ porción'
        : factor == 2.0
        ? '2 porciones'
        : '${factor}x';
    return MealEntry(
      id: mealId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: scaleLabel == null ? name : '$name ($scaleLabel)',
      mealType: mealType,
      calories: scaled.fold(0, (s, i) => s + i.calories),
      proteinGrams: scaled.fold(0, (s, i) => s + i.proteinGrams),
      carbsGrams: scaled.fold(0, (s, i) => s + i.carbsGrams),
      fatGrams: scaled.fold(0, (s, i) => s + i.fatGrams),
      recipeId: id.isEmpty ? null : id,
      scale: factor,
      ingredients: scaled,
      servingLabel: scaleLabel ?? '${ingredients.length} ingredientes',
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
  final int? grams; // porción en g (o ml≈g)
  final String? servingLabel; // ej. "155 ml", "1 ud"
  final String? recipeId; // si viene de un plato
  final double scale; // 1.0 = porción completa
  final List<RecipeIngredient> ingredients; // snapshot al registrar
  final String createdAt;

  MealEntry({
    required this.id,
    required this.name,
    required this.mealType,
    required this.calories,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.grams,
    this.servingLabel,
    this.recipeId,
    this.scale = 1.0,
    this.ingredients = const [],
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  bool get isRecipe => recipeId != null || ingredients.isNotEmpty;

  static const mealTypes = ['Desayuno', 'Almuerzo', 'Cena', 'Snack'];

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'mealType': mealType,
    'calories': calories,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    if (grams != null) 'grams': grams,
    if (servingLabel != null) 'servingLabel': servingLabel,
    if (recipeId != null) 'recipeId': recipeId,
    if (scale != 1.0) 'scale': scale,
    if (ingredients.isNotEmpty)
      'ingredients': ingredients.map((i) => i.toMap()).toList(),
    'createdAt': createdAt,
  };

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    final raw = map['ingredients'];
    final list = <RecipeIngredient>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add(RecipeIngredient.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    return MealEntry(
      id: _str(map['id']),
      name: _str(map['name']),
      mealType: _str(map['mealType'], 'Snack'),
      calories: map['calories'] ?? 0,
      proteinGrams: map['proteinGrams'] ?? 0,
      carbsGrams: map['carbsGrams'] ?? 0,
      grams: map['grams'] is int
          ? map['grams'] as int
          : int.tryParse('${map['grams'] ?? ''}'),
      servingLabel: map['servingLabel']?.toString(),
      recipeId: map['recipeId']?.toString(),
      scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
      ingredients: list,
      fatGrams: map['fatGrams'] ?? 0,
      createdAt: _str(map['createdAt'], DateTime.now().toIso8601String()),
    );
  }
}

