import 'package:balancore/core/food/open_food_facts_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OffProduct.parseProduct — unidades', () {
    test('detecta líquido cuando serving_quantity_unit es ml', () {
      final p = OpenFoodFactsService.parseProduct({
        'code': '123',
        'product_name': 'Jugo de naranja',
        'nutriments': {
          'energy-kcal_100g': 45,
          'proteins_100g': 0.7,
          'carbohydrates_100g': 10,
          'fat_100g': 0.2,
        },
        'serving_quantity': 200,
        'serving_quantity_unit': 'ml',
      });

      expect(p, isNotNull);
      expect(p!.isLiquid, isTrue);
      expect(p.baseUnit, 'ml');
      expect(p.servingGrams, 200);
    });

    test('producto sólido con porción en g', () {
      final p = OpenFoodFactsService.parseProduct({
        'code': '124',
        'product_name': 'Galletas',
        'nutriments': {'energy-kcal_100g': 480, 'fat_100g': 20},
        'serving_quantity': '30',
        'serving_quantity_unit': 'g',
      });

      expect(p, isNotNull);
      expect(p!.isLiquid, isFalse);
      expect(p.baseUnit, 'g');
      expect(p.servingGrams, 30);
    });

    test('deduce ml desde serving_size si falta la unidad', () {
      final p = OpenFoodFactsService.parseProduct({
        'code': '125',
        'product_name': 'Leche',
        'nutriments': {'energy-kcal_100g': 60},
        'serving_quantity': 250,
        'serving_size': '250 ml',
      });

      expect(p!.isLiquid, isTrue);
      expect(p.baseUnit, 'ml');
    });

    test('sin unidad ni pista queda en gramos', () {
      final p = OpenFoodFactsService.parseProduct({
        'code': '126',
        'product_name': 'Pan',
        'nutriments': {'energy-kcal_100g': 250},
        'serving_quantity': 50,
      });

      expect(p!.isLiquid, isFalse);
      expect(p.servingUnit, isNull);
      expect(p.baseUnit, 'g');
    });

    test('convierte kJ a kcal cuando falta energy-kcal', () {
      final p = OpenFoodFactsService.parseProduct({
        'code': '127',
        'product_name': 'Producto',
        'nutriments': {'energy_100g': 418.4, 'proteins_100g': 1},
      });

      expect(p!.caloriesPer100g, closeTo(100, 0.5));
    });

    test('devuelve null sin nutrientes ni nombre utilizable', () {
      expect(
        OpenFoodFactsService.parseProduct({'code': 'x', 'product_name': ''}),
        isNull,
      );
      expect(
        OpenFoodFactsService.parseProduct({
          'product_name': 'Vacío',
          'nutriments': <String, dynamic>{},
        }),
        isNull,
      );
    });
  });

  group('OffProduct.forGrams', () {
    const p = OffProduct(
      barcode: '1',
      name: 'Test',
      caloriesPer100g: 200,
      proteinPer100g: 10,
      carbsPer100g: 20,
      fatPer100g: 5,
    );

    test('escala linealmente desde 100 g', () {
      final r = p.forGrams(250);
      expect(r.kcal, 500);
      expect(r.protein, 25);
      expect(r.carbs, 50);
      expect(r.fat, 13); // 12.5 → 13 (redondeo)
    });

    test('mitad de porción redondea bien', () {
      final r = p.forGrams(50);
      expect(r.kcal, 100);
      expect(r.protein, 5);
    });
  });
}
