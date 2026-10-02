import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';

enum _Metric { calories, water, sleep, macros }

bool _logHasData(DailyLog log) {
  return log.waterGlasses > 0 ||
      log.sleepHours > 0 ||
      log.consumedCalories > 0 ||
      log.proteinGrams > 0 ||
      log.carbsGrams > 0 ||
      log.fatGrams > 0 ||
      log.meals.isNotEmpty;
}

class DailyHistoryScreen extends ConsumerStatefulWidget {
  final bool embedded;
  final int? fixedDays;

  const DailyHistoryScreen({
    super.key,
    this.embedded = false,
    this.fixedDays,
  });

  @override
  ConsumerState<DailyHistoryScreen> createState() => _DailyHistoryScreenState();
}

class _DailyHistoryScreenState extends ConsumerState<DailyHistoryScreen> {
  late int _days;
  _Metric? _selected;
  String? _expandedMonth;

  static const _ranges = <(int, String, String)>[
    (7, '1 semana', 'Última semana'),
    (30, '1 mes', 'Último mes'),
    (90, '3 meses', 'Últimos 3 meses'),
    (180, '6 meses', 'Últimos 6 meses'),
    (365, '1 año', 'Último año'),
  ];

  @override
  void initState() {
    super.initState();
    _days = widget.fixedDays ?? 30;
  }

