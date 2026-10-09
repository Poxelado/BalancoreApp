/// Alimentos genéricos (feria, mercado, casa) — valores por 100 g.
/// Útil cuando Open Food Facts solo trae productos envasados.
class CommonFood {
  final String name;
  final String category; // Frutas | Verduras | Proteínas | Cereales | Lácteos | Otros
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  /// Peso típico de 1 unidad (huevo, manzana…); null = solo g/ml.
  final double? unitGrams;
  final String defaultUnit; // g | ml | ud

  const CommonFood({
    required this.name,
    required this.category,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.unitGrams,
    this.defaultUnit = 'g',
  });

  ({int kcal, int protein, int carbs, int fat}) forGrams(double grams) {
    final f = grams / 100.0;
    return (
    kcal: (kcalPer100g * f).round(),
    protein: (proteinPer100g * f).round(),
    carbs: (carbsPer100g * f).round(),
    fat: (fatPer100g * f).round(),
    );
  }
}

/// Catálogo offline orientado a Chile / feria / cocina diaria.
const kCommonFoods = <CommonFood>[
  // ── Frutas ──
  CommonFood(name: 'Manzana', category: 'Frutas', kcalPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14, fatPer100g: 0.2, unitGrams: 180),
  CommonFood(name: 'Plátano / banana', category: 'Frutas', kcalPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, unitGrams: 120),
  CommonFood(name: 'Naranja', category: 'Frutas', kcalPer100g: 47, proteinPer100g: 0.9, carbsPer100g: 12, fatPer100g: 0.1, unitGrams: 150),
  CommonFood(name: 'Mandarina', category: 'Frutas', kcalPer100g: 53, proteinPer100g: 0.8, carbsPer100g: 13, fatPer100g: 0.3, unitGrams: 90),
  CommonFood(name: 'Pera', category: 'Frutas', kcalPer100g: 57, proteinPer100g: 0.4, carbsPer100g: 15, fatPer100g: 0.1, unitGrams: 170),
  CommonFood(name: 'Durazno', category: 'Frutas', kcalPer100g: 39, proteinPer100g: 0.9, carbsPer100g: 10, fatPer100g: 0.3, unitGrams: 150),
  CommonFood(name: 'Frutilla', category: 'Frutas', kcalPer100g: 32, proteinPer100g: 0.7, carbsPer100g: 8, fatPer100g: 0.3),
  CommonFood(name: 'Uva', category: 'Frutas', kcalPer100g: 69, proteinPer100g: 0.7, carbsPer100g: 18, fatPer100g: 0.2),
  CommonFood(name: 'Sandía', category: 'Frutas', kcalPer100g: 30, proteinPer100g: 0.6, carbsPer100g: 8, fatPer100g: 0.2),
  CommonFood(name: 'Melón', category: 'Frutas', kcalPer100g: 34, proteinPer100g: 0.8, carbsPer100g: 8, fatPer100g: 0.2),
  CommonFood(name: 'Kiwi', category: 'Frutas', kcalPer100g: 61, proteinPer100g: 1.1, carbsPer100g: 15, fatPer100g: 0.5, unitGrams: 75),
  CommonFood(name: 'Palta', category: 'Frutas', kcalPer100g: 160, proteinPer100g: 2, carbsPer100g: 9, fatPer100g: 15, unitGrams: 200),
  CommonFood(name: 'Limón', category: 'Frutas', kcalPer100g: 29, proteinPer100g: 1.1, carbsPer100g: 9, fatPer100g: 0.3, unitGrams: 60),
  CommonFood(name: 'Mango', category: 'Frutas', kcalPer100g: 60, proteinPer100g: 0.8, carbsPer100g: 15, fatPer100g: 0.4),
  CommonFood(name: 'Piña', category: 'Frutas', kcalPer100g: 50, proteinPer100g: 0.5, carbsPer100g: 13, fatPer100g: 0.1),

  // ── Verduras ──
  CommonFood(name: 'Tomate', category: 'Verduras', kcalPer100g: 18, proteinPer100g: 0.9, carbsPer100g: 3.9, fatPer100g: 0.2, unitGrams: 120),
  CommonFood(name: 'Lechuga', category: 'Verduras', kcalPer100g: 15, proteinPer100g: 1.4, carbsPer100g: 2.9, fatPer100g: 0.2),
  CommonFood(name: 'Zanahoria', category: 'Verduras', kcalPer100g: 41, proteinPer100g: 0.9, carbsPer100g: 10, fatPer100g: 0.2, unitGrams: 60),
  CommonFood(name: 'Cebolla', category: 'Verduras', kcalPer100g: 40, proteinPer100g: 1.1, carbsPer100g: 9, fatPer100g: 0.1),
  CommonFood(name: 'Papa', category: 'Verduras', kcalPer100g: 77, proteinPer100g: 2, carbsPer100g: 17, fatPer100g: 0.1),
  CommonFood(name: 'Camote', category: 'Verduras', kcalPer100g: 86, proteinPer100g: 1.6, carbsPer100g: 20, fatPer100g: 0.1),
  CommonFood(name: 'Brócoli', category: 'Verduras', kcalPer100g: 34, proteinPer100g: 2.8, carbsPer100g: 7, fatPer100g: 0.4),
  CommonFood(name: 'Zapallo / calabaza', category: 'Verduras', kcalPer100g: 26, proteinPer100g: 1, carbsPer100g: 7, fatPer100g: 0.1),
  CommonFood(name: 'Pepino', category: 'Verduras', kcalPer100g: 16, proteinPer100g: 0.7, carbsPer100g: 3.6, fatPer100g: 0.1),
  CommonFood(name: 'Pimentón', category: 'Verduras', kcalPer100g: 31, proteinPer100g: 1, carbsPer100g: 6, fatPer100g: 0.3),
  CommonFood(name: 'Espinaca', category: 'Verduras', kcalPer100g: 23, proteinPer100g: 2.9, carbsPer100g: 3.6, fatPer100g: 0.4),
  CommonFood(name: 'Repollo', category: 'Verduras', kcalPer100g: 25, proteinPer100g: 1.3, carbsPer100g: 6, fatPer100g: 0.1),
  CommonFood(name: 'Betarraga', category: 'Verduras', kcalPer100g: 43, proteinPer100g: 1.6, carbsPer100g: 10, fatPer100g: 0.2),
  CommonFood(name: 'Choclo (grano)', category: 'Verduras', kcalPer100g: 86, proteinPer100g: 3.3, carbsPer100g: 19, fatPer100g: 1.2),
  CommonFood(name: 'Champiñón', category: 'Verduras', kcalPer100g: 22, proteinPer100g: 3.1, carbsPer100g: 3.3, fatPer100g: 0.3),

  // ── Proteínas ──
  CommonFood(name: 'Huevo entero', category: 'Proteínas', kcalPer100g: 143, proteinPer100g: 13, carbsPer100g: 0.7, fatPer100g: 10, unitGrams: 50, defaultUnit: 'ud'),
  CommonFood(name: 'Clara de huevo', category: 'Proteínas', kcalPer100g: 52, proteinPer100g: 11, carbsPer100g: 0.7, fatPer100g: 0.2),
  CommonFood(name: 'Pollo pechuga (crudo)', category: 'Proteínas', kcalPer100g: 110, proteinPer100g: 23, carbsPer100g: 0, fatPer100g: 1.2),
  CommonFood(name: 'Pollo muslo (crudo)', category: 'Proteínas', kcalPer100g: 144, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 7),
  CommonFood(name: 'Carne vacuno magra', category: 'Proteínas', kcalPer100g: 140, proteinPer100g: 21, carbsPer100g: 0, fatPer100g: 6),
  CommonFood(name: 'Carne molida 90/10', category: 'Proteínas', kcalPer100g: 176, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 10),
  CommonFood(name: 'Cerdo lomo', category: 'Proteínas', kcalPer100g: 143, proteinPer100g: 21, carbsPer100g: 0, fatPer100g: 6),
  CommonFood(name: 'Salmón', category: 'Proteínas', kcalPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13),
  CommonFood(name: 'Merluza', category: 'Proteínas', kcalPer100g: 86, proteinPer100g: 18, carbsPer100g: 0, fatPer100g: 1.2),
  CommonFood(name: 'Atún en agua (escurrido)', category: 'Proteínas', kcalPer100g: 86, proteinPer100g: 19, carbsPer100g: 0, fatPer100g: 1),
  CommonFood(name: 'Lentejas cocidas', category: 'Proteínas', kcalPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0.4),
  CommonFood(name: 'Porotos cocidos', category: 'Proteínas', kcalPer100g: 127, proteinPer100g: 9, carbsPer100g: 23, fatPer100g: 0.5),
  CommonFood(name: 'Garbanzos cocidos', category: 'Proteínas', kcalPer100g: 164, proteinPer100g: 9, carbsPer100g: 27, fatPer100g: 2.6),
  CommonFood(name: 'Tofu firme', category: 'Proteínas', kcalPer100g: 144, proteinPer100g: 17, carbsPer100g: 3, fatPer100g: 9),

  // ── Cereales ──
  CommonFood(name: 'Arroz cocido', category: 'Cereales', kcalPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3),
  CommonFood(name: 'Arroz crudo', category: 'Cereales', kcalPer100g: 360, proteinPer100g: 7, carbsPer100g: 79, fatPer100g: 0.6),
  CommonFood(name: 'Fideos cocidos', category: 'Cereales', kcalPer100g: 131, proteinPer100g: 5, carbsPer100g: 25, fatPer100g: 1.1),
  CommonFood(name: 'Avena (copos)', category: 'Cereales', kcalPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7),
  CommonFood(name: 'Pan marraqueta', category: 'Cereales', kcalPer100g: 270, proteinPer100g: 9, carbsPer100g: 52, fatPer100g: 2.5, unitGrams: 80, defaultUnit: 'ud'),
  CommonFood(name: 'Pan hallulla', category: 'Cereales', kcalPer100g: 280, proteinPer100g: 8, carbsPer100g: 50, fatPer100g: 5, unitGrams: 70, defaultUnit: 'ud'),
  CommonFood(name: 'Quinoa cocida', category: 'Cereales', kcalPer100g: 120, proteinPer100g: 4.4, carbsPer100g: 21, fatPer100g: 1.9),

  // ── Lácteos / líquidos ──
  CommonFood(name: 'Leche entera', category: 'Lácteos', kcalPer100g: 61, proteinPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 3.3, defaultUnit: 'ml'),
  CommonFood(name: 'Leche descremada', category: 'Lácteos', kcalPer100g: 34, proteinPer100g: 3.4, carbsPer100g: 5, fatPer100g: 0.1, defaultUnit: 'ml'),
  CommonFood(name: 'Yogur natural', category: 'Lácteos', kcalPer100g: 61, proteinPer100g: 3.5, carbsPer100g: 4.7, fatPer100g: 3.3),
  CommonFood(name: 'Queso gauda', category: 'Lácteos', kcalPer100g: 356, proteinPer100g: 25, carbsPer100g: 2, fatPer100g: 28),
  CommonFood(name: 'Queso crema', category: 'Lácteos', kcalPer100g: 342, proteinPer100g: 6, carbsPer100g: 4, fatPer100g: 34),

  // ── Otros ──
  CommonFood(name: 'Aceite de oliva', category: 'Otros', kcalPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, defaultUnit: 'ml'),
  CommonFood(name: 'Aceite vegetal', category: 'Otros', kcalPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100, defaultUnit: 'ml'),
  CommonFood(name: 'Mantequilla', category: 'Otros', kcalPer100g: 717, proteinPer100g: 0.9, carbsPer100g: 0.1, fatPer100g: 81),
  CommonFood(name: 'Azúcar', category: 'Otros', kcalPer100g: 387, proteinPer100g: 0, carbsPer100g: 100, fatPer100g: 0),
  CommonFood(name: 'Miel', category: 'Otros', kcalPer100g: 304, proteinPer100g: 0.3, carbsPer100g: 82, fatPer100g: 0),
  CommonFood(name: 'Maní', category: 'Otros', kcalPer100g: 567, proteinPer100g: 26, carbsPer100g: 16, fatPer100g: 49),
  CommonFood(name: 'Nueces', category: 'Otros', kcalPer100g: 654, proteinPer100g: 15, carbsPer100g: 14, fatPer100g: 65),
  CommonFood(name: 'Almendras', category: 'Otros', kcalPer100g: 579, proteinPer100g: 21, carbsPer100g: 22, fatPer100g: 50),
];

List<CommonFood> searchCommonFoods(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return List.of(kCommonFoods);
  return kCommonFoods
      .where((f) =>
  f.name.toLowerCase().contains(q) ||
      f.category.toLowerCase().contains(q))
      .toList();
}

List<String> get commonFoodCategories {
  final set = <String>{};
  for (final f in kCommonFoods) {
    set.add(f.category);
  }
  return set.toList();
}
