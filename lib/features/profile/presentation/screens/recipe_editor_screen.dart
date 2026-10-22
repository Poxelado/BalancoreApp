import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'food_search_screen.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/input_limits.dart';

/// Crear / editar un plato con ingredientes.
class RecipeEditorScreen extends ConsumerStatefulWidget {
  final SavedRecipe? existing;

  const RecipeEditorScreen({super.key, this.existing});

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  late final TextEditingController _nameCtrl;
  late List<RecipeIngredient> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _items = List.of(widget.existing?.ingredients ?? []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  int get _kcal => _items.fold(0, (s, i) => s + i.calories);
  int get _p => _items.fold(0, (s, i) => s + i.proteinGrams);
  int get _c => _items.fold(0, (s, i) => s + i.carbsGrams);
  int get _f => _items.fold(0, (s, i) => s + i.fatGrams);

  /// Impide pasar del tope de ingredientes (evita listas gigantes que
  /// congelan la UI). Devuelve true si aún se puede agregar.
  bool _canAddIngredient() {
    if (_items.length >= InputLimits.maxRecipeIngredients) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Máximo ${InputLimits.maxRecipeIngredients} ingredientes por receta',
          ),
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _addManual() async {
    if (!_canAddIngredient()) return;
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final pCtrl = TextEditingController(text: '0');
    final cCtrl = TextEditingController(text: '0');
    final fCtrl = TextEditingController(text: '0');
    final gCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final primary = Theme.of(ctx).colorScheme.primary;
        return AlertDialog(
          title: const Text('Ingrediente manual'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: InputFormatters.text(InputLimits.titleMax),
                ),
                TextField(
                  controller: calCtrl,
                  decoration: const InputDecoration(labelText: 'Calorías'),
                  keyboardType: TextInputType.number,
                  inputFormatters: InputFormatters.digits(maxLength: 5),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: pCtrl,
                        decoration: const InputDecoration(labelText: 'Prot'),
                        keyboardType: TextInputType.number,
                        inputFormatters: InputFormatters.digits(maxLength: 4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: cCtrl,
                        decoration: const InputDecoration(labelText: 'Carb'),
                        keyboardType: TextInputType.number,
                        inputFormatters: InputFormatters.digits(maxLength: 4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: fCtrl,
                        decoration: const InputDecoration(labelText: 'Grasa'),
                        keyboardType: TextInputType.number,
                        inputFormatters: InputFormatters.digits(maxLength: 4),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: gCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Gramos (opcional)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: InputFormatters.digits(maxLength: 5),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: primary),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    final cal = int.tryParse(calCtrl.text) ?? 0;
    if (name.isEmpty || cal <= 0) return;
    setState(() {
      _items.add(
        RecipeIngredient(
          name: name,
          calories: cal,
          proteinGrams: int.tryParse(pCtrl.text) ?? 0,
          carbsGrams: int.tryParse(cCtrl.text) ?? 0,
          fatGrams: int.tryParse(fCtrl.text) ?? 0,
          grams: int.tryParse(gCtrl.text),
        ),
      );
    });
  }

  Future<void> _addFromSaved() async {
    if (!_canAddIngredient()) return;
    final foods = await ref.read(savedFoodsProvider.future);
    if (!mounted) return;
    if (foods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes alimentos guardados')),
      );
      return;
    }
    final chosen = await showModalBottomSheet<SavedFood>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                'Mis alimentos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            for (final f in foods)
              ListTile(
                title: Text(f.name),
                subtitle: Text(
                  '${f.calories} kcal'
                      '${f.portionGrams != null ? ' · ${f.portionGrams} g' : ''}',
                ),
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        );
      },
    );
    if (chosen == null) return;
    setState(() {
      _items.add(
        RecipeIngredient(
          name: chosen.name,
          calories: chosen.calories,
          proteinGrams: chosen.proteinGrams,
          carbsGrams: chosen.carbsGrams,
          fatGrams: chosen.fatGrams,
          grams: chosen.portionGrams,
        ),
      );
    });
  }

  Future<void> _addFromOff() async {
    if (!_canAddIngredient()) return;
    final result = await Navigator.push<FoodSearchResult>(
      context,
      MaterialPageRoute(builder: (_) => const FoodSearchScreen(saveToLibrary: true)),
    );
    if (result == null) return;
    if (!_canAddIngredient()) return;
    setState(() {
      _items.add(
        RecipeIngredient(
          name: result.name,
          calories: result.calories,
          proteinGrams: result.proteinGrams,
          carbsGrams: result.carbsGrams,
          fatGrams: result.fatGrams,
          grams: result.grams,
          servingLabel: result.servingLabel,
        ),
      );
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pon un nombre al plato')),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un ingrediente')),
      );
      return;
    }
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).saveRecipe(
        user.uid,
        SavedRecipe(
          id: widget.existing?.id ?? '',
          name: name,
          ingredients: _items,
          useCount: widget.existing?.useCount ?? 0,
        ),
      );
      ref.invalidate(savedRecipesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plato "$name" guardado')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar plato' : 'Nuevo plato'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text(
              'Guardar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: InputFormatters.text(InputLimits.titleMax),
            decoration: const InputDecoration(
              labelText: 'Nombre del plato',
              hintText: 'Ej: Arroz con pollo',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Total: $_kcal kcal · P $_p · C $_c · G $_f',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: accentOf(context),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Ingredientes',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: accentOf(context),
            ),
          ),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Aún no hay ingredientes.\nAñade desde Mis alimentos, OFF o manual.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ...List.generate(_items.length, (i) {
              final ing = _items[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(ing.name),
                  subtitle: Text(
                    '${ing.calories} kcal'
                        '${ing.grams != null ? ' · ${ing.grams} g' : ''}'
                        '${ing.servingLabel != null ? ' · ${ing.servingLabel}' : ''}'
                        ' · P ${ing.proteinGrams} · C ${ing.carbsGrams} · G ${ing.fatGrams}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    tooltip: 'Eliminar ingrediente',
                    icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                    onPressed: () => setState(() => _items.removeAt(i)),
                  ),
                ),
              );
            }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addFromSaved,
                  icon: const Icon(Icons.bookmark_outline, size: 18),
                  label: const Text('Mis alim.'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addFromOff,
                  icon: const Icon(Icons.manage_search, size: 18),
                  label: const Text('Buscar'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _addManual,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Manual'),
                  style: FilledButton.styleFrom(backgroundColor: primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
