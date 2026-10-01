import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';

class DailyHistoryScreen extends ConsumerStatefulWidget {
  const DailyHistoryScreen({super.key});

  @override
  ConsumerState<DailyHistoryScreen> createState() => _DailyHistoryScreenState();
}

class _DailyHistoryScreenState extends ConsumerState<DailyHistoryScreen> {
  int _days = 30; // 1M por defecto

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(dailyLogsHistoryProvider(_days));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial diario'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtro de periodo
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Periodo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                _chip('1M', 30),
                _chip('3M', 90),
                _chip('6M', 180),
                _chip('1A', 365),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: historyAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (logs) {
                if (logs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aún no hay registros diarios.\n'
                          'Registra agua, sueño o calorías para verlos aquí.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _DayCard(log: log);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, int days) {
    final selected = _days == days;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: Theme.of(context).colorScheme.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        onSelected: (_) {
          setState(() => _days = days);
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DailyLog log;

  const _DayCard({required this.log});

  String get _dateLabel {
    // date viene como yyyy-MM-dd
    final parts = log.date.split('-');
    if (parts.length != 3) return log.date;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _dateLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    icon: Icons.local_fire_department,
                    color: Colors.orange,
                    label: 'Calorías',
                    value: '${log.consumedCalories} kcal',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    icon: Icons.water_drop,
                    color: Colors.blue,
                    label: 'Agua',
                    value: '${log.waterGlasses} vasos',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    icon: Icons.bedtime,
                    color: Colors.indigo,
                    label: 'Sueño',
                    value: '${log.sleepHours.toStringAsFixed(1)} h',
                  ),
                ),
              ],
            ),
            if (log.proteinGrams > 0 ||
                log.carbsGrams > 0 ||
                log.fatGrams > 0) ...[
              const SizedBox(height: 10),
              Text(
                'P ${log.proteinGrams}g · C ${log.carbsGrams}g · G ${log.fatGrams}g',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _Metric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}