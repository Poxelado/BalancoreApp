import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/exercise.dart';
import '../providers/exercise_provider.dart';
import 'exercise_detail_screen.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  String _query = '';
  String? _group;
  String? _level; // beginner | intermediate | expert
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
            icon: Icon(_onlyFavorites ? Icons.star : Icons.star_border),
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
            if (_level != null && e.level != _level) return false;
            if (_query.isNotEmpty &&
                !e.name.toLowerCase().contains(_query.toLowerCase())) {
              return false;
            }
            return true;
          }).toList();

          // Favoritos primero, luego A–Z
          filtered.sort((a, b) {
            final af = favs.contains(a.id);
            final bf = favs.contains(b.id);
            if (af != bf) return af ? -1 : 1;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar ejercicio…',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const SizedBox(height: 8),
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
                        selected: _group == null,
                        onSelected: (_) => setState(() => _group = null),
                      ),
                    ),
                    ...Exercise.muscleGroups.map(
                      (g) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(g),
                          selected: _group == g,
                          onSelected: (_) => setState(
                            () => _group = _group == g ? null : g,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                        label: const Text('Cualquier nivel'),
                        selected: _level == null,
                        onSelected: (_) => setState(() => _level = null),
                      ),
                    ),
                    for (final entry in [
                      ('beginner', 'Principiante'),
                      ('intermediate', 'Intermedio'),
                      ('expert', 'Avanzado'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(entry.$2),
                          selected: _level == entry.$1,
                          onSelected: (_) => setState(
                            () => _level =
                                _level == entry.$1 ? null : entry.$1,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} ejercicio(s)'
                    '${_onlyFavorites ? ' · favoritos' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off,
                        title: 'Sin ejercicios',
                        subtitle:
                            'Prueba otro filtro o busca por nombre.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final e = filtered[i];
                          final isFav = favs.contains(e.id);
                          final subtitle = [
                            e.muscleGroup,
                            e.equipment,
                            if (e.levelEs != null) e.levelEs!,
                            if (e.mechanic != null) e.mechanic!,
                          ].join(' · ');

                          return Card(
                            child: ListTile(
                              leading: e.imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        e.imageUrl!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            Icon(Icons.fitness_center,
                                                color: primary),
                                      ),
                                    )
                                  : CircleAvatar(
                                      backgroundColor:
                                          primary.withValues(alpha: 0.12),
                                      child: Icon(Icons.fitness_center,
                                          color: primary, size: 20),
                                    ),
                              title: Text(
                                e.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                subtitle,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  isFav ? Icons.star : Icons.star_border,
                                  color:
                                      isFav ? Colors.amber : Colors.grey,
                                ),
                                onPressed: () async {
                                  final user = ref
                                      .read(authServiceProvider)
                                      .currentUser;
                                  if (user == null) return;
                                  await ref
                                      .read(exerciseRepositoryProvider)
                                      .toggleFavorite(user.uid, e.id);
                                  ref.invalidate(
                                      favoriteExerciseIdsProvider);
                                },
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ExerciseDetailScreen.fromExercise(
                                            e),
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
