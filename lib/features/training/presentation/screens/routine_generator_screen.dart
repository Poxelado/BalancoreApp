import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/ai_service.dart';
import '../../../../core/ai/ai_key_store.dart';
import '../../../../core/prefs/routine_regen_prefs.dart';
import '../../../../core/widgets/param_chips.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/exercise.dart';
import '../../domain/routine_generator.dart';
import '../providers/exercise_provider.dart';
import '../widgets/routine_preview_widgets.dart';
import 'ai_settings_screen.dart';
import 'exercise_detail_screen.dart';
import '../../../../core/theme/app_theme.dart';

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
  int _minutes = 60;
  final Set<String> _equipment = {};
  bool _generating = false;

  /// 'ai' = generada por el modelo, 'rules' = por reglas.
  String? _source;
  List<RoutineDay>? _preview;

  /// Genera siempre con una semilla distinta para obtener una rutina distinta
  /// al pulsar "Regenerar". El primer "Generar" también es aleatorio.
  int _seed = Random().nextInt(1 << 31);

  @override
  void initState() {
    super.initState();
    // La clave se lee una vez; si el usuario la configura en Ajustes y vuelve,
    // se vuelve a leer al entrar.
    _loadKey();
  }

  bool _hasKey = false;

  Future<void> _loadKey() async {
    final has = await AiKeyStore.isConfigured();
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
    _seed = Random().nextInt(1 << 31);
    setState(() => _generating = true);
    try {
      final req = RoutineRequest(
        goal: _goal,
        level: _level,
        daysPerWeek: _days,
        catalog: catalog,
        equipment: _equipment,
        minutesAvailable: _minutes,
      );
      // Capa 1: reglas. Siempre disponible.
      var days = generateRoutine(req, seed: _seed);
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
              minutesAvailable: _minutes,
              targetExercisesPerDay: targetExercisesFor(
                minutes: _minutes,
                daysPerWeek: _days,
                level: _level,
              ),
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
            // El modelo elige los ejercicios; las reglas garantizan el
            // volumen y la estructura del día.
            days = topUpRoutineDays(aiDays, days);
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

  /// Botón "Regenerar": pide confirmación (salvo que el usuario haya marcado
  /// "no volver a preguntar") y vuelve a generar con los mismos parámetros.
  Future<void> _regenerate(List<Exercise> catalog) async {
    if (_generating) return;
    final skipped = await RoutineRegenPrefs.dontAsk();
    if (!skipped) {
      if (!mounted) return;
      final result = await _regenDialog(context);
      if (result == null) return;
      if (result.dontAskAgain) await RoutineRegenPrefs.setDontAsk(true);
    }
    await _generate(catalog);
  }

  Future<_RegenChoice?> _regenDialog(BuildContext context) async {
    var dontAsk = false;
    return showDialog<_RegenChoice>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setLocal) => AlertDialog(
          title: const Text('Generar otra rutina'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se generará una rutina nueva con los mismos parámetros. '
                'Si no te convenció la anterior, esta será distinta. '
                '¿Continuar?',
              ),
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: dontAsk,
                onChanged: (v) => setLocal(() => dontAsk = v ?? false),
                title: const Text(
                  'No volver a preguntar',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dCtx),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dCtx, _RegenChoice(dontAskAgain: dontAsk)),
              child: const Text('Generar'),
            ),
          ],
        ),
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                ParamSection(
                  title: 'Objetivo',
                  emphasized: true,
                  dense: true,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in RoutineGoal.values)
                        ParamChoiceChip(
                          label: g.label,
                          selected: _goal == g,
                          onTap: () => setState(() => _goal = g),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ParamSection(
                  title: 'Nivel',
                  dense: true,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final l in RoutineLevel.values)
                        ParamChoiceChip(
                          label: l.label,
                          selected: _level == l,
                          onTap: () => setState(() => _level = l),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ParamSection(
                  title: 'Días por semana',
                  emphasized: true,
                  dense: true,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final n in [2, 3, 4, 5, 6])
                        ParamChoiceChip(
                          label: '$n',
                          compact: true,
                          selected: _days == n,
                          onTap: () => setState(() => _days = n),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ParamSection(
                  title: 'Tiempo por sesión',
                  dense: true,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in const [30, 45, 60, 75, 90])
                        ParamChoiceChip(
                          label: m == 90 ? '90+ min' : '$m min',
                          compact: true,
                          selected: _minutes == m,
                          onTap: () => setState(() => _minutes = m),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ParamSection(
                  title: 'Equipamiento disponible',
                  dense: true,
                  trailing: const ParamMultiBadge(),
                  helper:
                      'Sin marcar nada se asume gimnasio completo.',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in _equipmentOptions)
                        ParamFilterChip(
                          label: e,
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
                ),
                const SizedBox(height: 12),
                _aiNotice(),
                const SizedBox(height: 18),
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
                                size: 16, color: accentOf(context)),
                            const SizedBox(width: 6),
                            const Text(
                              'Generada con IA',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Icon(Icons.rule, size: 16, color: accentOf(context)),
                            const SizedBox(width: 6),
                            const Text(
                              'Generada con el motor de reglas',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                  const SizedBox(height: 8),
                  ..._preview!.map(
                    (d) => RoutinePreviewCard(
                      day: d,
                      onExerciseTap: _openExercise,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _generating
                              ? null
                              : () => _regenerate(exercises),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Regenerar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _apply,
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _openExercise(RoutineExercise e) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exerciseId: e.exerciseId,
          exerciseName: e.exerciseName,
        ),
      ),
    );
  }

  Widget _aiNotice() {
    final primary = accentOf(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: accentOf(context)),
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

}

class _RegenChoice {
  final bool dontAskAgain;

  const _RegenChoice({required this.dontAskAgain});
}