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

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  String _query = '';
  String? _group;
  bool _onlyFavorites = false;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final exercisesAsync = ref.watch(exercisesProvider);
    final favAsync = ref.watch(favoriteExerciseIdsProvider);
    final favs = favAsync.valueOrNull ?? {};

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
      body: exercisesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          var filtered = list.where((e) {
            if (_onlyFavorites && !favs.contains(e.id)) return false;
            if (_group != null && e.muscleGroup != _group) return false;
            if (_query.isNotEmpty &&
                !e.name.toLowerCase().contains(_query.toLowerCase())) {
              return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Buscar ejercicio...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
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
                    FilterChip(
                      label: const Text('Todos'),
                      selected: _group == null && !_onlyFavorites,
                      onSelected: (_) => setState(() {
                        _group = null;
                        _onlyFavorites = false;
                      }),
                    ),
                    const SizedBox(width: 6),
                    FilterChip(
                      label: const Text('★ Favoritos'),
                      selected: _onlyFavorites,
                      onSelected: (_) =>
                          setState(() => _onlyFavorites = !_onlyFavorites),
                    ),
                    const SizedBox(width: 6),
                    ...Exercise.muscleGroups.map(
                          (g) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(g),
                          selected: _group == g,
                          onSelected: (_) => setState(() {
                            _group = _group == g ? null : g;
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                  child: Text(
                    'Sin ejercicios con ese filtro',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final e = filtered[i];
                    final isFav = favs.contains(e.id);
                    return Card(
                      child: ListTile(
                        title: Text(
                          e.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                            '${e.muscleGroup} · ${e.equipment}'),
                        trailing: IconButton(
                          icon: Icon(
                            isFav ? Icons.star : Icons.star_border,
                            color: isFav ? Colors.amber : Colors.grey,
                          ),
                          onPressed: () async {
                            final user = ref
                                .read(authServiceProvider)
                                .currentUser;
                            if (user == null) return;
                            await ref
                                .read(exerciseRepositoryProvider)
                                .toggleFavorite(user.uid, e.id);
                            ref.invalidate(favoriteExerciseIdsProvider);
                          },
                        ),
                        onTap: () {
                          if (e.instructions.isEmpty) return;
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(e.name),
                              content: Text(e.instructions),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cerrar'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
