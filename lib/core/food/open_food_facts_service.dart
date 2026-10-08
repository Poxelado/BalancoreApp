import 'dart:convert';
import 'package:http/http.dart' as http;

/// Producto normalizado desde Open Food Facts (por 100 g).
class OffProduct {
  final String barcode;
  final String name;
  final String? brand;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final String? imageUrl;
  final double? servingGrams;

  const OffProduct({
    required this.barcode,
    required this.name,
    this.brand,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.imageUrl,
    this.servingGrams,
  });

  ({int kcal, int protein, int carbs, int fat}) forGrams(double grams) {
    final f = grams / 100.0;
    return (
    kcal: (caloriesPer100g * f).round(),
    protein: (proteinPer100g * f).round(),
    carbs: (carbsPer100g * f).round(),
    fat: (fatPer100g * f).round(),
    );
  }

  String get displayName {
    if (brand != null && brand!.isNotEmpty) {
      return '$name ($brand)';
    }
    return name;
  }
}

class OpenFoodFactsService {
  OpenFoodFactsService._();
  static final instance = OpenFoodFactsService._();

  static const _userAgent = 'Balancore/1.0 (Flutter; Android; thesis)';
  static const _timeout = Duration(seconds: 15);

  /// Hosts alternativos: world a veces responde 503.
  static const _hosts = [
    'world.openfoodfacts.org',
    'world.openfoodfacts.net',
  ];

  Future<http.Response> _get(Uri Function(String host) build) async {
    Object? lastError;
    for (final host in _hosts) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final res = await http
              .get(
            build(host),
            headers: {
              'User-Agent': _userAgent,
              'Accept': 'application/json',
            },
          )
              .timeout(_timeout);
          // 503/502 = reintentar o siguiente host
          if (res.statusCode == 503 || res.statusCode == 502) {
            lastError = 'Open Food Facts no disponible (${res.statusCode})';
            await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
            continue;
          }
          return res;
        } catch (e) {
          lastError = e;
          await Future<void>.delayed(Duration(milliseconds: 300 * (attempt + 1)));
        }
      }
    }
    throw lastError ?? 'Open Food Facts: sin respuesta';
  }

  Future<List<OffProduct>> search(String query, {int pageSize = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    final res = await _get(
          (host) => Uri.https(host, '/cgi/search.pl', {
        'search_terms': q,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '$pageSize',
        'fields':
        'code,product_name,brands,nutriments,image_front_small_url,serving_quantity',
      }),
    );

    if (res.statusCode != 200) {
      throw 'Open Food Facts temporalmente no disponible '
          '(código ${res.statusCode}). Intenta de nuevo en unos segundos.';
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final products = data['products'] as List? ?? [];
    final out = <OffProduct>[];
    for (final raw in products) {
      if (raw is! Map) continue;
      final p = _fromMap(Map<String, dynamic>.from(raw));
      if (p != null) out.add(p);
    }
    return out;
  }

  Future<OffProduct?> byBarcode(String barcode) async {
    final code = barcode.trim().replaceAll(RegExp(r'\s'), '');
    if (code.isEmpty) return null;

    final res = await _get(
          (host) => Uri.https(host, '/api/v2/product/$code.json', {
        'fields':
        'code,product_name,brands,nutriments,image_front_small_url,serving_quantity',
      }),
    );

    if (res.statusCode != 200) {
      throw 'Open Food Facts temporalmente no disponible '
          '(código ${res.statusCode}). Intenta de nuevo.';
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['status'] != 1) return null;
    final product = data['product'];
    if (product is! Map) return null;
    return _fromMap(Map<String, dynamic>.from(product));
  }

  OffProduct? _fromMap(Map<String, dynamic> m) {
    final name = (m['product_name'] ?? m['product_name_en'] ?? '')
        .toString()
        .trim();
    if (name.isEmpty) return null;

    final nutriments = m['nutriments'];
    final n = nutriments is Map
        ? Map<String, dynamic>.from(nutriments)
        : <String, dynamic>{};

    double numVal(List<String> keys) {
      for (final k in keys) {
        final v = n[k];
        if (v is num) return v.toDouble();
        if (v is String) {
          final p = double.tryParse(v.replaceAll(',', '.'));
          if (p != null) return p;
        }
      }
      return 0;
    }

    var kcal = numVal([
      'energy-kcal_100g',
      'energy-kcal',
      'energy-kcal_value',
    ]);
    if (kcal <= 0) {
      final kj = numVal(['energy-kj_100g', 'energy_100g', 'energy']);
      if (kj > 0) kcal = kj / 4.184;
    }

    final protein = numVal(['proteins_100g', 'proteins']);
    final carbs = numVal(['carbohydrates_100g', 'carbohydrates']);
    final fat = numVal(['fat_100g', 'fat']);
    if (kcal <= 0 && protein <= 0 && carbs <= 0 && fat <= 0) return null;

    double? serving;
    final sq = m['serving_quantity'];
    if (sq is num) {
      serving = sq.toDouble();
    } else if (sq is String) {
      serving = double.tryParse(sq.replaceAll(',', '.'));
    }

    final brand = (m['brands'] ?? '').toString().trim();
    final img = (m['image_front_small_url'] ?? '').toString();

    return OffProduct(
      barcode: (m['code'] ?? '').toString(),
      name: name,
      brand: brand.isEmpty ? null : brand,
      caloriesPer100g: kcal,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      imageUrl: img.isEmpty ? null : img,
      servingGrams: serving != null && serving > 0 ? serving : null,
    );
  }
}
