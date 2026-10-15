import 'package:flutter/material.dart';

import '../../domain/exercise.dart';
import '../../../../core/theme/app_theme.dart';

/// Miniatura de un ejercicio (imagen remota con fallback al ícono).
/// Acepta un [Exercise] o resuelve por [exerciseId] desde el catálogo.
class ExerciseThumb extends StatelessWidget {
  final Exercise? exercise;
  final String? exerciseId;
  final double size;

  /// true = recorta la imagen en círculo (para llenar avatares redondos).
  final bool circular;

  const ExerciseThumb({
    super.key,
    this.exercise,
    this.exerciseId,
    this.size = 48,
    this.circular = false,
  }) : assert(exercise != null || exerciseId != null,
            'Indica exercise o exerciseId');

  @override
  Widget build(BuildContext context) {
    final e = exercise ?? ExerciseCatalog.byId(exerciseId!);
    final url = e?.imageUrl;
    if (url == null) return _fallback(accentOf(context));
    final image = Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: e?.name ?? 'Imagen del ejercicio',
      errorBuilder: (_, __, ___) => _fallback(accentOf(context)),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: size,
          height: size,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: accentOf(context)),
            ),
          ),
        );
      },
    );
    if (circular) return ClipOval(child: image);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: image,
    );
  }

  Widget _fallback(Color primary) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.12),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(8),
      ),
      child: Icon(Icons.fitness_center, color: primary, size: size * 0.45),
    );
  }
}

/// Banner grande de un ejercicio (estilo Hevy/Symmetry): la imagen a lo ancho
/// y debajo el nombre COMPLETO (sin recortar) con el grupo muscular. Cae al
/// ícono si no hay imagen.
class ExerciseBanner extends StatelessWidget {
  final String exerciseId;
  final String name;
  final String muscleGroup;
  final double height;
  final VoidCallback? onTap;

