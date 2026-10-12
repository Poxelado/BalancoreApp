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
                child: Icon(
                  allDone ? Icons.check : Icons.fitness_center,
                  color: selected
                      ? Colors.white
                      : (allDone ? Colors.green : Colors.grey),
                  size: 22,
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
  final VoidCallback onOpenDetail;
  final VoidCallback onEditRest;
  final VoidCallback onEditNotes;
  final ValueChanged<int> onSetRpe;

  const ExerciseHeaderCard({
    super.key,
    required this.ex,
    required this.primary,
    required this.onOpenDetail,
    required this.onEditRest,
    required this.onEditNotes,
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
          IconButton(
            tooltip: 'Notas del ejercicio',
            icon: Icon(
              ex.notes.isEmpty ? Icons.note_add_outlined : Icons.sticky_note_2,
              color: primary,
            ),
            onPressed: onEditNotes,
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

/// Fila de una serie: número, previa, peso, reps y marcar completada.
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
    required this.onToggle,
    required this.onDismissed,
    required this.confirmDismiss,
  });

  @override
  Widget build(BuildContext context) {
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
      child: Container(
        color: s.completed ? Colors.green.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text('${s.setNumber}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: s.completed ? Colors.green : null,
                  )),
            ),
            Expanded(
              flex: 3,
              child: Text(previa,
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13)),
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
              width: 40,
              child: IconButton(
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
    );
  }
}

String fmtRest(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
  return '${s}s';
}
