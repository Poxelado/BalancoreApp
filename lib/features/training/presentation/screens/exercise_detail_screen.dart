import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/exercise.dart';
import '../../domain/strength_stats.dart';
import '../providers/strength_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/exercise_provider.dart';

/// Detalle de ejercicio: Guía | Estadísticas | Historial (estilo Hevy/similar).
class ExerciseDetailScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final String equipment;
  final String instructions;

  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    this.muscleGroup = '',
    this.equipment = '',
    this.instructions = '',
  });

  factory ExerciseDetailScreen.fromExercise(Exercise e) {
    return ExerciseDetailScreen(
      exerciseId: e.id,
      exerciseName: e.name,
      muscleGroup: e.muscleGroup,
      equipment: e.equipment,
      instructions: e.instructions,
    );
  }

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  int _periodDays = 30; // 1M
  /// true = volumen por sesión, false = peso máximo
  bool _showVolume = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _instructions {
    if (widget.instructions.trim().isNotEmpty) return widget.instructions;
    final cat = ExerciseCatalog.byId(widget.exerciseId);
    if (cat != null && cat.instructions.isNotEmpty) return cat.instructions;
    return 'Aún no hay descripción detallada para este ejercicio. '
        'Registra series en tus entrenamientos para ver estadísticas aquí.';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final favAsync = ref.watch(favoriteExerciseIdsProvider);
    final isFav = favAsync.valueOrNull?.contains(widget.exerciseId) ?? false;

    final statsArgs = (
    exerciseId: widget.exerciseId,
    name: widget.exerciseName,
    days: _periodDays > 365 ? 400 : _periodDays,
    );
    final statsAsync = ref.watch(exerciseStrengthStatsProvider(statsArgs));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exerciseName),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: isFav ? 'Quitar favorito' : 'Favorito',
            icon: Icon(isFav ? Icons.star : Icons.star_border),
            onPressed: () async {
              final user = ref.read(authServiceProvider).currentUser;
              if (user == null) return;
              await ref
                  .read(exerciseRepositoryProvider)
                  .toggleFavorite(user.uid, widget.exerciseId);
              ref.invalidate(favoriteExerciseIdsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Guía'),
            Tab(text: 'Estadísticas'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildGuide(primary),
          statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (stats) => _buildStats(primary, stats),
          ),
          statsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (stats) => _buildHistory(primary, stats),
          ),
        ],
      ),
    );
  }

  Widget _buildGuide(Color primary) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.fitness_center, size: 72, color: primary.withValues(alpha: 0.5)),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.muscleGroup.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.accessibility_new, size: 18),
                label: Text(widget.muscleGroup),
              ),
            if (widget.equipment.isNotEmpty)
              Chip(
                avatar: const Icon(Icons.sports_gymnastics, size: 18),
                label: Text(widget.equipment),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Cómo hacerlo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _instructions,
          style: const TextStyle(fontSize: 15, height: 1.45),
        ),
      ],
    );
  }

  Widget _buildStats(Color primary, ExerciseStrengthStats stats) {
    final points = stats.inPeriod(_periodDays);
    final avgVol = points.isEmpty
        ? 0.0
        : points.fold<double>(0, (a, p) => a + p.volume) / points.length;
    final best = points.isEmpty
        ? null
        : points.reduce((a, b) => a.maxWeight >= b.maxWeight ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart, color: primary),
            const SizedBox(width: 8),
            const Text(
              'Tus estadísticas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Métrica + periodo
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<bool>(
                value: _showVolume,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  labelText: 'Métrica',
                ),
                items: const [
                  DropdownMenuItem(value: true, child: Text('Volumen por sesión')),
                  DropdownMenuItem(value: false, child: Text('Peso máximo')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _showVolume = v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _periodDays,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  labelText: 'Periodo',
                ),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('1 mes')),
                  DropdownMenuItem(value: 90, child: Text('3 meses')),
                  DropdownMenuItem(value: 180, child: Text('6 meses')),
                  DropdownMenuItem(value: 365, child: Text('1 año')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _periodDays = v);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (points.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Sin datos en este periodo.\nCompleta series con peso en tus entrenamientos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else ...[
          Text(
            _showVolume
                ? '${_fmtVol(avgVol)} kg  ·  media / sesión'
                : '${_fmtW(best!.maxWeight)} kg  ·  mejor peso',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (points.length / 4).clamp(1, 10).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final d = points[i].date;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${d.day}/${d.month}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, _) => Text(
                        v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < points.length; i++)
                        FlSpot(
                          i.toDouble(),
                          _showVolume ? points[i].volume : points[i].maxWeight,
                        ),
                    ],
                    isCurved: true,
                    color: primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: primary.withValues(alpha: 0.15),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touched) {
                      return touched.map((t) {
                        final i = t.x.round();
                        if (i < 0 || i >= points.length) return null;
                        final p = points[i];
                        final label = _showVolume
                            ? '${_fmtVol(p.volume)} kg vol'
                            : '${_fmtW(p.maxWeight)} kg × ${p.repsAtMax}';
                        return LineTooltipItem(
                          '${p.date.day}/${p.date.month}\n$label',
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tus récords personales',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          const SizedBox(height: 8),
          _recordTile(
            Icons.emoji_events,
            'Mejor peso',
            best == null
                ? '—'
                : '${_fmtW(best.maxWeight)} kg × ${best.repsAtMax}',
            primary,
          ),
          _recordTile(
            Icons.stacked_line_chart,
            'Mejor volumen (sesión)',
            points.isEmpty
                ? '—'
                : '${_fmtVol(points.map((p) => p.volume).reduce((a, b) => a > b ? a : b))} kg',
            primary,
          ),
          _recordTile(
            Icons.fitness_center,
            'Sesiones registradas',
            '${points.length}',
            primary,
          ),
        ],
      ],
    );
  }

  Widget _buildHistory(Color primary, ExerciseStrengthStats stats) {
    final points = stats.inPeriod(_periodDays).reversed.toList();
    if (points.isEmpty) {
      return Center(
        child: Text(
          'Sin historial aún',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: points.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = points[i];
        final date =
            '${p.date.day.toString().padLeft(2, '0')}/${p.date.month.toString().padLeft(2, '0')}/${p.date.year}';
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: primary.withValues(alpha: 0.12),
            child: Icon(Icons.fitness_center, color: primary, size: 20),
          ),
          title: Text(
            p.maxWeight > 0
                ? '${_fmtW(p.maxWeight)} kg × ${p.repsAtMax}'
                : '${p.completedSets} series',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '$date · Vol ${_fmtVol(p.volume)} kg · ${p.completedSets} series',
          ),
        );
      },
    );
  }

  Widget _recordTile(IconData icon, String label, String value, Color primary) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: primary),
      title: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  String _fmtW(double w) {
    if (w == w.roundToDouble()) return '${w.toInt()}';
    return w.toStringAsFixed(1);
  }

  String _fmtVol(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(2)} mil';
    if (v == v.roundToDouble()) return '${v.toInt()}';
    return v.toStringAsFixed(0);
  }
}
