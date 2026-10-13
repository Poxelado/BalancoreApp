import 'user_profile.dart';

/// Resumen de macros de una semana (Lun–Dom).
class MacroWeekReport {
  final DateTime weekStart;
  final DateTime weekEnd;
  final int daysWithData;
  final double avgCalories;
  final double avgProtein;
  final double avgCarbs;
  final double avgFat;
  final double? prevAvgCalories;
  final double? prevAvgProtein;
  final double? prevAvgCarbs;
  final double? prevAvgFat;
  final int targetCalories;
  final int targetProtein;
  final int targetCarbs;
  final int targetFat;
  final int daysHitProtein;
  final int daysHitCalories;

  const MacroWeekReport({
    required this.weekStart,
    required this.weekEnd,
    required this.daysWithData,
    required this.avgCalories,
    required this.avgProtein,
    required this.avgCarbs,
    required this.avgFat,
    this.prevAvgCalories,
    this.prevAvgProtein,
    this.prevAvgCarbs,
    this.prevAvgFat,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.daysHitProtein,
    required this.daysHitCalories,
  });

  double get proteinPctOfTarget =>
      targetProtein > 0 ? (avgProtein / targetProtein) * 100 : 0;

  double get caloriesPctOfTarget =>
      targetCalories > 0 ? (avgCalories / targetCalories) * 100 : 0;

  double get proteinCalPct {
    final t = avgCalories;
    if (t <= 0) return 0;
    return (avgProtein * 4 / t) * 100;
  }

  double get carbsCalPct {
    final t = avgCalories;
    if (t <= 0) return 0;
    return (avgCarbs * 4 / t) * 100;
  }

  double get fatCalPct {
    final t = avgCalories;
    if (t <= 0) return 0;
    return (avgFat * 9 / t) * 100;
  }

  double? get deltaCalories =>
      prevAvgCalories == null ? null : avgCalories - prevAvgCalories!;

  double? get deltaProtein =>
      prevAvgProtein == null ? null : avgProtein - prevAvgProtein!;

  double? get deltaCarbs =>
      prevAvgCarbs == null ? null : avgCarbs - prevAvgCarbs!;

  double? get deltaFat =>
      prevAvgFat == null ? null : avgFat - prevAvgFat!;
}

class MacroWeekAnalysis {
  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime startOfWeek(DateTime d) {
    final x = _day(d);
    return x.subtract(Duration(days: x.weekday - 1));
  }

  static DateTime? _parseLogDate(String date) {
    final p = date.split('-');
    if (p.length < 3) return null;
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static bool _hasMacroData(DailyLog log) {
    return log.consumedCalories > 0 ||
        log.proteinGrams > 0 ||
        log.carbsGrams > 0 ||
        log.fatGrams > 0 ||
        log.meals.isNotEmpty;
  }

  static List<DailyLog> _inRange(
      List<DailyLog> logs,
      DateTime start,
      DateTime endExclusive,
      ) {
    return logs.where((l) {
      final d = _parseLogDate(l.date);
      if (d == null) return false;
      return !d.isBefore(start) && d.isBefore(endExclusive);
    }).toList();
  }

  static ({double cal, double p, double c, double f, int n}) _averages(
      List<DailyLog> logs,
      ) {
    final usable = logs.where(_hasMacroData).toList();
    if (usable.isEmpty) {
      return (cal: 0.0, p: 0.0, c: 0.0, f: 0.0, n: 0);
    }
    final n = usable.length;
    final cal =
        usable.fold<int>(0, (a, l) => a + l.consumedCalories) / n;
    final p = usable.fold<int>(0, (a, l) => a + l.proteinGrams) / n;
    final c = usable.fold<int>(0, (a, l) => a + l.carbsGrams) / n;
    final f = usable.fold<int>(0, (a, l) => a + l.fatGrams) / n;
    return (cal: cal, p: p, c: c, f: f, n: n);
  }

  static MacroWeekReport build({
    required List<DailyLog> logs,
    required UserProfile? profile,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final weekStart = startOfWeek(n);
    final weekEnd = weekStart.add(const Duration(days: 7));
    final prevStart = weekStart.subtract(const Duration(days: 7));

    final thisWeek = _inRange(logs, weekStart, weekEnd);
    final prevWeek = _inRange(logs, prevStart, weekStart);

    final cur = _averages(thisWeek);
    final prev = _averages(prevWeek);

    var tCal = profile?.targetCalories ?? 0;
    var tP = profile?.targetProtein ?? 0;
    var tC = profile?.targetCarbs ?? 0;
    var tF = profile?.targetFat ?? 0;

    if (profile != null) {
      final eff = profile.effectiveTargets;
      tCal = eff.calories;
      tP = eff.protein;
      tC = eff.carbs;
      tF = eff.fat;
    }

    var hitP = 0;
    var hitCal = 0;
    for (final l in thisWeek.where(_hasMacroData)) {
      if (tP > 0 && l.proteinGrams >= tP * 0.9) hitP++;
      if (tCal > 0) {
        final ratio = l.consumedCalories / tCal;
        if (ratio >= 0.9 && ratio <= 1.1) hitCal++;
      }
    }

    return MacroWeekReport(
      weekStart: weekStart,
      weekEnd: weekEnd.subtract(const Duration(days: 1)),
      daysWithData: cur.n,
      avgCalories: cur.cal,
      avgProtein: cur.p,
      avgCarbs: cur.c,
      avgFat: cur.f,
      prevAvgCalories: prev.n > 0 ? prev.cal : null,
      prevAvgProtein: prev.n > 0 ? prev.p : null,
      prevAvgCarbs: prev.n > 0 ? prev.c : null,
      prevAvgFat: prev.n > 0 ? prev.f : null,
      targetCalories: tCal,
      targetProtein: tP,
      targetCarbs: tC,
      targetFat: tF,
      daysHitProtein: hitP,
      daysHitCalories: hitCal,
    );
  }
}
