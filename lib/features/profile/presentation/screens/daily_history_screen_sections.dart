part of 'daily_history_screen.dart';

mixin _DailyHistorySections on ConsumerState<DailyHistoryScreen> {
  HistoryMetric? _selected;
  String? _expandedSection; // mes yyyy-MM o semana yyyy-MM-dd (lunes)
  int get _days;

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
                color: accentOf(context),
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
                      onEditMeals: () => _editMeals(log),
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
                '$days días · $totalCal kcal · $totalWater vasos · ${avgSleep.toStringAsFixed(1)} h sueño',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: accentOf(context),
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
                      onEditMeals: () => _editMeals(log),
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
                inputFormatters: InputFormatters.digits(maxLength: 5),
                decoration: const InputDecoration(labelText: 'Calorías (kcal)'),
              ),
              TextField(
                controller: waterCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: InputFormatters.digits(maxLength: 2),
                decoration: const InputDecoration(labelText: 'Agua (vasos)'),
              ),
              TextField(
                controller: sleepCtrl,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: InputFormatters.decimal(maxLength: 4),
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
                inputFormatters: InputFormatters.digits(maxLength: 4),
                decoration: const InputDecoration(labelText: 'Proteína'),
              ),
              TextField(
                controller: cCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: InputFormatters.digits(maxLength: 4),
                decoration: const InputDecoration(labelText: 'Carbohidratos'),
              ),
              TextField(
                controller: fCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: InputFormatters.digits(maxLength: 4),
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
            child: Text('Guardar', style: TextStyle(color: accentOf(context))),
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
      waterGlasses: (int.tryParse(waterCtrl.text) ?? log.waterGlasses)
          .clamp(0, InputLimits.waterGlassesMax),
      sleepHours: (double.tryParse(sleepCtrl.text.replaceAll(',', '.')) ??
              log.sleepHours)
          .clamp(0, InputLimits.sleepHoursMax),
      consumedCalories: (int.tryParse(calCtrl.text) ?? log.consumedCalories)
          .clamp(0, InputLimits.caloriesMax),
      proteinGrams:
          (int.tryParse(pCtrl.text) ?? log.proteinGrams).clamp(0, InputLimits.macroGramsMax),
      carbsGrams:
          (int.tryParse(cCtrl.text) ?? log.carbsGrams).clamp(0, InputLimits.macroGramsMax),
      fatGrams:
          (int.tryParse(fCtrl.text) ?? log.fatGrams).clamp(0, InputLimits.macroGramsMax),
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

  /// Ver y modificar las comidas individuales de un día pasado.
  Future<void> _editMeals(DailyLog log) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    final repo = ref.read(profileRepositoryProvider);

    DailyLog current = await repo.getLogForDate(user.uid, log.date);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> reload() async {
              final fresh = await repo.getLogForDate(user.uid, log.date);
              if (!ctx.mounted) return;
              setModal(() => current = fresh);
              ref.invalidate(dailyLogsHistoryProvider(_days));
            }

            final meals = current.meals;
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.72,
              maxChildSize: 0.94,
              builder: (_, scrollCtrl) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Comidas · ${_dateLabel(log.date)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: accentOf(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${current.consumedCalories} kcal · '
                        'P ${current.proteinGrams} · C ${current.carbsGrams} · G ${current.fatGrams}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView(
                          controller: scrollCtrl,
                          children: [
                            for (final t in MealEntry.mealTypes)
                              MealSection(
                                type: t,
                                meals:
                                    meals.where((m) => m.mealType == t).toList(),
                                totalCal: meals
                                    .where((m) => m.mealType == t)
                                    .fold<int>(0, (s, m) => s + m.calories),
                                onEdit: (m) async {
                                  await openMealEditor(context, ref,
                                      existing: m, dateKey: log.date);
                                  await reload();
                                },
                                onDelete: (id) async {
                                  await repo.removeMealForDate(
                                      user.uid, log.date, id);
                                  await reload();
                                },
                                onSaveAsFood: (m) =>
                                    saveMealAsFood(context, ref, m),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          await openMealEditor(context, ref, dateKey: log.date);
                          await reload();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Añadir comida'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
