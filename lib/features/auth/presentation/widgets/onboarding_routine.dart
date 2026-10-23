part of 'onboarding_pages.dart';

/// Página 4: rutina dinámica generada según las preferencias del usuario.
class RoutinePage extends StatelessWidget {
  final RoutineGoal goal;
  final RoutineLevel level;
  final int days;
  final int minutes;
  final Set<String> equipment;
  final List<RoutineDay>? generated;
  final bool generating;
  final bool catalogReady;
  final Color primary;
  final ValueChanged<RoutineLevel> onLevel;
  final ValueChanged<int> onDays;
  final ValueChanged<int> onMinutes;
  final void Function(String name, bool selected) onEquipment;
  final VoidCallback onGenerate;
  final VoidCallback? onRegenerate;
  final ValueChanged<RoutineExercise>? onExerciseTap;

  const RoutinePage({
    super.key,
    required this.goal,
    required this.level,
    required this.days,
    required this.minutes,
    required this.equipment,
    required this.generated,
    required this.generating,
    required this.catalogReady,
    required this.primary,
    required this.onLevel,
    required this.onDays,
    required this.onMinutes,
    required this.onEquipment,
    required this.onGenerate,
    this.onRegenerate,
    this.onExerciseTap,
  });

  static const equipmentOptions = [
    'Barra',
    'Mancuernas',
    'Polea',
    'Máquina',
    'Peso corporal',
    'Kettlebell',
    'Bandas',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const OnboardingHeader(
          icon: Icons.auto_awesome,
          title: 'Diseña tu rutina',
          subtitle:
              'Generamos una rutina según tu objetivo, tu nivel y los días que '
              'puedes entrenar. Después puedes editarla o cambiarla cuando quieras.',
          step: 'PASO 4 DE 5',
        ),
        ParamSection(
          title: 'Objetivo',
          emphasized: true,
          helper: 'Define la meta principal de tu entrenamiento.',
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_outlined, size: 16, color: cs.onPrimary),
                  const SizedBox(width: 8),
                  Text(
                    goal.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ParamSection(
          title: 'Nivel',
          helper: 'Ajustamos series y descansos a tu experiencia.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in RoutineLevel.values)
                ParamChoiceChip(
                  label: l.label,
                  selected: level == l,
                  onTap: () => onLevel(l),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ParamSection(
          title: 'Días por semana',
          emphasized: true,
          helper: 'Los días que realmente puedes entrenar cada semana.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in [2, 3, 4, 5, 6])
                ParamChoiceChip(
                  label: '$n',
                  compact: true,
                  selected: days == n,
                  onTap: () => onDays(n),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ParamSection(
          title: 'Tiempo por sesión',
          helper: 'Cuánto tiempo tienes por sesión, descansos incluidos.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in [30, 45, 60, 75, 90])
                ParamChoiceChip(
                  label: m == 90 ? '90+ min' : '$m min',
                  compact: true,
                  selected: minutes == m,
                  onTap: () => onMinutes(m),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ParamSection(
          title: 'Equipamiento disponible',
          trailing: const ParamMultiBadge(),
          helper: 'Sin marcar nada se asume gimnasio completo. '
              'Puedes marcar varios.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in equipmentOptions)
                ParamFilterChip(
                  label: e,
                  selected: equipment.contains(e),
                  onSelected: (sel) => onEquipment(e, sel),
                ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: (generating || !catalogReady) ? null : onGenerate,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: generating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            generating
                ? 'Generando…'
                : (generated == null
                    ? 'Generar mi rutina'
                    : 'Volver a generar'),
          ),
        ),
        if (!catalogReady && !generating) ...[
          const SizedBox(height: 8),
          Text(
            'Cargando el catálogo de ejercicios…',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
        if (generated != null) ...[
          const SizedBox(height: 22),
          Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: accentOf(context)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tu rutina está lista',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Se guardará como tu rutina semanal al terminar.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ...generated!.map(
            (d) => RoutinePreviewCard(
              day: d,
              onExerciseTap: onExerciseTap,
            ),
          ),
          if (onRegenerate != null) ...[
            const SizedBox(height: 6),
            OutlinedButton.icon(
              onPressed: generating ? null : onRegenerate,
              icon: const Icon(Icons.refresh),
              label: const Text('Generar otra rutina'),
            ),
          ],
        ],
      ],
    );
  }
}
