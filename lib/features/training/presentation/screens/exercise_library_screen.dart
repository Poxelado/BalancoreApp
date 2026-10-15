import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/exercise.dart';
import '../../domain/muscle_zones.dart';
import '../providers/exercise_provider.dart';
import '../widgets/exercise_list_widgets.dart';
import 'exercise_detail_screen.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/utils/text_normalize.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

List<String> _zoneSearchWords(Exercise e) => [
      ...primaryZonesOf(e),
      ...e.primaryMuscles,
      ...e.secondaryMuscles,
    ];

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  String _query = '';
  String? _group;
  String? _zone;
  String? _level; // beginner | intermediate | expert
  bool _onlyFavorites = false;

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);
    final favAsync = ref.watch(favoriteExerciseIdsProvider);
    final favs = favAsync.valueOrNull ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de ejercicios'),
        actions: [
          IconButton(
            tooltip: _onlyFavorites ? 'Ver todos' : 'Solo favoritos',
            icon: Icon(_onlyFavorites ? Icons.star : Icons.star_border),
            onPressed: () => setState(() => _onlyFavorites = !_onlyFavorites),
          ),
        ],
      ),
      body: exercisesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: accentOf(context))),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          final groups = availableGroups(list);
          final zones = availableZones(list);
          final filtered = list.where((e) {
            if (_onlyFavorites && !favs.contains(e.id)) return false;
            if (_group != null && e.muscleGroup != _group) return false;
            if (_zone != null && !primaryZonesOf(e).contains(_zone)) return false;
            if (_level != null && e.level != _level) return false;
            if (_query.isNotEmpty) {
              final matches = matchesSearch(e.name, _query) ||
                  matchesSearch(e.nameEn ?? '', _query) ||
                  matchesSearch(e.muscleGroup, _query) ||
                  _zoneSearchWords(e).any((z) => matchesSearch(z, _query));
              if (!matches) return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              ExerciseFilterBar(
                query: _query,
                group: _group,
                zone: _zone,
                level: _level,
                groups: groups,
                zones: zones,
                onQueryChanged: (v) => setState(() => _query = v.trim()),
                onGroupChanged: (g) => setState(() => _group = g),
                onZoneChanged: (z) => setState(() => _zone = z),
                onLevelChanged: (l) => setState(() => _level = l),
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
                child: ExerciseListBody(
                  exercises: filtered,
                  favoriteIds: favs,
                  onTap: (e) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExerciseDetailScreen.fromExercise(e),
                      ),
                    );
                  },
                  onToggleFavorite: (e) async {
                    final user =
                        ref.read(authServiceProvider).currentUser;
                    if (user == null) return;
                    await ref
                        .read(exerciseRepositoryProvider)
                        .toggleFavorite(user.uid, e.id);
                    ref.invalidate(favoriteExerciseIdsProvider);
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
