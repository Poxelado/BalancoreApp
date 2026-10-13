import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/ai_service.dart';
import '../../../../core/ai/ai_key_store.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/exercise.dart';
import '../../domain/routine_generator.dart';
import '../providers/exercise_provider.dart';
import 'ai_settings_screen.dart';

/// Pantalla del asistente: recoge los datos de la rutina y la genera.
///
/// Funciona siempre: si no hay clave de IA configurada, o si la IA falla, usa
/// el generador de reglas. La IA es un plus, nunca un requisito.
class RoutineGeneratorScreen extends ConsumerStatefulWidget {
  const RoutineGeneratorScreen({super.key});

  @override
  ConsumerState<RoutineGeneratorScreen> createState() =>
      _RoutineGeneratorScreenState();
}

class _RoutineGeneratorScreenState
    extends ConsumerState<RoutineGeneratorScreen> {
  RoutineGoal _goal = RoutineGoal.mantenimiento;
  RoutineLevel _level = RoutineLevel.intermedio;
  int _days = 4;
  final Set<String> _equipment = {};
  bool _generating = false;

  /// 'ai' = generada por el modelo, 'rules' = por reglas.
  String? _source;
  List<RoutineDay>? _preview;

  @override
  void initState() {
    super.initState();
    // La clave se lee una vez; si el usuario la configura en Ajustes y vuelve,
    // se vuelve a leer al entrar.
    _loadKey();
  }

  bool _hasKey = false;

  Future<void> _loadKey() async {
    final has = await AiKeyStore.hasKey();
    if (mounted) setState(() => _hasKey = has);
  }

  static const _equipmentOptions = [
    'Barra',
    'Mancuernas',
    'Polea',
    'Máquina',
    'Peso corporal',
    'Kettlebell',
    'Bandas',
  ];

  Future<void> _generate(List<Exercise> catalog) async {
    if (_generating) return;
    setState(() => _generating = true);
    try {
      final req = RoutineRequest(
        goal: _goal,
        level: _level,
        daysPerWeek: _days,
        catalog: catalog,
        equipment: _equipment,
      );
      // Capa 1: reglas. Siempre disponible.
      var days = generateRoutine(req);
      var source = 'rules';

      // Capa 2: modelo de lenguaje, solo si el usuario trajo su clave.
      if (_hasKey) {
        try {
          final service = RoutineAiServiceImpl();
          await service.load();
          final profile = await ref.read(userProfileProvider.future);
          final aiDays = await service.generate(
            context: RoutineAiContext(
              goal: _goal.label,
              daysPerWeek: _days,
              level: _level.label,
              equipment: _equipment.toList(),
              weight: profile?.currentWeight,
              age: profile?.age,
              sex: profile?.sex,
            ),
            allowedExercises: [
              for (final e in catalog)
                AiExercise(
                  id: e.id,
                  name: e.name,
                  muscleGroup: e.muscleGroup,
                ),
            ],
          );
          if (aiDays != null && aiDays.isNotEmpty) {
            days = aiDays;
            source = 'ai';
          }
        } catch (_) {
          // Cualquier fallo de red o cuota: se queda con las reglas.
        }
      }

      if (!mounted) return;
      setState(() {
        _preview = days;
        _source = source;
        _generating = false;
      });
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _apply() async {
    final days = _preview;
    if (days == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Aplicar rutina'),
        content: Text(
          'Se reemplazará tu rutina semanal por la rutina generada '
          '(${days.length} días). ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    await ref.read(profileRepositoryProvider).saveAllRoutines(user.uid, days);
    ref.invalidate(routinesProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final catalog = ref.watch(exercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asistente de rutina'),
        actions: [
          IconButton(
            tooltip: 'Configurar IA',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
              _loadKey();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: catalog.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('No se pudo cargar')),
          data: (exercises) {
            if (exercises.isEmpty) {
              return const Center(child: Text('Catálogo vacío'));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _goalSelector(primary),
                const SizedBox(height: 16),
                _levelSelector(primary),
                const SizedBox(height: 16),
                _daysSelector(primary),
                const SizedBox(height: 16),
                _equipmentSelector(primary),
                const SizedBox(height: 8),
                _aiNotice(),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      _generating ? null : () => _generate(exercises),
                  icon: _generating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _generating ? 'Generando…' : 'Generar rutina',
                  ),
                ),
                if (_preview != null) ...[
                  const SizedBox(height: 20),
                  _source == 'ai'
                      ? Row(
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 16, color: primary),
                            const SizedBox(width: 6),
                            const Text(
                              'Generada con IA',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(Icons.rule, size: 16, color: primary),
                            const SizedBox(width: 6),
                            const Text(
                              'Generada con el motor de reglas',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                  const SizedBox(height: 8),
                  ..._preview!.map(_dayCard),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _apply,
                    child: const Text('Aplicar a mi semana'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dayCard(RoutineDay d) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${d.day} · ${d.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            for (final e in d.exercises)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  '· ${e.exerciseName} — ${e.sets}x${e.reps} (${e.restSeconds}s)',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _aiNotice() {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _hasKey
                  ? 'Se enviará tu objetivo, nivel y días al modelo de IA para '
                      'generar la rutina. No se envía ningún dato personal '
                      'identificable.'
                  : 'Sin clave de IA: se usará el generador de reglas, que '
                      'funciona sin internet. Puedes añadir una clave en '
                      'Ajustes de IA.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalSelector(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Objetivo', primary),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final g in RoutineGoal.values)
              ChoiceChip(
                label: Text(g.label),
                selected: _goal == g,
                onSelected: (_) => setState(() => _goal = g),
              ),
          ],
        ),
      ],
    );
  }

  Widget _levelSelector(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Nivel', primary),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final l in RoutineLevel.values)
              ChoiceChip(
                label: Text(l.label),
                selected: _level == l,
                onSelected: (_) => setState(() => _level = l),
              ),
          ],
        ),
      ],
    );
  }

  Widget _daysSelector(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Días por semana', primary),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final n in [2, 3, 4, 5, 6])
              ChoiceChip(
                label: Text('$n'),
                selected: _days == n,
                onSelected: (_) => setState(() => _days = n),
              ),
          ],
        ),
      ],
    );
  }

  Widget _equipmentSelector(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Equipamiento disponible', primary),
        const SizedBox(height: 2),
        Text(
          'Sin marcar nada: se asume gimnasio completo',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final e in _equipmentOptions)
              FilterChip(
                label: Text(e),
                selected: _equipment.contains(e),
                onSelected: (sel) => setState(() {
                  if (sel) {
                    _equipment.add(e);
                  } else {
                    _equipment.remove(e);
                  }
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _label(String text, Color primary) => Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: primary,
        ),
      );
}