  const ExerciseBanner({
    super.key,
    required this.exerciseId,
    required this.name,
    this.muscleGroup = '',
    this.height = 132,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final e = ExerciseCatalog.byId(exerciseId);
    final url = e?.imageUrl;
    final accent = accentOf(context);
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        color: accent.withValues(alpha: 0.08),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (url != null)
                      Image.network(
                        url,
                        fit: BoxFit.cover,
                        semanticLabel: name,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => _icon(accent),
                      )
                    else
                      _icon(accent),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (muscleGroup.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.accessibility_new,
                              size: 14, color: accent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              muscleGroup,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(Color accent) => Center(
        child: Icon(
          Icons.fitness_center,
          size: 56,
          color: accent.withValues(alpha: 0.5),
        ),
      );
}

/// Ordena una lista de ejercicios agrupándolos por grupo muscular.
/// Los grupos conocidos (Exercise.muscleGroups) van primero; el resto después.
List<MapEntry<String, List<Exercise>>> groupByMuscle(
  List<Exercise> list, {
  Set<String> favorites = const {},
}) {
  final map = <String, List<Exercise>>{};
  for (final e in list) {
    final g = e.muscleGroup.trim().isEmpty ? 'Otro' : e.muscleGroup;
    map.putIfAbsent(g, () => []).add(e);
  }
  const known = Exercise.muscleGroups;
  final keys = map.keys.toList()
    ..sort((a, b) {
      final ia = known.indexOf(a);
      final ib = known.indexOf(b);
      if (ia != -1 && ib != -1) return ia.compareTo(ib);
      if (ia != -1) return -1;
      if (ib != -1) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  for (final k in keys) {
    map[k]!.sort((a, b) {
      final af = favorites.contains(a.id);
      final bf = favorites.contains(b.id);
      if (af != bf) return af ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }
  return [for (final k in keys) MapEntry(k, map[k]!)];
}

/// Grupos musculares presentes en una lista, en el orden de Exercise.muscleGroups.
List<String> availableGroups(List<Exercise> list) {
  final present = <String>{};
  for (final e in list) {
    present.add(e.muscleGroup.trim().isEmpty ? 'Otro' : e.muscleGroup);
  }
  final known = Exercise.muscleGroups.where(present.contains).toList();
  final others = present
      .where((g) => !Exercise.muscleGroups.contains(g))
      .toList()
    ..sort();
  return [...known, ...others];
}

/// Buscador + chips de grupo muscular y nivel. Controlado por el padre.
class ExerciseFilterBar extends StatelessWidget {
  final String query;
  final String? group;
  final String? level;
  final List<String> groups;
  final List<String> zones;
  final String? zone;
  final bool showLevels;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<String?> onLevelChanged;
  final ValueChanged<String?>? onZoneChanged;
  final String searchHint;

  const ExerciseFilterBar({
    super.key,
    required this.query,
    required this.group,
    required this.level,
    required this.groups,
    required this.onQueryChanged,
    required this.onGroupChanged,
    required this.onLevelChanged,
    this.zones = const [],
    this.zone,
    this.onZoneChanged,
    this.showLevels = true,
    this.searchHint = 'Buscar ejercicio…',
  });

  static const _levels = [
    ('beginner', 'Principiante'),
    ('intermediate', 'Intermedio'),
    ('expert', 'Avanzado'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onQueryChanged,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _chip(
                label: 'Todos',
                selected: group == null,
                onSelected: () => onGroupChanged(null),
              ),
              for (final g in groups)
                _chip(
                  label: g,
                  selected: group == g,
                  onSelected: () => onGroupChanged(group == g ? null : g),
                ),
            ],
          ),
        ),
        if (zones.isNotEmpty && onZoneChanged != null)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip(
                  label: 'Toda zona',
                  selected: zone == null,
                  onSelected: () => onZoneChanged!(null),
                ),
                for (final z in zones)
                  _chip(
                    label: z,
                    selected: zone == z,
                    onSelected: () => onZoneChanged!(zone == z ? null : z),
                  ),
              ],
            ),
          ),
        if (showLevels)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _chip(
                  label: 'Cualquier nivel',
                  selected: level == null,
                  onSelected: () => onLevelChanged(null),
                ),
                for (final entry in _levels)
                  _chip(
                    label: entry.$2,
                    selected: level == entry.$1,
                    onSelected: () =>
                        onLevelChanged(level == entry.$1 ? null : entry.$1),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

/// Lista de ejercicios agrupada por músculo, con imagen y selección opcional.
class ExerciseListBody extends StatelessWidget {
  final List<Exercise> exercises;
  final Set<String> favoriteIds;
  final void Function(Exercise) onTap;
  final void Function(Exercise)? onToggleFavorite;
  final bool selectionMode;
  final Set<String> selectedIds;
  final String emptyTitle;
  final String emptySubtitle;

  const ExerciseListBody({
    super.key,
    required this.exercises,
    required this.onTap,
    this.favoriteIds = const {},
    this.onToggleFavorite,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.emptyTitle = 'Sin ejercicios',
    this.emptySubtitle = 'Prueba otro filtro o busca por nombre.',
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (exercises.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final rows = <Object>[];
    for (final entry in groupByMuscle(exercises, favorites: favoriteIds)) {
      rows.add(entry.key);
      rows.addAll(entry.value);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
            child: Text(
              row,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: accentOf(context),
                letterSpacing: 0.3,
              ),
            ),
          );
        }
        final e = row as Exercise;
        return _item(context, e, primary);
      },
    );
  }

  Widget _item(BuildContext context, Exercise e, Color primary) {
    final isFav = favoriteIds.contains(e.id);
    final selected = selectedIds.contains(e.id);
    final subtitle = [
      e.muscleGroup,
      e.equipment,
      if (e.levelEs != null && e.levelEs!.isNotEmpty) e.levelEs!,
    ].join(' · ');

    return Card(
      child: ListTile(
        selected: selectionMode && selected,
        selectedTileColor: primary.withValues(alpha: 0.10),
        leading: ExerciseThumb(exercise: e),
        title: Text(
          e.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: selectionMode
            ? Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? primary : Colors.grey,
              )
            : (onToggleFavorite != null
                ? IconButton(
                    tooltip: isFav
                        ? 'Quitar de favoritos'
                        : 'Añadir a favoritos',
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? AppDataColors.gold : Colors.grey,
                    ),
                    onPressed: () => onToggleFavorite!(e),
                  )
                : null),
        onTap: () => onTap(e),
      ),
    );
  }
}
