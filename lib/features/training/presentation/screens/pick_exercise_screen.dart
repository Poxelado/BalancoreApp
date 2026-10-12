import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/exercise.dart';
import '../providers/exercise_provider.dart';
import '../widgets/exercise_list_widgets.dart';

/// Selector de ejercicios para añadir a una rutina.
/// Devuelve `List<Exercise>` (selección múltiple) al pulsar "Añadir".
class PickExerciseScreen extends ConsumerStatefulWidget {
  const PickExerciseScreen({super.key});

  @override
  ConsumerState<PickExerciseScreen> createState() => _PickExerciseScreenState();
}

class _PickExerciseScreenState extends ConsumerState<PickExerciseScreen> {
  String _query = '';
  String? _group;
  String? _level;
  final Map<String, Exercise> _selected = {};

  void _toggle(Exercise e) {
    setState(() {
      if (_selected.containsKey(e.id)) {
        _selected.remove(e.id);
      } else {
        _selected[e.id] = e;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final exercisesAsync = ref.watch(exercisesProvider);
    final favAsync = ref.watch(favoriteExerciseIdsProvider);
    final favs = favAsync.valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selected.isEmpty
              ? 'Elegir ejercicios'
              : 'Elegir ejercicios (${_selected.length})',
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () => setState(_selected.clear),
              child: const Text(
                'Limpiar',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: exercisesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (base) {
          final all = ExerciseCatalog.forPicker(base);
          final groups = availableGroups(all);
          final filtered = all.where((e) {
            if (_group != null && e.muscleGroup != _group) return false;
            if (_level != null && e.level != _level) return false;
            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              final matches = e.name.toLowerCase().contains(q) ||
                  (e.nameEn?.toLowerCase().contains(q) ?? false);
              if (!matches) return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              ExerciseFilterBar(
                query: _query,
                group: _group,
                level: _level,
                groups: groups,
                searchHint: 'Buscar y añadir…',
                onQueryChanged: (v) => setState(() => _query = v.trim()),
                onGroupChanged: (g) => setState(() => _group = g),
                onLevelChanged: (l) => setState(() => _level = l),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} ejercicio(s)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ),
              Expanded(
                child: ExerciseListBody(
                  exercises: filtered,
                  favoriteIds: favs,
                  selectionMode: true,
                  selectedIds: _selected.keys.toSet(),
                  onTap: _toggle,
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _selected.isEmpty
              ? Text(
                  'Toca los ejercicios para seleccionarlos',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                )
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: primary),
                    onPressed: () =>
                        Navigator.pop(context, _selected.values.toList()),
                    icon: const Icon(Icons.add),
                    label: Text('Añadir (${_selected.length})'),
                  ),
                ),
        ),
      ),
    );
  }
}
