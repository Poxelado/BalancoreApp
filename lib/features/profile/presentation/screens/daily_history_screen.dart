import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/history_components.dart';


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
  HistoryMetric? _selected;
  String? _expandedSection; // mes yyyy-MM o semana yyyy-MM-dd (lunes)

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


  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(dailyLogsHistoryProvider(_days));
    // Abrir con macros si se pidió desde Nutrición
    final forcedMetric = ref.watch(habitsMetricProvider);
    if (forcedMetric != null && _selected == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selected = HistoryMetric.values[forcedMetric.clamp(0, HistoryMetric.values.length - 1)];
        });
        ref.read(habitsMetricProvider.notifier).state = null;
      });
    }

    final primary = Theme.of(context).colorScheme.primary;
    final groupByMonth = _days >= 90;
    final groupByWeek = _days >= 30 && _days < 90;

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
          // empty state abajo
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.insights_outlined,
                title: 'Sin registros en este rango',
                subtitle: 'Registra comidas, agua o sueño para ver el historial.',
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
            MetricSelector(
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
              child: HistoryChart(
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
                  : groupByWeek
                  ? 'Semanas del rango'
                  : 'Registros del rango',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            ),
            const SizedBox(height: 10),
            if (groupByMonth)
              ..._buildMonthSections(logs)
            else if (groupByWeek)
              ..._buildWeekSections(logs)
            else
              ...logs.map(
                    (log) => HistoryRow(
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
      HistoryMetric.calories => 'Calorías',
      HistoryMetric.water => 'Agua',
      HistoryMetric.sleep => 'Sueño',
      HistoryMetric.macros => 'Macros (P / C / G)',
    };
  }

  Widget _legend() {
    if (_selected == null) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LegendDot(color: historyCalColor, label: 'Kcal'),
          SizedBox(width: 10),
          LegendDot(color: historyWaterColor, label: 'Agua'),
          SizedBox(width: 10),
          LegendDot(color: historySleepColor, label: 'Sueño'),
          SizedBox(width: 10),
          LegendDot(color: historyProteinColor, label: 'Macros*'),
        ],
      );
    }
    if (_selected == HistoryMetric.macros) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LegendDot(color: historyProteinColor, label: 'Proteína'),
          SizedBox(width: 12),
          LegendDot(color: historyCarbsColor, label: 'Carbos'),
          SizedBox(width: 12),
          LegendDot(color: historyFatColor, label: 'Grasas'),
        ],
      );
    }
    return const SizedBox.shrink();
  }


  DateTime? _parseLogDate(String date) {
    final p = date.split('-');
    if (p.length < 3) return null;
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  String _fmtD(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  /// Agrupa por semana (Lun–Dom) para rango 1 mes.
  List<Widget> _buildWeekSections(List<DailyLog> logsDesc) {
    final primary = Theme.of(context).colorScheme.primary;
    final map = <String, List<DailyLog>>{};
    for (final log in logsDesc) {
      final d = _parseLogDate(log.date);
      if (d == null) continue;
      final mon = _mondayOf(d);
      final key =
          '${mon.year}-${mon.month.toString().padLeft(2, '0')}-${mon.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(log);
    }
    final keys = map.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // más reciente primero

    // Número de semana dentro del mes (1–5)
    int weekOfMonth(DateTime monday) {
      return ((monday.day - 1) ~/ 7) + 1;
    }

    const monthNames = [
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

    return keys.map((key) {
      final days = map[key]!
        ..sort((a, b) => b.date.compareTo(a.date));
      final mon = _parseLogDate(key)!;
      final sun = mon.add(const Duration(days: 6));
      final wom = weekOfMonth(mon);
      final monthName = monthNames[mon.month];
      final label =
          '$monthName · Semana $wom  (${_fmtD(mon)} – ${_fmtD(sun)})';
      final expanded = _expandedSection == key;

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
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Text(
                '${days.length} días · $totalCal kcal · $totalWater vasos · ${avgSleep.toStringAsFixed(1)} h sueño',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: primary,
              ),
              onTap: () {
                setState(() {
                  _expandedSection = expanded ? null : key;
                });
              },
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Column(
                  children: days
                      .map(
                        (log) => HistoryRow(
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
      final expanded = _expandedSection == monthKey;
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
                  _expandedSection = expanded ? null : monthKey;
                });
              },
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Column(
                  children: days
                      .map(
                        (log) => HistoryRow(
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
}

// ═══════════════════════════════════════════════════════════

