import 'package:flutter/material.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/progression_rules.dart';
import 'exercise_list_widgets.dart';

String rpeLabel(int r) {
  if (r <= 3) return 'Muy fácil';
  if (r <= 5) return 'Moderado';
  if (r <= 7) return 'Exigente';
  if (r <= 9) return 'Muy duro';
  return 'Máximo';
}

Color rpeColor(int r) {
  if (r <= 3) return const Color(0xFF4CAF50);
  if (r <= 5) return const Color(0xFF8BC34A);
  if (r <= 6) return const Color(0xFFFFC107);
  if (r <= 8) return const Color(0xFFFF9800);
  return const Color(0xFFE53935);
}

/// Selector horizontal de ejercicios de la sesión (círculos).
class ExerciseSelectorStrip extends StatelessWidget {
  final List<WorkoutExerciseLog> exercises;
  final int selectedIndex;
  final Color primary;
  final Color cardBg;
  final ValueChanged<int> onSelect;

  const ExerciseSelectorStrip({
    super.key,
    required this.exercises,
    required this.selectedIndex,
    required this.primary,
    required this.cardBg,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: exercises.length,
        itemBuilder: (context, i) {
          final e = exercises[i];
          final selected = i == selectedIndex;
          final allDone = e.sets.isNotEmpty && e.sets.every((s) => s.completed);
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? primary
                      : (allDone
                          ? Colors.green.withValues(alpha: 0.3)
                          : cardBg),
                  border: Border.all(
                    color: selected
                        ? primary
                        : Colors.grey.withValues(alpha: 0.3),
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        allDone ? Icons.check : Icons.fitness_center,
                        color: selected
                            ? Colors.white
                            : (allDone ? Colors.green : Colors.grey),
                        size: 22,
                      ),
                    ),
                    if (e.hasSuperset)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.deepPurple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.link,
                              size: 11, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Encabezado del ejercicio activo: nombre, grupo, descanso y selector RPE.
class ExerciseHeaderCard extends StatelessWidget {
  final WorkoutExerciseLog ex;
  final Color primary;
  final String? supersetPartner;
  final VoidCallback onOpenDetail;
  final VoidCallback onEditRest;
  final VoidCallback onEditNotes;
  final VoidCallback onEditSuperset;
  final ValueChanged<int> onSetRpe;

  const ExerciseHeaderCard({
    super.key,
    required this.ex,
    required this.primary,
    this.supersetPartner,
    required this.onOpenDetail,
    required this.onEditRest,
    required this.onEditNotes,
    required this.onEditSuperset,
    required this.onSetRpe,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: ExerciseThumb(exerciseId: ex.exerciseId, size: 44),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onOpenDetail,
                  child: Text(
                    ex.exerciseName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (ex.muscleGroup.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      ex.muscleGroup,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                if (supersetPartner != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link,
                              size: 13, color: Colors.deepPurple),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Superset con $supersetPartner',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: onEditRest,
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: primary),
                      const SizedBox(width: 4),
                      Text(
                        'Descanso ${fmtRest(ex.restSeconds > 0 ? ex.restSeconds : 60)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                      Icon(Icons.edit, size: 14, color: primary),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // RPE compacto: una fila 1–10 sin scroll
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.speed, size: 16, color: primary),
                          const SizedBox(width: 6),
                          Text(
                            'RPE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            ex.rpe != null
                                ? '${ex.rpe} · ${rpeLabel(ex.rpe!)}'
                                : 'Esfuerzo percibido',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var r = 1; r <= 10; r++) ...[
                            if (r > 1) const SizedBox(width: 3),
                            Expanded(
                              child: Material(
                                color: ex.rpe == r
                                    ? rpeColor(r)
                                    : (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.06)),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => onSetRpe(r),
                                  child: SizedBox(
                                    height: 32,
                                    child: Center(
                                      child: Text(
                                        '$r',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: ex.rpe == r
                                              ? Colors.white
                                              : Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fácil',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Text(
                            'Máximo',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Superset',
                icon: Icon(
                  ex.hasSuperset ? Icons.link : Icons.link_off,
                  color:
                      ex.hasSuperset ? Colors.deepPurple : primary,
                ),
                onPressed: onEditSuperset,
              ),
              IconButton(
                tooltip: 'Notas del ejercicio',
                icon: Icon(
                  ex.notes.isEmpty
                      ? Icons.note_add_outlined
                      : Icons.sticky_note_2,
                  color: primary,
                ),
                onPressed: onEditNotes,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Banner de sugerencia de progresión (doble progresión).
class ProgressionBanner extends StatelessWidget {
  final ProgressionSuggestion suggestion;
  final Color primary;
  final VoidCallback onApply;

  const ProgressionBanner({
    super.key,
    required this.suggestion,
    required this.primary,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        color:
            (suggestion.isIncrease ? Colors.green : primary).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                suggestion.isIncrease ? Icons.trending_up : Icons.history,
                size: 20,
                color: suggestion.isIncrease ? Colors.green : primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  suggestion.message,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: onApply,
                child: const Text('Aplicar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Franja de descanso activo entre series.
class RestBanner extends StatelessWidget {
  final int remaining;
  final Color primary;
  final VoidCallback onSkip;

  const RestBanner({
    super.key,
    required this.remaining,
    required this.primary,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: primary.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.hourglass_bottom, color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Descanso · ${fmtRest(remaining)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primary,
                  fontSize: 16,
                ),
              ),
            ),
            TextButton(onPressed: onSkip, child: const Text('Saltar')),
          ],
        ),
      ),
    );
  }
}

/// Color asociado a cada tipo de serie.
Color setTypeColor(SetType t) => switch (t) {
      SetType.normal => const Color(0xFF9E9E9E),
      SetType.warmup => const Color(0xFF42A5F5),
      SetType.dropset => const Color(0xFFAB47BC),
      SetType.failure => const Color(0xFFE53935),
    };

/// 1RM estimado (fórmula de Epley). Devuelve null si no hay datos válidos.
double? estimated1RM(double weight, int reps) {
  if (weight <= 0 || reps <= 0) return null;
  if (reps <= 1) return weight;
  return weight * (1 + reps / 30);
}

String fmt1RM(double? v) {
  if (v == null) return '—';
  return '${v.round()} kg';
}

/// Fila de una serie: tipo, previa + 1RM, peso, reps, nota y completar.
/// Se puede deslizar para borrar (confirmación delegada al padre).
class SetLogRow extends StatelessWidget {
  final String dismissKey;
  final WorkoutSetLog s;
  final TextEditingController weightCtrl;
  final TextEditingController repsCtrl;
  final String previa;
  final String? hintW;
  final String? hintR;
  final Color cardBg;
  final ValueChanged<String> onWeightChanged;
  final ValueChanged<String> onRepsChanged;
  final ValueChanged<SetType> onChangeType;
  final VoidCallback onEditNote;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;
  final VoidCallback onDismissed;
  final Future<bool> Function() confirmDismiss;

  const SetLogRow({
    super.key,
    required this.dismissKey,
    required this.s,
    required this.weightCtrl,
    required this.repsCtrl,
    required this.previa,
    required this.hintW,
    required this.hintR,
    required this.cardBg,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onChangeType,
    required this.onEditNote,
    required this.onLongPress,
    required this.onToggle,
    required this.onDismissed,
    required this.confirmDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = setTypeColor(s.type);
    final oneRm = estimated1RM(s.weight, s.reps);

    return Dismissible(
      key: ValueKey(dismissKey),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Colors.red.shade700,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.red.shade700,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => confirmDismiss(),
      onDismissed: (_) => onDismissed(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: Container(
        decoration: BoxDecoration(
          color: s.completed ? Colors.green.withValues(alpha: 0.08) : null,
          border: Border(left: BorderSide(color: typeColor, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            _typeBadge(),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(previa,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13)),
                  if (s.type != SetType.normal || oneRm != null)
                    Text(
                      [
                        if (s.type != SetType.normal) s.type.label,
                        if (oneRm != null) '1RM ${fmt1RM(oneRm)}',
                      ].join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: s.type != SetType.normal
                            ? typeColor
                            : Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: weightCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: s.completed
                        ? null
                        : (weightCtrl.text.isEmpty ? Colors.grey : null),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: s.completed ? null : hintW,
                    hintStyle: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: onWeightChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: repsCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: s.completed
                        ? null
                        : (repsCtrl.text.isEmpty ? Colors.grey : null),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: s.completed ? null : hintR,
                    hintStyle: TextStyle(
                      color: Colors.grey.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: onRepsChanged,
                ),
              ),
            ),
            SizedBox(
              width: 34,
              child: IconButton(
                tooltip: 'Nota de la serie',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: onEditNote,
                icon: Icon(
                  s.note.isEmpty
                      ? Icons.sticky_note_2_outlined
                      : Icons.sticky_note_2,
                  size: 18,
                  color: s.note.isEmpty ? Colors.grey : typeColor,
                ),
              ),
            ),
            SizedBox(
              width: 38,
              child: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: onToggle,
                icon: Icon(
                  s.completed ? Icons.check_circle : Icons.check_circle_outline,
                  color: s.completed ? Colors.green : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _typeBadge() {
    return PopupMenuButton<SetType>(
      tooltip: 'Tipo de serie',
      padding: EdgeInsets.zero,
      onSelected: onChangeType,
      itemBuilder: (ctx) => [
        for (final t in SetType.values)
          PopupMenuItem<SetType>(
            value: t,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: setTypeColor(t),
                  child: Text(t.short,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text(t.label),
              ],
            ),
          ),
      ],
      child: CircleAvatar(
        radius: 15,
        backgroundColor: setTypeColor(s.type),
        child: Text(
          '${s.setNumber}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

String fmtRest(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}
