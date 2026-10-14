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
        _chip(
          icon: Icons.flag_outlined,
          text: 'Objetivo: ${goal.label}',
        ),
        const SizedBox(height: 20),
        _label('Nivel'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final l in RoutineLevel.values)
              ChoiceChip(
                label: Text(l.label),
                selected: level == l,
                onSelected: (_) => onLevel(l),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _label('Días por semana'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final n in [2, 3, 4, 5, 6])
              ChoiceChip(
                label: Text('$n'),
                selected: days == n,
                onSelected: (_) => onDays(n),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _label('Tiempo por sesión'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final m in [30, 45, 60, 75, 90])
              ChoiceChip(
                label: Text(m == 90 ? '90+ min' : '$m min'),
                selected: minutes == m,
                onSelected: (_) => onMinutes(m),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _label('Equipamiento disponible'),
        const SizedBox(height: 2),
        Text(
          'Sin marcar nada se asume gimnasio completo.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final e in equipmentOptions)
              FilterChip(
                label: Text(e),
                selected: equipment.contains(e),
                onSelected: (sel) => onEquipment(e, sel),
              ),
          ],
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
          ...generated!.map((d) => _dayCard(context, d)),
        ],
      ],
    );
  }

  Widget _chip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCard(BuildContext context, RoutineDay d) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${d.day} · ${d.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${d.exercises.length} ej.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final e in d.exercises)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  '· ${e.exerciseName} — ${e.effectiveSets.length}x${e.reps}',
                  style: TextStyle(fontSize: 13, color: cs.onSurface),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      );
}
