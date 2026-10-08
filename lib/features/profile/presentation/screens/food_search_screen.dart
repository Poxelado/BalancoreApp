import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/food/open_food_facts_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';

/// Resultado: comida lista para registrar (+ opcionalmente ya en savedFoods).
class FoodSearchResult {
  final String name;
  final int calories;
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final String? barcode;
  final bool saveToLibrary;

  const FoodSearchResult({
    required this.name,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    this.barcode,
    this.saveToLibrary = true,
  });
}

/// Busca en Open Food Facts y devuelve macros ajustadas por gramos.
class FoodSearchScreen extends ConsumerStatefulWidget {
  /// Si true, al confirmar guarda también en Mis alimentos.
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

  bool _loading = false;
  String? _error;
  List<OffProduct> _results = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    _barcodeCtrl.dispose();
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
        if (list.isEmpty) _error = 'Sin resultados para “$q”';
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

  Future<void> _pickProduct(OffProduct p) async {
    final gramsCtrl = TextEditingController(
      text: (p.servingGrams ?? 100).round().toString(),
    );
    bool saveLib = widget.saveToLibrary;

    final confirmed = await showModalBottomSheet<FoodSearchResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final grams = double.tryParse(
              gramsCtrl.text.replaceAll(',', '.'),
            ) ??
                100;
            final m = p.forGrams(grams.clamp(1, 5000));
            final primary = Theme.of(ctx).colorScheme.primary;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    p.displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (p.barcode.isNotEmpty)
                    Text(
                      'Código: ${p.barcode}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Por 100 g: ${p.caloriesPer100g.round()} kcal · '
                        'P ${p.proteinPer100g.round()} · '
                        'C ${p.carbsPer100g.round()} · '
                        'G ${p.fatPer100g.round()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: gramsCtrl,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Cantidad (gramos)',
                      border: OutlineInputBorder(),
                      suffixText: 'g',
                    ),
                    onChanged: (_) => setModal(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${m.kcal} kcal  ·  P ${m.protein} g  ·  '
                          'C ${m.carbs} g  ·  G ${m.fat} g',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: saveLib,
                    onChanged: (v) => setModal(() => saveLib = v ?? true),
                    title: const Text('Guardar en Mis alimentos'),
                    subtitle: const Text(
                      'Aparecerá en frecuentes para el próximo registro',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        ctx,
                        FoodSearchResult(
                          name: p.displayName,
                          calories: m.kcal,
                          proteinGrams: m.protein,
                          carbsGrams: m.carbs,
                          fatGrams: m.fat,
                          barcode: p.barcode.isEmpty ? null : p.barcode,
                          saveToLibrary: saveLib,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(backgroundColor: primary),
                    child: const Text('Usar este alimento'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    // Re-prompt save flag: use widget.saveToLibrary default if sheet dismissed
    if (confirmed == null || !mounted) return;

    // Guardar en biblioteca si el checkbox quedó true (default true)
    // Volvemos a mostrar un quick confirm if needed — simpler: always save when widget.saveToLibrary
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar alimento'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Nombre', icon: Icon(Icons.search, size: 18)),
            Tab(text: 'Código', icon: Icon(Icons.qr_code, size: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AnimatedBuilder(
              animation: _tabs,
              builder: (_, __) {
                final isBarcode = _tabs.index == 1;
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: isBarcode ? _barcodeCtrl : _searchCtrl,
                        textInputAction: TextInputAction.search,
                        keyboardType: isBarcode
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: InputDecoration(
                          hintText: isBarcode
                              ? 'Código de barras (EAN/UPC)'
                              : 'Ej: yogurt, arroz, pollo…',
                          border: const OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(
                            isBarcode ? Icons.qr_code_2 : Icons.search,
                          ),
                        ),
                        onSubmitted: (_) =>
                        isBarcode ? _runBarcode() : _runSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _loading
                          ? null
                          : () => isBarcode ? _runBarcode() : _runSearch(),
                      style: FilledButton.styleFrom(backgroundColor: primary),
                      child: const Text('Buscar'),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Datos de Open Food Facts (comunidad). Ajusta los gramos antes de usar.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          if (_error != null && !_loading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: ListView.separated(
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
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.fastfood,
                          color: primary,
                        ),
                      ),
                    )
                        : Icon(Icons.fastfood, color: primary),
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
}
