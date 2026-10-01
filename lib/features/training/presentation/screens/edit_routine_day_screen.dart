import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/exercise.dart';
import 'edit_routine_exercise_screen.dart';
import 'exercise_detail_screen.dart';

class EditRoutineDayScreen extends ConsumerStatefulWidget {
  final RoutineDay day;

  const EditRoutineDayScreen({super.key, required this.day});

  @override
  ConsumerState<EditRoutineDayScreen> createState() =>
      _EditRoutineDayScreenState();
}

class _EditRoutineDayScreenState extends ConsumerState<EditRoutineDayScreen> {
  late TextEditingController _titleCtrl;
  late bool _isRestDay;
  late List<RoutineExercise> _exercises;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.day.title);
    _isRestDay = widget.day.isRestDay;
    _exercises = List<RoutineExercise>.from(widget.day.exercises);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  String get _autoDuration =>
      RoutineExercise.estimateDayDuration(_exercises);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;

      final updated = RoutineDay(
        day: widget.day.day,
        title: _titleCtrl.text.trim().isEmpty
            ? widget.day.title
            : _titleCtrl.text.trim(),
        duration: _isRestDay ? '' : _autoDuration,
        calories: widget.day.calories,
        isRestDay: _isRestDay,
        description: widget.day.description,
        imageUrl: widget.day.imageUrl,
        exercises: _isRestDay ? const [] : _exercises,
      );

      await ref.read(profileRepositoryProvider).saveRoutine(user.uid, updated);

      // Memoria de pesos/series por ejercicio
      if (!_isRestDay) {
        for (final ex in _exercises) {
          await ref.read(profileRepositoryProvider).saveExerciseDefault(
            uid: user.uid,
            exerciseId: ex.exerciseId,
            plannedSets: ex.effectiveSets,
            restSeconds: ex.restSeconds,
            notes: ex.notes,
          );
        }
      }

      ref.invalidate(routinesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Día guardado')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openExerciseEditor(int index) async {
    final result = await Navigator.push<RoutineExercise>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditRoutineExerciseScreen(exercise: _exercises[index]),
      ),
    );
    if (result != null) {
      setState(() => _exercises[index] = result);
    }
  }

  void _openDetail(RoutineExercise ex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exerciseId: ex.exerciseId,
          exerciseName: ex.exerciseName,
          muscleGroup: ex.muscleGroup,
        ),
      ),
    );
  }

  Future<void> _addExercise() async {
    final Exercise? picked = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(builder: (_) => const _PickExerciseScreen()),
    );
    if (picked == null) return;

    // Recuperar memoria (pesos / descanso) si existía
    final user = ref.read(authServiceProvider).currentUser;
    List<PlannedSet> planned = [
      const PlannedSet(weight: 0, reps: 10),
      const PlannedSet(weight: 0, reps: 10),
      const PlannedSet(weight: 0, reps: 10),
    ];
    var rest = 60;
    var notes = '';

    if (user != null) {
      final data = await ref
          .read(profileRepositoryProvider)
          .getExerciseDefault(user.uid, picked.id);
      if (data != null) {
        rest = data['restSeconds'] as int? ?? 60;
        notes = (data['notes'] as String?) ?? '';
        final raw = data['plannedSets'];
        if (raw is List && raw.isNotEmpty) {
          planned = [
            for (final item in raw)
              if (item is Map)
                PlannedSet.fromMap(Map<String, dynamic>.from(item)),
          ];
          if (planned.isEmpty) {
            planned = [
              const PlannedSet(weight: 0, reps: 10),
              const PlannedSet(weight: 0, reps: 10),
              const PlannedSet(weight: 0, reps: 10),
            ];
          }
        }
      }
    }

    setState(() {
      _exercises.add(
        RoutineExercise(
          exerciseId: picked.id,
          exerciseName: picked.name,
          muscleGroup: picked.muscleGroup,
          sets: planned.length,
          reps: planned.first.reps,
          plannedSets: planned,
          restSeconds: rest,
          notes: notes,
        ),
      );
      _isRestDay = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('Editar · ${widget.day.day}'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            )
                : const Text('Guardar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Día de descanso'),
            value: _isRestDay,
            activeColor: primary,
            onChanged: (v) => setState(() {
              _isRestDay = v;
              if (v) _titleCtrl.text = 'Descanso';
            }),
          ),
          TextField(
            controller: _titleCtrl,
            enabled: !_isRestDay,
            decoration: const InputDecoration(
              labelText: 'Título (ej. Pecho, Pierna)',
              border: OutlineInputBorder(),
            ),
          ),
          if (!_isRestDay) ...[
            const SizedBox(height: 12),
            // Duración automática (solo lectura)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Duración estimada (auto)',
                border: OutlineInputBorder(),
                helperText: '1 min por serie + descansos entre series',
              ),
              child: Text(
                _autoDuration.isEmpty ? '—' : _autoDuration,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Ejercicios (${_exercises.length})',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: primary, fontSize: 16),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir'),
                ),
              ],
            ),
            if (_exercises.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Sin ejercicios. Pulsa Añadir.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exercises.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _exercises.removeAt(oldIndex);
                    _exercises.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final ex = _exercises[index];
                  final n = ex.effectiveSets.length;
                  final restM = ex.restSeconds ~/ 60;
                  final restS = ex.restSeconds % 60;
                  final restLabel = restM > 0
                      ? (restS > 0 ? '${restM}min ${restS}s' : '${restM}min')
                      : '${restS}s';
                  final firstW = n > 0 ? ex.effectiveSets.first.weight : 0.0;
                  final weightHint = firstW > 0
                      ? '${firstW == firstW.roundToDouble() ? firstW.toInt() : firstW} kg'
                      : 'sin peso';

                  return Card(
                    key: ValueKey('${ex.exerciseId}_$index'),
                    child: ListTile(
                      leading: const Icon(Icons.drag_handle),
                      title: Text(
                        ex.exerciseName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${ex.muscleGroup.isEmpty ? '—' : ex.muscleGroup}'
                            ' · $n series · $weightHint · descanso $restLabel',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Detalle',
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => _openDetail(ex),
                          ),
                          IconButton(
                            tooltip: 'Series y pesos',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openExerciseEditor(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () =>
                                setState(() => _exercises.removeAt(index)),
                          ),
                        ],
                      ),
                      onTap: () => _openExerciseEditor(index),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _PickExerciseScreen extends StatefulWidget {
  const _PickExerciseScreen();

  @override
  State<_PickExerciseScreen> createState() => _PickExerciseScreenState();
}

class _PickExerciseScreenState extends State<_PickExerciseScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final filtered = ExerciseCatalog.builtIn.where((e) {
      if (_query.isEmpty) return true;
      return e.name.toLowerCase().contains(_query.toLowerCase()) ||
          e.muscleGroup.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elegir ejercicio'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final e = filtered[i];
                return ListTile(
                  title: Text(e.name),
                  subtitle: Text('${e.muscleGroup} · ${e.equipment}'),
                  onTap: () => Navigator.pop(context, e),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
