import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/history_components.dart';
part 'daily_history_screen_sections.dart';


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

class _DailyHistoryScreenState extends ConsumerState<DailyHistoryScreen>
    with _DailyHistorySections {
  @override
  late int _days;

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
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
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

}

// ═══════════════════════════════════════════════════════════

