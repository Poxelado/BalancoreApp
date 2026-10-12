import 'package:flutter/material.dart';
import '../screens/daily_history_screen.dart';
import 'weekly_macro_card.dart';

// ═══════════════════════════════════════════════════════════
// HÁBITOS
// ═══════════════════════════════════════════════════════════

class HabitsSection extends StatelessWidget {
  final Color primary;
  const HabitsSection({super.key, required this.primary});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      children: const [
        WeeklyMacroCard(),
        DailyHistoryScreen(embedded: true),
      ],
    );
  }
}
