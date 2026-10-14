import 'package:flutter/material.dart';
import '../../../profile/domain/user_profile.dart';
import '../../domain/progression_rules.dart';
import 'exercise_list_widgets.dart';
import '../../../../core/theme/app_theme.dart';

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

  /// Si no es null, muestra un botón "+" al final para añadir ejercicios.
  final VoidCallback? onAdd;

  const ExerciseSelectorStrip({
    super.key,
    required this.exercises,
    required this.selectedIndex,
    required this.primary,
    required this.cardBg,
    required this.onSelect,
    this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final hasAdd = onAdd != null;
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: exercises.length + (hasAdd ? 1 : 0),
        itemBuilder: (context, i) {
          if (hasAdd && i == exercises.length) {
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primary.withValues(alpha: 0.08),
                          border: Border.all(
                            color: primary.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(Icons.add, color: accentOf(context), size: 26),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Añadir',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: accentOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final e = exercises[i];
          final selected = i == selectedIndex;
          final allDone = e.sets.isNotEmpty && e.sets.every((s) => s.completed);
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected
                            ? primary
                            : (allDone
                                ? AppSemanticColors.of(context).success.withValues(alpha: 0.3)
                                : cardBg),
                        border: Border.all(
                          color: selected
                              ? primary
                              : Colors.grey.withValues(alpha: 0.3),
                          width: selected ? 2.5 : 1,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ExerciseThumb(
                            exerciseId: e.exerciseId,
                            size: 56,
                            circular: true,
                          ),
                          if (allDone)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppSemanticColors.of(context).success,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check,
                                    size: 11, color: Colors.white),
                              ),
                            ),
                          if (e.hasSuperset)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.link,
                                    size: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondary),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.exerciseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? primary : Colors.grey.shade600,
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExerciseBanner(
            exerciseId: ex.exerciseId,
            name: ex.exerciseName,
            muscleGroup: ex.muscleGroup,
            onTap: onOpenDetail,
          ),
          if (supersetPartner != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _supersetChip(context, supersetPartner!),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: onEditRest,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 2, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined, size: 16, color: accentOf(context)),
                      const SizedBox(width: 4),
                      Text(
                        'Descanso ${fmtRest(ex.restSeconds > 0 ? ex.restSeconds : 60)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accentOf(context),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.edit, size: 14, color: accentOf(context)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Superset',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  ex.hasSuperset ? Icons.link : Icons.link_off,
                  color: ex.hasSuperset
                      ? Theme.of(context).colorScheme.secondary
                      : primary,
                ),
                onPressed: onEditSuperset,
              ),
              IconButton(
                tooltip: 'Notas del ejercicio',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  ex.notes.isEmpty
                      ? Icons.note_add_outlined
                      : Icons.sticky_note_2,
                  color: accentOf(context),
                ),
                onPressed: onEditNotes,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _rpeCard(context),
        ],
      ),
    );
  }

  Widget _supersetChip(BuildContext context, String partner) {
    final secondary = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: secondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link, size: 13, color: secondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Superset con $partner',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Selector de esfuerzo percibido (RPE) 1–10, con color por intensidad,
  /// descriptores y reps en reserva (RIR) para una lectura realista.
  Widget _rpeCard(BuildContext context) {
    final accent = accentOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                'Esfuerzo percibido',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Text(
                ex.rpe != null ? '${ex.rpe} · ${rpeLabel(ex.rpe!)}' : 'Sin marcar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: ex.rpe != null ? FontWeight.w700 : FontWeight.w500,
                  color: ex.rpe != null ? rpeColor(ex.rpe!) : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var r = 1; r <= 10; r++) ...[
                if (r > 1) const SizedBox(width: 3),
                Expanded(child: _rpeCell(context, r)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4CAF50),
                  Color(0xFF8BC34A),
                  Color(0xFFFFC107),
                  Color(0xFFFF9800),
                  Color(0xFFE53935),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Fácil',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              const Spacer(),
              Flexible(
                child: Text(
                  _rpeHint(ex.rpe),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const Spacer(),
              Text('Máximo',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rpeCell(BuildContext context, int r) {
    final selected = ex.rpe == r;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? rpeColor(r)
          : (dark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05)),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSetRpe(r),
        child: SizedBox(
          height: 34,
          child: Center(
            child: Text(
              '$r',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey.shade500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _rpeHint(int? rpe) {
    if (rpe == null) return 'Toca tu esfuerzo';
    final rir = (10 - rpe).clamp(0, 10);
    if (rir == 0) return 'Al fallo · 0 reps en reserva';
    if (rir == 1) return '1 rep en reserva';
    return '$rir reps en reserva';
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
            (suggestion.isIncrease ? AppSemanticColors.of(context).success : primary).withValues(
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
                color: suggestion.isIncrease ? AppSemanticColors.of(context).success : primary,
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

/// Descanso activo entre series, como tarjeta flotante (popup) con anillo de
/// cuenta atrás. Aparece sobre el listado de series y se puede ajustar o saltar.
class RestBanner extends StatelessWidget {
  final int remaining;
  final int total;
  final Color primary;
  final VoidCallback onSkip;
  final ValueChanged<int> onAdjust;

  const RestBanner({
    super.key,
    required this.remaining,
    this.total = 0,
    required this.primary,
    required this.onSkip,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    final denom = total > 0 ? total : (remaining > 0 ? remaining : 1);
    final progress = (remaining / denom).clamp(0.0, 1.0);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 4,
                    color: accent,
                    backgroundColor: accent.withValues(alpha: 0.15),
                  ),
                  Center(
                    child: Icon(Icons.hourglass_bottom, size: 18, color: accent),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DESCANSO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  fmtRest(remaining),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: accent,
                    fontSize: 20,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Quitar 15s',
              visualDensity: VisualDensity.compact,
              onPressed: () => onAdjust(-15),
              icon: Icon(Icons.remove_circle_outline, color: accent, size: 22),
            ),
            IconButton(
              tooltip: 'Añadir 15s',
              visualDensity: VisualDensity.compact,
              onPressed: () => onAdjust(15),
              icon: Icon(Icons.add_circle_outline, color: accent, size: 22),
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
  /// Etiqueta de récord personal (p. ej. "PR · Peso") o null si la serie no
  /// es récord.
  final String? prLabel;

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
    this.prLabel,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = setTypeColor(s.type);
    final oneRm = estimated1RM(s.weight, s.reps);

    return Dismissible(
      key: ValueKey(dismissKey),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Theme.of(context).colorScheme.error,
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
          color: s.completed ? AppSemanticColors.of(context).success.withValues(alpha: 0.08) : null,
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
                if (prLabel != null)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppDataColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppDataColors.gold, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events,
                              size: 11, color: AppDataColors.gold),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              prLabel!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppDataColors.gold,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
                tooltip: 'Marcar serie',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: onToggle,
                icon: Icon(
                  s.completed ? Icons.check_circle : Icons.check_circle_outline,
                  color: s.completed ? AppSemanticColors.of(context).success : Colors.grey,
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

/// Confirmación al terminar el entrenamiento: resume lo hecho hasta ahora
/// (tiempo, series, volumen) y avisa si quedan series sin marcar.
class FinishWorkoutDialog extends StatelessWidget {
  final int durationSeconds;
  final int completedSets;
  final int totalSets;
  final double volume;

  const FinishWorkoutDialog({
    super.key,
    required this.durationSeconds,
    required this.completedSets,
    required this.totalSets,
    required this.volume,
  });

  static String _duration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}min';
    return '${s}s';
  }

  static String _kg(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}t';
    if (v == v.roundToDouble()) return '${v.toInt()}';
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    final sem = AppSemanticColors.of(context);
    final missing = totalSets - completedSets;
    final allDone = missing <= 0;
    final tone = allDone ? sem.success : sem.warning;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.flag_rounded, color: accent, size: 30),
          ),
          const SizedBox(height: 12),
          const Text(
            'Terminar entrenamiento',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(allDone ? Icons.check_circle : Icons.error_outline,
                    size: 18, color: tone),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    allDone
                        ? 'Completaste todas las series.'
                        : 'Te quedan $missing ${missing == 1 ? 'serie' : 'series'} sin marcar.',
                    style: TextStyle(fontWeight: FontWeight.w600, color: tone),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _mini(context, Icons.timer_outlined,
                    _duration(durationSeconds), 'Tiempo'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mini(context, Icons.check_circle_outline,
                    '$completedSets/$totalSets', 'Series'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _mini(context, Icons.fitness_center,
                    '${_kg(volume)} kg', 'Volumen'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Seguir'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: const Text('Finalizar'),
        ),
      ],
    );
  }

  Widget _mini(
      BuildContext context, IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: accentOf(context)),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
