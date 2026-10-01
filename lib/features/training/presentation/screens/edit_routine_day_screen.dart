import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/exercise.dart';

class EditRoutineDayScreen extends ConsumerStatefulWidget {
  final RoutineDay day;

  const EditRoutineDayScreen({super.key, required this.day});

  @override
  ConsumerState<EditRoutineDayScreen> createState() =>
      _EditRoutineDayScreenState();
}

class _EditRoutineDayScreenState extends ConsumerState<EditRoutineDayScreen> {
  late bool _isRest;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _durationCtrl;
  late List<RoutineExercise> _exercises;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _isRest = widget.day.isRestDay;
    _titleCtrl = TextEditingController(text: widget.day.title);
    _durationCtrl = TextEditingController(text: widget.day.duration);
    _exercises = List.of(widget.day.exercises);
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

      final updated = widget.day.copyWith(
        title: _isRest ? 'Descanso' : _titleCtrl.text.trim(),
        duration: _isRest ? '' : _durationCtrl.text.trim(),
        isRestDay: _isRest,
        exercises: _isRest ? [] : _exercises,
        calories: _isRest ? 0 : widget.day.calories,
      );

      await ref.read(profileRepositoryProvider).saveRoutine(user.uid, updated);
      ref.invalidate(routinesProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addExercise() async {
    final selected = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => const _ExercisePickerSheet(),
    );
    if (selected == null) return;

    setState(() {
      _exercises.add(
        RoutineExercise(
          exerciseId: selected.id,
          exerciseName: selected.name,
          muscleGroup: selected.muscleGroup,
          sets: 3,
          reps: 10,
        ),
      );
      _isRest = false;
      if (_titleCtrl.text.trim().isEmpty || _titleCtrl.text == 'Descanso') {
        _titleCtrl.text = selected.muscleGroup;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.day.day),
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
      floatingActionButton: _isRest
          ? null
          : FloatingActionButton.extended(
        onPressed: _addExercise,
        backgroundColor: primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ejercicio',
            style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Día de descanso'),
            value: _isRest,
            activeColor: primary,
            onChanged: (v) => setState(() => _isRest = v),
          ),
          const SizedBox(height: 8),
          if (!_isRest) ...[
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del día (ej: Pecho, Push)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationCtrl,
              decoration: const InputDecoration(
                labelText: 'Duración estimada',
                hintText: '45–60 min',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ejercicios (${_exercises.length})',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            if (_exercises.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Sin ejercicios.\nToca + Ejercicio para agregar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ..._exercises.asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              return Card(
                child: ListTile(
                  title: Text(e.exerciseName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${e.muscleGroup.isEmpty ? 'Ejercicio' : e.muscleGroup} · ${e.sets} × ${e.reps}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editSetsReps(i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            setState(() => _exercises.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 80),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  'Este día está marcado como descanso.\nNo se listarán ejercicios.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editSetsReps(int index) async {
    final e = _exercises[index];
    final setsCtrl = TextEditingController(text: '${e.sets}');
    final repsCtrl = TextEditingController(text: '${e.reps}');
    final primary = Theme.of(context).colorScheme.primary;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.exerciseName),
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
              decoration: const InputDecoration(
                labelText: 'Reps (o segundos)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('OK', style: TextStyle(color: primary)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _exercises[index] = e.copyWith(
        sets: int.tryParse(setsCtrl.text) ?? e.sets,
        reps: int.tryParse(repsCtrl.text) ?? e.reps,
      );
    });
  }
}

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _query = '';
  String? _group;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    var list = ExerciseCatalog.builtIn.where((e) {
      if (_group != null && e.muscleGroup != _group) return false;
      if (_query.isNotEmpty &&
          !e.name.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Elegir ejercicio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: _group == null,
                    onSelected: (_) => setState(() => _group = null),
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
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final e = list[i];
                  return ListTile(
                    title: Text(e.name),
                    subtitle: Text('${e.muscleGroup} · ${e.equipment}'),
                    onTap: () => Navigator.pop(context, e),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
