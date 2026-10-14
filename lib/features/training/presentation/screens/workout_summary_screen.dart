import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../domain/personal_records.dart';
import '../../domain/session_stats.dart';
import '../../../profile/domain/user_profile.dart';
import '../widgets/exercise_list_widgets.dart';
import '../../../../core/theme/app_theme.dart';

/// Resumen de una sesión recién terminada: qué se hizo (con el detalle de
/// series por ejercicio), cómo se comparó con la sesión anterior y qué
/// récords se batieron.
class WorkoutSummaryScreen extends StatelessWidget {
  final SessionStats stats;
  final List<PersonalRecord> records;
  final String title;
  final int calories;

  /// Sesión completada, para el desglose ejercicio por ejercicio. Opcional.
  final WorkoutSession? session;

  const WorkoutSummaryScreen({
    super.key,
    required this.stats,
    this.records = const [],
    this.title = 'Entrenamiento completado',
    this.calories = 0,
    this.session,
  });

  static const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static String _fmtDate(DateTime d) {
    final wd = _weekdays[d.weekday - 1];
    final mo = _months[d.month - 1];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$wd ${d.day} $mo · $hh:$mm';
  }

  Color _colorFor(BuildContext context, int i) {
    final s = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    final palette = [
      s.primary,
      sem.info,
      sem.success,
      sem.warning,
      s.secondary,
      sem.rest,
      s.tertiary,
      s.primaryContainer,
    ];
    return palette[i % palette.length];
  }

  static Color _setColor(BuildContext context, SetType type) {
    final s = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    return switch (type) {
      SetType.normal => s.primary,
      SetType.warmup => sem.info,
      SetType.dropset => sem.warning,
      SetType.failure => s.error,
    };
  }