  @override
  void didUpdateWidget(covariant DailyHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fixedDays != null && widget.fixedDays != _days) {
      setState(() => _days = widget.fixedDays!);
    }
  }

  String get _rangeLabel {
    for (final r in _ranges) {
      if (r.$1 == _days) return r.$2;
    }
    return '$_days d';
  }

  String get _rangeTitle {
    for (final r in _ranges) {
      if (r.$1 == _days) return r.$3;
    }
    return 'Rango';
  }

  Future<void> _pickRange() async {
    if (widget.fixedDays != null) return;
    final primary = Theme.of(context).colorScheme.primary;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.date_range, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Seleccionar rango',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final r in _ranges)
              ListTile(
                title: Text(r.$2),
                subtitle: Text(r.$3),
                trailing: _days == r.$1
                    ? Icon(Icons.check, color: primary)
                    : null,
                onTap: () => Navigator.pop(ctx, r.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) setState(() => _days = chosen);
  }

  Widget _rangeDropdown() {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.fixedDays != null ? null : _pickRange,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rango',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _rangeLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  if (widget.fixedDays == null)
                    Icon(Icons.expand_more, size: 18, color: primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _calColor = Color(0xFFFF9800);
  static const _waterColor = Color(0xFF2196F3);
  static const _sleepColor = Color(0xFF9E9E9E);
  static const _proteinColor = Color(0xFF4CAF50);
  static const _carbsColor = Color(0xFFFFC107);
  static const _fatColor = Color(0xFFE91E63);

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(dailyLogsHistoryProvider(_days));
    final primary = Theme.of(context).colorScheme.primary;
    final groupByMonth = _days >= 90;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(widget.embedded ? 8 : 16, 12, widget.embedded ? 8 : 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _rangeTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          _rangeDropdown(),
        ],
      ),
    );

    final content = historyAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (logsDesc) {
        final logs = logsDesc.where(_logHasData).toList();
        final logsAsc = [...logs]..sort((a, b) => a.date.compareTo(b.date));

        if (logs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay días con registros en este rango.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView(
          shrinkWrap: widget.embedded,
          physics: widget.embedded
              ? const NeverScrollableScrollPhysics()
              : null,
          padding: widget.embedded
              ? const EdgeInsets.fromLTRB(8, 0, 8, 8)
              : const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _MetricSelector(
              selected: _selected,
              onSelect: (m) {
                setState(() {
                  _selected = _selected == m ? null : m;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              _chartTitle(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: _HistoryChart(
                logs: logsAsc,
                selected: _selected,
              ),
            ),
            const SizedBox(height: 8),
            _legend(),
            const SizedBox(height: 20),
            Text(
              groupByMonth
                  ? 'Meses del rango'
                  : 'Registros del rango',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            const SizedBox(height: 10),
            if (groupByMonth)
              ..._buildMonthSections(logs)
            else
              ...logs.map(
                    (log) => _HistoryRow(
                  log: log,
                  filter: _selected,
                  onEdit: () => _editLog(log),
                ),
              ),
          ],
        );
      },
    );

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          content,
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de hábitos'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          header,
          const Divider(height: 1),
          Expanded(child: content),
        ],
      ),
    );
  }

  String _chartTitle() {
    if (_selected == null) return 'Resumen del periodo';
    return switch (_selected!) {
      _Metric.calories => 'Calorías',
      _Metric.water => 'Agua',
      _Metric.sleep => 'Sueño',
      _Metric.macros => 'Macros (P / C / G)',
    };
  }

  Widget _legend() {
    if (_selected == null) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendDot(color: _calColor, label: 'Kcal'),
          SizedBox(width: 10),
          _LegendDot(color: _waterColor, label: 'Agua'),
          SizedBox(width: 10),
          _LegendDot(color: _sleepColor, label: 'Sueño'),
          SizedBox(width: 10),
          _LegendDot(color: _proteinColor, label: 'Macros*'),
        ],
      );
    }
    if (_selected == _Metric.macros) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendDot(color: _proteinColor, label: 'Proteína'),
          SizedBox(width: 12),
          _LegendDot(color: _carbsColor, label: 'Carbos'),
          SizedBox(width: 12),
          _LegendDot(color: _fatColor, label: 'Grasas'),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  List<Widget> _buildMonthSections(List<DailyLog> logsDesc) {
    // logsDesc: más reciente primero
    final byMonth = <String, List<DailyLog>>{};
    for (final log in logsDesc) {
      final key = log.date.length >= 7 ? log.date.substring(0, 7) : log.date;
      byMonth.putIfAbsent(key, () => []).add(log);
    }
    final months = byMonth.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // reciente primero

    return months.map((monthKey) {
      final days = byMonth[monthKey]!;
      final expanded = _expandedMonth == monthKey;
      final label = _monthLabel(monthKey);
      final primary = Theme.of(context).colorScheme.primary;

      // resumen mes
      final totalCal =
      days.fold<int>(0, (s, l) => s + l.consumedCalories);
      final totalWater =
      days.fold<int>(0, (s, l) => s + l.waterGlasses);
      final avgSleep = days.isEmpty
          ? 0.0
          : days.fold<double>(0, (s, l) => s + l.sleepHours) / days.length;

      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            ListTile(
              title: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${days.length} días · ${totalCal} kcal · ${totalWater} vasos · ${avgSleep.toStringAsFixed(1)} h sueño',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: primary,
              ),
              onTap: () {
                setState(() {
                  _expandedMonth = expanded ? null : monthKey;
                });
              },
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Column(
                  children: days
                      .map(
                        (log) => _HistoryRow(
                      log: log,
                      filter: _selected,
                      onEdit: () => _editLog(log),
                    ),
                  )
                      .toList(),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  String _monthLabel(String yyyyMm) {
    final parts = yyyyMm.split('-');
    if (parts.length < 2) return yyyyMm;
    const names = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    final m = int.tryParse(parts[1]) ?? 0;
    final name = (m >= 1 && m <= 12) ? names[m] : parts[1];
    return '$name ${parts[0]}';
  }

  Future<void> _editLog(DailyLog log) async {
    final calCtrl =
    TextEditingController(text: '${log.consumedCalories}');
    final waterCtrl =
    TextEditingController(text: '${log.waterGlasses}');
    final sleepCtrl =
    TextEditingController(text: log.sleepHours.toStringAsFixed(1));
    final pCtrl = TextEditingController(text: '${log.proteinGrams}');
    final cCtrl = TextEditingController(text: '${log.carbsGrams}');
    final fCtrl = TextEditingController(text: '${log.fatGrams}');
    final primary = Theme.of(context).colorScheme.primary;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar ${_dateLabel(log.date)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calorías (kcal)'),
              ),
              TextField(
                controller: waterCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Agua (vasos)'),
              ),
              TextField(
                controller: sleepCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Sueño (horas)'),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Macros (g)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              TextField(
                controller: pCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Proteína'),
              ),
              TextField(
                controller: cCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Carbohidratos'),
              ),
              TextField(
                controller: fCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Grasas'),
              ),
              if (log.meals.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    'Nota: este día tiene comidas registradas. '
                        'Los macros/kcal pueden recalcularse desde nutrición.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Guardar', style: TextStyle(color: primary)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    await ref.read(profileRepositoryProvider).updateDailyLog(
      user.uid,
      log.date,
      waterGlasses: int.tryParse(waterCtrl.text) ?? log.waterGlasses,
      sleepHours: double.tryParse(sleepCtrl.text.replaceAll(',', '.')) ??
          log.sleepHours,
      consumedCalories:
      int.tryParse(calCtrl.text) ?? log.consumedCalories,
      proteinGrams: int.tryParse(pCtrl.text) ?? log.proteinGrams,
      carbsGrams: int.tryParse(cCtrl.text) ?? log.carbsGrams,
      fatGrams: int.tryParse(fCtrl.text) ?? log.fatGrams,
    );

    ref.invalidate(dailyLogsHistoryProvider(_days));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Día actualizado')),
      );
    }
  }

  String _dateLabel(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Widget _chip(String label, int days) {
    final selected = _days == days;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() {
          _days = days;
          _expandedMonth = null;
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════

class _MetricSelector extends StatelessWidget {
  final _Metric? selected;
  final void Function(_Metric m) onSelect;

  const _MetricSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _MetricIcon(
            icon: Icons.local_fire_department,
            label: 'Calorías',
            color: _DailyHistoryScreenState._calColor,
            selected: selected == _Metric.calories,
            dimmed: selected != null && selected != _Metric.calories,
            onTap: () => onSelect(_Metric.calories),
          ),
          _MetricIcon(
            icon: Icons.water_drop,
            label: 'Agua',
            color: _DailyHistoryScreenState._waterColor,
            selected: selected == _Metric.water,
            dimmed: selected != null && selected != _Metric.water,
            onTap: () => onSelect(_Metric.water),
          ),
          _MetricIcon(
            icon: Icons.bedtime,
            label: 'Sueño',
            color: _DailyHistoryScreenState._sleepColor,
            selected: selected == _Metric.sleep,
            dimmed: selected != null && selected != _Metric.sleep,
            onTap: () => onSelect(_Metric.sleep),
          ),
          _MetricIcon(
            icon: Icons.pie_chart_outline,
            label: 'Macros',
            color: _DailyHistoryScreenState._proteinColor,
            selected: selected == _Metric.macros,
            dimmed: selected != null && selected != _Metric.macros,
            onTap: () => onSelect(_Metric.macros),
          ),
        ],
      ),
    );
  }
}

class _MetricIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final bool dimmed;
  final VoidCallback onTap;

  const _MetricIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: dimmed ? 0.35 : 1,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.25 : 0.12),
                  shape: BoxShape.circle,
                  border:
                  selected ? Border.all(color: color, width: 2) : null,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

// ─── Chart ─────────────────────────────────────────────────

class _HistoryChart extends StatelessWidget {
  final List<DailyLog> logs;
  final _Metric? selected;

  const _HistoryChart({required this.logs, required this.selected});

  double _scalar(DailyLog log, _Metric m) {
    return switch (m) {
      _Metric.calories => log.consumedCalories.toDouble(),
      _Metric.water => log.waterGlasses.toDouble(),
      _Metric.sleep => log.sleepHours,
      _Metric.macros => (log.proteinGrams + log.carbsGrams + log.fatGrams)
          .toDouble(), // solo para normalizar vista conjunta
    };
  }

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(child: Text('Sin datos'));
    }

    // Vista macros: 3 series P/C/G
    if (selected == _Metric.macros) {
      return _buildMulti(
        series: [
          _Series(
            'P',
            _DailyHistoryScreenState._proteinColor,
            [for (var i = 0; i < logs.length; i++) FlSpot(i.toDouble(), logs[i].proteinGrams.toDouble())],
          ),
          _Series(
            'C',
            _DailyHistoryScreenState._carbsColor,
            [for (var i = 0; i < logs.length; i++) FlSpot(i.toDouble(), logs[i].carbsGrams.toDouble())],
          ),
          _Series(
            'G',
            _DailyHistoryScreenState._fatColor,
            [for (var i = 0; i < logs.length; i++) FlSpot(i.toDouble(), logs[i].fatGrams.toDouble())],
          ),
        ],
        normalize: false,
        logs: logs,
      );
    }

    // Una métrica
    if (selected != null) {
      final m = selected!;
      final color = switch (m) {
        _Metric.calories => _DailyHistoryScreenState._calColor,
        _Metric.water => _DailyHistoryScreenState._waterColor,
        _Metric.sleep => _DailyHistoryScreenState._sleepColor,
        _Metric.macros => _DailyHistoryScreenState._proteinColor,
      };
      return _buildMulti(
        series: [
          _Series(
            '',
            color,
            [
              for (var i = 0; i < logs.length; i++)
                FlSpot(i.toDouble(), _scalar(logs[i], m)),
            ],
          ),
        ],
        normalize: false,
        logs: logs,
      );
    }

    // Conjunto: kcal, agua, sueño + macros totales (normalizado)
    return _buildMulti(
      series: [
        for (final m in [_Metric.calories, _Metric.water, _Metric.sleep, _Metric.macros])
          _Series(
            '',
            switch (m) {
              _Metric.calories => _DailyHistoryScreenState._calColor,
              _Metric.water => _DailyHistoryScreenState._waterColor,
              _Metric.sleep => _DailyHistoryScreenState._sleepColor,
              _Metric.macros => _DailyHistoryScreenState._proteinColor,
            },
            _normalizedSpots(m),
          ),
      ],
      normalize: true,
      logs: logs,
    );
  }

  List<FlSpot> _normalizedSpots(_Metric m) {
    final values = logs.map((l) => _scalar(l, m)).toList();
    final maxV = values.fold<double>(1, (a, b) => b > a ? b : a);
    return [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), maxV == 0 ? 0 : values[i] / maxV),
    ];
  }

  Widget _buildMulti({
    required List<_Series> series,
    required bool normalize,
    required List<DailyLog> logs,
  }) {
    double maxY = 1.05;
    if (!normalize) {
      maxY = 1;
      for (final s in series) {
        for (final spot in s.spots) {
          if (spot.y > maxY) maxY = spot.y;
        }
      }
      maxY *= 1.15;
      if (maxY < 1) maxY = 1;
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (logs.length - 1).clamp(0, 9999).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.grey.withValues(alpha: 0.15),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !normalize,
              reservedSize: 36,
              getTitlesWidget: (v, meta) {
                if (v == 0 || (v - meta.max).abs() < 0.01) {
                  return Text(
                    v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: logs.length <= 7
                  ? 1
                  : (logs.length / 4).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (i < 0 || i >= logs.length) return const SizedBox.shrink();
                final parts = logs[i].date.split('-');
                final label = parts.length == 3
                    ? '${parts[2]}/${parts[1]}'
                    : logs[i].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style:
                      const TextStyle(fontSize: 9, color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) {
              return touched.map((s) {
                final i = s.x.round().clamp(0, logs.length - 1);
                final log = logs[i];
                String text;
                if (selected == _Metric.macros) {
                  final names = ['P', 'C', 'G'];
                  final vals = [
                    log.proteinGrams,
                    log.carbsGrams,
                    log.fatGrams
                  ];
                  final idx = s.barIndex.clamp(0, 2);
                  text = '${names[idx]} ${vals[idx]} g';
                } else if (selected == _Metric.calories) {
                  text = '${log.consumedCalories} kcal';
                } else if (selected == _Metric.water) {
                  text = '${log.waterGlasses} vasos';
                } else if (selected == _Metric.sleep) {
                  text = '${log.sleepHours.toStringAsFixed(1)} h';
                } else {
                  text = log.date;
                }
                return LineTooltipItem(
                  text,
                  TextStyle(
                    color: series[s.barIndex.clamp(0, series.length - 1)].color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          for (final s in series)
            LineChartBarData(
              spots: s.spots,
              isCurved: true,
              color: s.color,
              barWidth: selected == null ? 2.2 : 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: logs.length <= 14),
              belowBarData: BarAreaData(
                show: selected != null && selected != _Metric.macros,
                color: s.color.withValues(alpha: 0.12),
              ),
            ),
        ],
      ),
    );
  }
}

class _Series {
  final String name;
  final Color color;
  final List<FlSpot> spots;
  _Series(this.name, this.color, this.spots);
}

// ─── Row ───────────────────────────────────────────────────

class _HistoryRow extends StatelessWidget {
  final DailyLog log;
  final _Metric? filter;
  final VoidCallback onEdit;

  const _HistoryRow({
    required this.log,
    required this.filter,
    required this.onEdit,
  });

  String get _dateLabel {
    final parts = log.date.split('-');
    if (parts.length != 3) return log.date;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget chip(IconData icon, Color color, String value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 3),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDark ? const Color(0xFF1A1A2E) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onEdit,
        onLongPress: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _dateLabel,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Spacer(),
                  Icon(Icons.edit_outlined,
                      size: 16, color: Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 8),
              if (filter == null || filter == _Metric.calories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: chip(
                    Icons.local_fire_department,
                    _DailyHistoryScreenState._calColor,
                    '${log.consumedCalories} kcal',
                  ),
                ),
              if (filter == null || filter == _Metric.water)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: chip(
                    Icons.water_drop,
                    _DailyHistoryScreenState._waterColor,
                    '${log.waterGlasses} vasos',
                  ),
                ),
              if (filter == null || filter == _Metric.sleep)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: chip(
                    Icons.bedtime,
                    _DailyHistoryScreenState._sleepColor,
                    '${log.sleepHours.toStringAsFixed(1)} h',
                  ),
                ),
              if (filter == null || filter == _Metric.macros)
                Row(
                  children: [
                    chip(
                      Icons.egg_alt,
                      _DailyHistoryScreenState._proteinColor,
                      'Prote ${log.proteinGrams}g',
                    ),
                    const SizedBox(width: 10),
                    chip(
                      Icons.grain,
                      _DailyHistoryScreenState._carbsColor,
                      'Carbos ${log.carbsGrams}g',
                    ),
                    const SizedBox(width: 10),
                    chip(
                      Icons.water,
                      _DailyHistoryScreenState._fatColor,
                      'Grasas ${log.fatGrams}g',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
