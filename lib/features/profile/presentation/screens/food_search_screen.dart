import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/food/open_food_facts_service.dart';
import '../../../../core/food/common_foods.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../../../../core/theme/app_theme.dart';

part 'food_search_sheet.dart';

/// Resultado: comida lista para registrar (+ opcionalmente ya en savedFoods).
class FoodSearchResult {
  final String name;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  /// Gramos equivalentes (ml se tratan ≈ g para líquidos).
  final int grams;
  /// Texto legible: "155 ml", "1 ud", "100 g"
  final String servingLabel;
  final String? barcode;
  final bool saveToLibrary;

  const FoodSearchResult({
    required this.name,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.grams,
    required this.servingLabel,
    this.barcode,
    this.saveToLibrary = true,
  });
}

/// Busca en Open Food Facts + catálogo offline (feria / extras).
class FoodSearchScreen extends ConsumerStatefulWidget {
  final bool saveToLibrary;

  const FoodSearchScreen({super.key, this.saveToLibrary = true});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _extrasCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  List<OffProduct> _results = [];
  List<CommonFood> _extras = List.of(kCommonFoods);
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _barcodeCtrl.dispose();
    _extrasCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 2) {
      setState(() => _error = 'Escribe al menos 2 caracteres');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final list = await OpenFoodFactsService.instance.search(q);
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
        if (list.isEmpty) {
          _error =
              'Sin resultados en supermercado para “$q”. Prueba la pestaña Extras.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _runBarcode() async {
    final code = _barcodeCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Código de barras inválido');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final p = await OpenFoodFactsService.instance.byBarcode(code);
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (p == null) {
          _error = 'Producto no encontrado';
        } else {
          _results = [p];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _filterExtras() {
    var list = searchCommonFoods(_extrasCtrl.text);
    if (_categoryFilter != null) {
      list = list.where((f) => f.category == _categoryFilter).toList();
    }
    setState(() {
      _extras = list;
      _error = null;
    });
  }

  Future<void> _pickProduct(OffProduct p) async {
    final unitGrams = (p.servingGrams != null && p.servingGrams! > 0)
        ? p.servingGrams!
        : 125.0;
    final qtyCtrl = TextEditingController(text: '1');
    int unitMode = p.servingGrams != null ? 2 : 0;
    if (unitMode == 2) {
      qtyCtrl.text = '1';
    } else {
      qtyCtrl.text = (p.servingGrams ?? 100).round().toString();
    }
    bool saveLib = widget.saveToLibrary;

    final confirmed = await _quantitySheet(
      context,
      title: p.displayName,
      subtitle: p.barcode.isNotEmpty ? 'Código: ${p.barcode}' : null,
      per100:
          'Por 100 g: ${p.caloriesPer100g.round()} kcal · P ${p.proteinPer100g.round()} · C ${p.carbsPer100g.round()} · G ${p.fatPer100g.round()}',
      unitGramsHint: p.servingGrams?.round(),
      initialUnitMode: unitMode,
      initialQty: qtyCtrl.text,
      onMacros: (grams) => p.forGrams(grams),
      saveLibDefault: saveLib,
      labelFrom: (mode, qty, grams) {
        switch (mode) {
          case 1:
            return '${qty == qty.roundToDouble() ? qty.toInt() : qty} ml';
          case 2:
            final u = qty == qty.roundToDouble() ? '${qty.toInt()}' : '$qty';
            return '$u ud (${grams.round()} g)';
          default:
            return '${grams.round()} g';
        }
      },
      unitGramsForUd: unitGrams,
    );

    if (confirmed == null || !mounted) return;
    await _finishPick(confirmed);
  }

  Future<void> _pickCommon(CommonFood f) async {
    final unitGrams = f.unitGrams ?? 100;
    int unitMode = f.defaultUnit == 'ml'
        ? 1
        : (f.defaultUnit == 'ud' || f.unitGrams != null)
            ? 2
            : 0;
    final initialQty = unitMode == 2
        ? '1'
        : unitMode == 1
            ? '200'
            : '100';

    final confirmed = await _quantitySheet(
      context,
      title: f.name,
      subtitle: '${f.category} · valores por 100 g (referencia genérica)',
      per100:
          'Por 100 g: ${f.kcalPer100g.round()} kcal · P ${f.proteinPer100g.round()} · C ${f.carbsPer100g.round()} · G ${f.fatPer100g.round()}',
      unitGramsHint: f.unitGrams?.round(),
      initialUnitMode: unitMode,
      initialQty: initialQty,
      onMacros: (grams) => f.forGrams(grams),
      saveLibDefault: widget.saveToLibrary,
      labelFrom: (mode, qty, grams) {
        switch (mode) {
          case 1:
            return '${qty == qty.roundToDouble() ? qty.toInt() : qty} ml';
          case 2:
            final u = qty == qty.roundToDouble() ? '${qty.toInt()}' : '$qty';
            return '$u ud (${grams.round()} g)';
          default:
            return '${grams.round()} g';
        }
      },
      unitGramsForUd: unitGrams,
    );

    if (confirmed == null || !mounted) return;
    await _finishPick(confirmed);
  }

  Future<void> _finishPick(FoodSearchResult confirmed) async {
    if (confirmed.saveToLibrary) {
      final user = ref.read(authServiceProvider).currentUser;
      if (user != null) {
        await ref.read(profileRepositoryProvider).saveFood(
              user.uid,
              SavedFood(
                id: '',
                name: confirmed.name,
                calories: confirmed.calories,
                proteinGrams: confirmed.proteinGrams,
                carbsGrams: confirmed.carbsGrams,
                fatGrams: confirmed.fatGrams,
                portionGrams: confirmed.grams,
                servingLabel: confirmed.servingLabel,
              ),
            );
        ref.invalidate(savedFoodsProvider);
      }
    }
    if (mounted) Navigator.pop(context, confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tab = _tabs.index;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar alimento'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Supermercado', icon: Icon(Icons.storefront, size: 18)),
            Tab(text: 'Extras', icon: Icon(Icons.eco, size: 18)),
            Tab(text: 'Código', icon: Icon(Icons.qr_code, size: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (tab == 0 || tab == 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tab == 2 ? _barcodeCtrl : _searchCtrl,
                      textInputAction: TextInputAction.search,
                      keyboardType: tab == 2
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(
                        hintText: tab == 2
                            ? 'Código de barras (EAN/UPC)'
                            : 'Ej: yogurt, arroz, pollo…',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(
                          tab == 2 ? Icons.qr_code_2 : Icons.search,
                        ),
                      ),
                      onSubmitted: (_) =>
                          tab == 2 ? _runBarcode() : _runSearch(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading
                        ? null
                        : () => tab == 2 ? _runBarcode() : _runSearch(),
                    style: FilledButton.styleFrom(backgroundColor: primary),
                    child: const Text('Buscar'),
                  ),
                ],
              ),
            ),
          if (tab == 1) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _extrasCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar: manzana, huevo, papa…',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _extrasCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _extrasCtrl.clear();
                            _filterExtras();
                          },
                        ),
                ),
                onChanged: (_) => _filterExtras(),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: const Text('Todos'),
                      selected: _categoryFilter == null,
                      onSelected: (_) {
                        setState(() => _categoryFilter = null);
                        _filterExtras();
                      },
                    ),
                  ),
                  for (final c in commonFoodCategories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(c),
                        selected: _categoryFilter == c,
                        onSelected: (_) {
                          setState(() => _categoryFilter = c);
                          _filterExtras();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              tab == 1
                  ? 'Frutas, verduras, huevos y más (feria / casa). Valores genéricos por 100 g.'
                  : 'Datos de Open Food Facts (productos envasados). Ajusta gramos/ml antes de usar.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          if (_error != null && !_loading && tab != 1)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: tab == 1
                ? _buildExtrasList(primary)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final p = _results[i];
                      return Card(
                        child: ListTile(
                          leading: p.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    p.imageUrl!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    semanticLabel: p.displayName,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.fastfood,
                                      color: accentOf(context),
                                    ),
                                  ),
                                )
                              : Icon(Icons.fastfood, color: accentOf(context)),
                          title: Text(
                            p.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${p.caloriesPer100g.round()} kcal/100g · '
                            'P ${p.proteinPer100g.round()} · '
                            'C ${p.carbsPer100g.round()} · '
                            'G ${p.fatPer100g.round()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _pickProduct(p),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtrasList(Color primary) {
    if (_extras.isEmpty) {
      return Center(
        child: Text(
          'Sin coincidencias.\nPrueba otra palabra o categoría.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _extras.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final f = _extras[i];
        return Card(
          child: ListTile(
            leading: Icon(
              f.category == 'Frutas'
                  ? Icons.apple
                  : f.category == 'Verduras'
                      ? Icons.eco
                      : f.category == 'Proteínas'
                          ? Icons.egg_alt
                          : Icons.restaurant,
              color: accentOf(context),
            ),
            title: Text(f.name),
            subtitle: Text(
              '${f.category} · ${f.kcalPer100g.round()} kcal/100g · '
              'P ${f.proteinPer100g.round()} · C ${f.carbsPer100g.round()} · G ${f.fatPer100g.round()}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickCommon(f),
          ),
        );
      },
    );
  }
}