  static String _fmtDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  static String _fmtKg(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)} t';
    if (v == v.roundToDouble()) return '${v.toInt()}';
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentOf(context);
    final session = this.session;

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _header(context),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _stat(
                    icon: Icons.timer_outlined,
                    label: 'Duración',
                    value: _fmtDuration(stats.durationSeconds),
                    primary: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _stat(
                    icon: Icons.check_circle_outline,
                    label: 'Series',
                    value: '${stats.completedSets}/${stats.totalSets}',
                    primary: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _stat(
                    icon: Icons.fitness_center,
                    label: 'Volumen',
                    value: '${_fmtKg(stats.totalVolume)} kg',
                    primary: accent,
                  ),
                ),
              ],
            ),
            if (stats.hasPrevious) ...[
              const SizedBox(height: 10),
              _comparison(context, accent),
            ],
            if (calories > 0) ...[
              const SizedBox(height: 10),
              _caloriesCard(),
            ],
            if (session != null && session.exercises.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle('Ejercicios', Icons.list_alt, accent),
              const SizedBox(height: 8),
              for (final ex in session.exercises) _exerciseCard(context, ex),
            ],
            if (records.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle('Récords personales', Icons.emoji_events, accent),
              const SizedBox(height: 8),
              for (final r in records) _recordRow(r),
            ],
            if (stats.volumeByMuscle.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sectionTitle(
                  'Distribución por músculo', Icons.donut_large, accent),
              const SizedBox(height: 8),
              _muscleDonut(context),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Listo'),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final accent = accentOf(context);
    final started = session?.startedAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_rounded, size: 42, color: accent),
          const SizedBox(height: 10),
          Text(
            '¡$title! 🎉',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: accent,
            ),
          ),
          if (started != null) ...[
            const SizedBox(height: 4),
            Text(
              _fmtDate(started),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _caloriesCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppDataColors.calories.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppDataColors.calories.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0x22FF9800),
              child: Icon(
                Icons.local_fire_department,
                color: AppDataColors.calories,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gasto estimado',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppDataColors.calories,
                    ),
                  ),
                  Text(
                    '≈ $calories kcal',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Sumado a tu gasto de hoy',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _exerciseCard(BuildContext context, WorkoutExerciseLog ex) {
    final key = ex.exerciseId.isNotEmpty ? ex.exerciseId : ex.exerciseName;
    final recCount = records
        .where((r) =>
            (r.exerciseId.isNotEmpty ? r.exerciseId : r.exerciseName) == key)
        .length;
    final doneSets = ex.sets.where((s) => s.completed).length;
    final meta = [
      if (ex.muscleGroup.trim().isNotEmpty) ex.muscleGroup.trim(),
      '$doneSets/${ex.sets.length} series',
      if (ex.rpe != null) 'RPE ${ex.rpe}',
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                ExerciseThumb(
                    exerciseId: ex.exerciseId, size: 40, circular: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.exerciseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (recCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppDataColors.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events,
                            size: 13, color: AppDataColors.gold),
                        const SizedBox(width: 4),
                        Text(
                          '$recCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppDataColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              children: [for (final s in ex.sets) _setRow(context, s)],
            ),
          ),
          if (ex.notes.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: 15, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ex.notes.trim(),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _setRow(BuildContext context, WorkoutSetLog s) {
    final color = _setColor(context, s.type);
    final sem = AppSemanticColors.of(context);
    final grey = Colors.grey.shade600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${s.setNumber}',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                Text(
                  s.weight > 0 ? '${_fmtKg(s.weight)} kg' : 'Corporal',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: s.completed ? null : grey,
                  ),
                ),
                if (s.reps > 0) ...[
                  Text('×', style: TextStyle(color: grey)),
                  Text(
                    '${s.reps}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: s.completed ? null : grey,
                    ),
                  ),
                  Text('reps', style: TextStyle(fontSize: 11, color: grey)),
                ],
                if (s.type != SetType.normal)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      s.type.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (s.note.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.sticky_note_2_outlined,
                  size: 15, color: Colors.grey.shade500),
            ),
          Icon(
            s.completed ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: s.completed ? sem.success : Colors.grey.shade400,
          ),
        ],
      ),
    );
  }

  Widget _recordRow(PersonalRecord r) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppDataColors.gold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppDataColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: AppDataColors.gold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${r.exerciseName} · ${r.label}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              _fmtKg(r.value),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppDataColors.gold,
              ),
            ),
          ],
        ),
      );

  Widget _sectionTitle(String text, IconData icon, Color primary) => Row(
        children: [
          Icon(icon, size: 18, color: primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      );

  Widget _stat({
    required IconData icon,
    required String label,
    required String value,
    required Color primary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: primary),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _comparison(BuildContext context, Color primary) {
    final delta = stats.volumeDelta ?? 0;
    final up = stats.volumeImproved;
    final pct = stats.volumeDeltaPercent;
    final sem = AppSemanticColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (up ? sem.success : sem.warning).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            up ? Icons.trending_up : Icons.trending_down,
            color: up ? sem.success : sem.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              up
                  ? 'Mejor que la sesión anterior'
                  : 'Por debajo de la sesión anterior',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${up ? '+' : ''}${_fmtKg(delta.abs())} kg'
            '${pct == null ? '' : ' (${pct.abs().toStringAsFixed(0)}%)'}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: up ? sem.success : sem.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _muscleDonut(BuildContext context) {
    final entries = stats.volumeByMuscle.entries.toList();
    // Con muchos grupos, el donut se vuelve ilegible: se agrupa la cola.
    final shown = entries.take(5).toList();
    final restTotal = entries.length > 5
        ? entries.skip(5).fold<double>(0, (s, e) => s + e.value)
        : 0.0;
    final slices = <({String label, double value, Color color})>[
      for (var i = 0; i < shown.length; i++)
        (label: shown[i].key, value: shown[i].value, color: _colorFor(context, i)),
      if (restTotal > 0)
        (label: 'Otros', value: restTotal, color: _colorFor(context, shown.length)),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Semantics(
              label: 'Distribución de series por grupo muscular',
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                  sections: [
                    for (final s in slices)
                      PieChartSectionData(
                        value: s.value,
                        color: s.color,
                        radius: 34,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in slices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(s.label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                        ),
                        Text('${_fmtKg(s.value)} kg',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
