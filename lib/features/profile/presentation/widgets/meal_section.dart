import 'package:flutter/material.dart';
import '../../domain/user_profile.dart';

class MealSection extends StatelessWidget {
  final String type;
  final List<MealEntry> meals;
  final int totalCal;
  final void Function(MealEntry meal) onEdit;
  final void Function(String id) onDelete;
  final void Function(MealEntry meal) onSaveAsFood;

  const MealSection({
    super.key,
    required this.type,
    required this.meals,
    required this.totalCal,
    required this.onEdit,
    required this.onDelete,
    required this.onSaveAsFood,
  });

  IconData get _icon => switch (type) {
    'Desayuno' => Icons.wb_sunny_outlined,
    'Almuerzo' => Icons.lunch_dining_outlined,
    'Cena' => Icons.dinner_dining_outlined,
    _ => Icons.cookie_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(_icon, color: primary),
        title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          meals.isEmpty
              ? 'Sin registros'
              : '$totalCal kcal · ${meals.length} ítem(s)',
          style: const TextStyle(fontSize: 12),
        ),
        children: meals.isEmpty
            ? [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Nada registrado en esta comida.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          ),
        ]
            : meals.map((m) {
          final sub =
              '${m.calories} kcal'
              '${m.servingLabel != null && m.servingLabel!.isNotEmpty ? ' · ${m.servingLabel}' : (m.grams != null ? ' · ${m.grams} g' : '')}'
              '${m.proteinGrams > 0 || m.carbsGrams > 0 || m.fatGrams > 0 ? ' · P ${m.proteinGrams} · C ${m.carbsGrams} · G ${m.fatGrams}' : ''}';
          if (m.isRecipe && m.ingredients.isNotEmpty) {
            return ExpansionTile(
              dense: true,
              leading: Icon(Icons.restaurant_menu, color: primary, size: 20),
              title: Text(m.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit(m);
                  if (v == 'delete') onDelete(m.id);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar…')),
                  PopupMenuItem(
                      value: 'delete', child: Text('Eliminar')),
                ],
              ),
              children: [
                for (final ing in m.ingredients)
                  ListTile(
                    dense: true,
                    contentPadding:
                    const EdgeInsets.only(left: 56, right: 16),
                    title: Text(ing.name,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      '${ing.calories} kcal'
                          '${ing.grams != null ? ' · ${ing.grams} g' : ''}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            );
          }
          return ListTile(
            dense: true,
            title: Text(m.name),
            subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') onEdit(m);
                if (v == 'save') onSaveAsFood(m);
                if (v == 'delete') onDelete(m.id);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar…')),
                PopupMenuItem(
                    value: 'save',
                    child: Text('Guardar en Mis alimentos')),
                PopupMenuItem(
                    value: 'delete', child: Text('Eliminar')),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
