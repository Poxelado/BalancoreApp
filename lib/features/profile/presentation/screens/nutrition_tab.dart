import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/recipes_tab.dart';
import '../widgets/saved_foods_tab.dart';
import '../widgets/today_tab.dart';

class NutritionTab extends ConsumerWidget {
  const NutritionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(todayLogProvider);
    final profile = ref.watch(userProfileProvider).value;
    final primary = Theme.of(context).colorScheme.primary;

    return logAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: primary)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (log) => _NutritionBody(log: log, profile: profile),
    );
  }
}

class _NutritionBody extends ConsumerStatefulWidget {
  final DailyLog log;
  final UserProfile? profile;

  const _NutritionBody({required this.log, required this.profile});

  @override
  ConsumerState<_NutritionBody> createState() => _NutritionBodyState();
}

class _NutritionBodyState extends ConsumerState<_NutritionBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

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

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primary,
          tabs: const [
            Tab(text: 'Hoy'),
            Tab(text: 'Mis alimentos'),
            Tab(text: 'Recetas'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              TodayTab(log: widget.log, profile: widget.profile),
              const SavedFoodsTab(),
              const RecipesTab(),
            ],
          ),
        ),
      ],
    );
  }
}
