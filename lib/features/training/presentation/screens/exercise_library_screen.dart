import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/exercise.dart';
import '../providers/exercise_provider.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState
    extends ConsumerState<ExerciseLibraryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _muscleFilter; // null = todos
  bool _onlyFavorites = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final exercisesAsync = ref.watch(exercisesProvider);
    final favAsync = ref.watch(favoriteExerciseIdsProvider);
    final favIds = favAsync.valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de ejercicios'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _onlyFavorites ? 'Ver todos' : 'Solo favoritos',
            icon: Icon(
              _onlyFavorites ? Icons.star : Icons.star_border,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _onlyFavorites = !_onlyFavorites),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Crear', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar ejercicio...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: const Text('Todos'),
                    selected: _muscleFilter == null,
                    onSelected: (_) => setState(() => _muscleFilter = null),
                  ),
                ),
                ...Exercise.muscleGroups.map((g) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(g),
                      selected: _muscleFilter == g,
                      onSelected: (_) => setState(() {
                        _muscleFilter = _muscleFilter == g ? null : g;
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: exercisesAsync.when(
              loading: () =>
                  Center(child: CircularProgressIndicator(color: primary)),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (all) {
                var list = all.where((e) {
                  if (_muscleFilter != null &&
                      e.muscleGroup != _muscleFilter) {
                    return false;
                  }
                  if (_onlyFavorites && !favIds.contains(e.id)) {
                    return false;
                  }
                  if (_query.isNotEmpty &&
                      !e.name.toLowerCase().contains(_query) &&
                      !e.muscleGroup.toLowerCase().contains(_query)) {
                    return false;
                  }
                  return true;
                }).toList();

                if (list.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay ejercicios con ese filtro.\nCrea uno con el botón +.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Agrupar por músculo si no hay filtro
                if (_muscleFilter == null && _query.isEmpty && !_onlyFavorites) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    children: Exercise.muscleGroups.map((group) {
                      final items =
                          list.where((e) => e.muscleGroup == group).toList();
                      if (items.isEmpty) return const SizedBox.shrink();
                      return _MuscleGroupSection(
                        group: group,
                        exercises: items,
                        favoriteIds: favIds,
                        onTap: (e) => _showDetail(context, e, favIds),
                        onToggleFav: (e) => _toggleFav(e.id),
                      );
                    }).toList(),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final e = list[i];
                    return _ExerciseTile(
                      exercise: e,
                      isFavorite: favIds.contains(e.id),
                      onTap: () => _showDetail(context, e, favIds),
                      onToggleFav: () => _toggleFav(e.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFav(String exerciseId) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    await ref
        .read(exerciseRepositoryProvider)
        .toggleFavorite(user.uid, exerciseId);
    ref.invalidate(favoriteExerciseIdsProvider);
  }

  void _showDetail(
    BuildContext context,
    Exercise exercise,
    Set<String> favIds,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final isFav = favIds.contains(exercise.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: Colors.amber.shade700,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _toggleFav(exercise.id);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(exercise.muscleGroup)),
                  Chip(label: Text(exercise.equipment)),
                  if (exercise.isCustom)
                    const Chip(
                      label: Text('Personalizado'),
                      avatar: Icon(Icons.person, size: 16),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Cómo hacerlo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                exercise.instructions.isEmpty
                    ? 'Sin instrucciones todavía.'
                    : exercise.instructions,
                style: const TextStyle(height: 1.4),
              ),
              if (exercise.isCustom) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openEditor(context, exercise: exercise);
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final user =
                              ref.read(authServiceProvider).currentUser;
                          if (user == null) return;
                          await ref
                              .read(exerciseRepositoryProvider)
                              .deleteCustomExercise(user.uid, exercise.id);
                          ref.invalidate(exercisesProvider);
                          ref.invalidate(favoriteExerciseIdsProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Eliminar',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, {Exercise? exercise}) async {
    final nameCtrl = TextEditingController(text: exercise?.name ?? '');
    final instrCtrl =
        TextEditingController(text: exercise?.instructions ?? '');
    String muscle = exercise?.muscleGroup ?? 'Pecho';
    String equipment = exercise?.equipment ?? 'Gimnasio';
    final primary = Theme.of(context).colorScheme.primary;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      exercise == null
                          ? 'Nuevo ejercicio'
                          : 'Editar ejercicio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: muscle,
                      decoration: const InputDecoration(
                        labelText: 'Grupo muscular',
                        border: OutlineInputBorder(),
                      ),
                      items: Exercise.muscleGroups
                          .map((g) =>
                              DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModal(() => muscle = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: equipment,
                      decoration: const InputDecoration(
                        labelText: 'Equipamiento',
                        border: OutlineInputBorder(),
                      ),
                      items: Exercise.equipmentTypes
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModal(() => equipment = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: instrCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Instrucciones (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final user =
                            ref.read(authServiceProvider).currentUser;
                        if (user == null) return;

                        final toSave = Exercise(
                          id: exercise?.id ?? '',
                          name: name,
                          muscleGroup: muscle,
                          equipment: equipment,
                          instructions: instrCtrl.text.trim(),
                          isCustom: true,
                        );
                        await ref
                            .read(exerciseRepositoryProvider)
                            .saveCustomExercise(user.uid, toSave);
                        ref.invalidate(exercisesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Guardar',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MuscleGroupSection extends StatelessWidget {
  final String group;
  final List<Exercise> exercises;
  final Set<String> favoriteIds;
  final void Function(Exercise) onTap;
  final void Function(Exercise) onToggleFav;

  const _MuscleGroupSection({
    required this.group,
    required this.exercises,
    required this.favoriteIds,
    required this.onTap,
    required this.onToggleFav,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            group,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
        ),
        ...exercises.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _ExerciseTile(
              exercise: e,
              isFavorite: favoriteIds.contains(e.id),
              onTap: () => onTap(e),
              onToggleFav: () => onToggleFav(e),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFav;

  const _ExerciseTile({
    required this.exercise,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFav,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        title: Text(
          exercise.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${exercise.muscleGroup} · ${exercise.equipment}'
          '${exercise.isCustom ? ' · Personalizado' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(
            isFavorite ? Icons.star : Icons.star_border,
            color: isFavorite ? Colors.amber.shade700 : Colors.grey,
          ),
          onPressed: onToggleFav,
        ),
      ),
    );
  }
}
