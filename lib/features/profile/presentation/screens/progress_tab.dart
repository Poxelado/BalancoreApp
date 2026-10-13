import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_provider.dart';
import '../widgets/progress_consistency.dart';
import '../widgets/progress_habits.dart';
import '../widgets/progress_workouts.dart';
import '../../../../core/theme/app_theme.dart';

class ProgressTab extends ConsumerStatefulWidget {
  const ProgressTab({super.key});

  @override
  ConsumerState<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends ConsumerState<ProgressTab> {
  int _trainPeriodDays = 30;
  int _summaryPeriodDays = 7;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final section = ref.watch(progressSectionProvider);

    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Entrenos'),
                icon: Icon(Icons.fitness_center, size: 13),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Registros'),
                icon: Icon(Icons.calendar_view_week, size: 13),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Hábitos'),
                icon: Icon(Icons.water_drop_outlined, size: 13),
              ),
            ],
            selected: {section},
            onSelectionChanged: (s) {
              ref.read(progressSectionProvider.notifier).state = s.first;
              invalidateProgressData(ref);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) return primary;
                return null;
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            color: accentOf(context),
            onRefresh: () async {
              invalidateProgressData(ref);
              await Future.wait([
                ref.refresh(
                  workoutHistoryProvider(
                    section == 0
                        ? _trainPeriodDays + 14
                        : _summaryPeriodDays + 14,
                  ).future,
                ),
                ref.refresh(
                  dailyLogsHistoryProvider(_summaryPeriodDays + 14).future,
                ),
                ref.refresh(todayLogProvider.future),
              ]);
            },
            child: switch (section) {
              0 => WorkoutsSection(
                primary: primary,
                periodDays: _trainPeriodDays,
                onPeriodChanged: (d) =>
                    setState(() => _trainPeriodDays = d),
              ),
              1 => WeekSummarySection(
                primary: primary,
                periodDays: _summaryPeriodDays,
                onPeriodChanged: (d) {
                  setState(() => _summaryPeriodDays = d);
                  invalidateProgressData(ref);
                },
              ),
              _ => HabitsSection(primary: primary),
            },
          ),
        ),
      ],
    );
  }
}
