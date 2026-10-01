import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/exercise.dart';
import 'exercise_detail_screen.dart';

/// Editar un día de la rutina semanal (título, descanso, ejercicios).
class EditRoutineDayScreen extends ConsumerStatefulWidget {
  final RoutineDay day;

  const EditRoutineDayScreen({super.key, required this.day});

  @override
  ConsumerState<EditRoutineDayScreen> createState() =>
      _EditRoutineDayScreenState();
}

class _EditRoutineDayScreenState extends ConsumerState<EditRoutineDayScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _durationCtrl;
  late bool _isRestDay;
  late List<RoutineExercise> _exercises;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.day.title);
    _durationCtrl = TextEditingController(text: widget.day.duration);
    _isRestDay = widget.day.isRestDay;
    _exercises = List<RoutineExercise>.from(widget.day.exercises);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

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
        duration: _durationCtrl.text.trim(),
        calories: widget.day.calories,
        isRestDay: _isRestDay,
        description: widget.day.description,
        imageUrl: widget.day.imageUrl,
        exercises: _isRestDay ? const [] : _exercises,
      );

      await ref.read(profileRepositoryProvider).saveRoutine(user.uid, updated);
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
    setState(() {
      _exercises.add(
        RoutineExercise(
          exerciseId: picked.id,
          exerciseName: picked.name,
          muscleGroup: picked.muscleGroup,
          sets: 3,
          reps: 10,
        ),
      );
      _isRestDay = false;
    });
  }

  Future<void> _editExercise(int index) async {
    final ex = _exercises[index];
    final setsCtrl = TextEditingController(text: '${ex.sets}');
    final repsCtrl = TextEditingController(text: '${ex.reps}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ex.exerciseName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: setsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Series'),
            ),
            TextField(
              controller: repsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reps'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _exercises[index] = ex.copyWith(
        sets: int.tryParse(setsCtrl.text) ?? ex.sets,
        reps: int.tryParse(repsCtrl.text) ?? ex.reps,
      );
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
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Text(
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
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            enabled: !_isRestDay,
            decoration: const InputDecoration(
              labelText: 'Título (ej. Pecho, Pierna)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _durationCtrl,
            enabled: !_isRestDay,
            decoration: const InputDecoration(
              labelText: 'Duración (ej. 1h 30min)',
              border: OutlineInputBorder(),
            ),
          ),
          if (!_isRestDay) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Ejercicios (${_exercises.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primary,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_exercises.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Sin ejercicios.\nPulsa Añadir para elegir de la biblioteca.',
                    textAlign: TextAlign.center,
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
                  return Card(
                    key: ValueKey('${ex.exerciseId}_$index'),
                    child: ListTile(
                      leading: const Icon(Icons.drag_handle),
                      title: InkWell(
                        onTap: () => _openDetail(ex),
                        child: Text(
                          ex.exerciseName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primary,
                            decoration: TextDecoration.underline,
                            decorationColor: primary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      subtitle: Text(
                        '${ex.muscleGroup.isEmpty ? '—' : ex.muscleGroup}'
                            ' · ${ex.sets}×${ex.reps}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Ver detalle',
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => _openDetail(ex),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editExercise(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () {
                              setState(() => _exercises.removeAt(index));
                            },
                          ),
                        ],
                      ),
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

class _PickExerciseScreen extends ConsumerStatefulWidget {
  const _PickExerciseScreen();

  @override
  ConsumerState<_PickExerciseScreen> createState() =>
      _PickExerciseScreenState();
}

class _PickExerciseScreenState extends ConsumerState<_PickExerciseScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final all = ExerciseCatalog.builtIn;
    final filtered = all.where((e) {
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
