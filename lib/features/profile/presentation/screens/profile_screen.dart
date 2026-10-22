import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../providers/profile_provider.dart';
import 'profile_tab.dart';
import 'routine_tab.dart';
import 'nutrition_tab.dart';
import 'edit_profile_screen.dart';
import 'progress_tab.dart';
import 'settings_screen.dart';
import 'home_tab.dart';
import '../widgets/workout_mini_player.dart';
import '../widgets/offline_status_banner.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // tab via shellTabProvider (default Inicio = 2)
  @override
  void dispose() {
    super.dispose();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final themePrefs = ref.watch(themePreferencesProvider);
    final isProfileTab = ref.watch(shellTabProvider) == 4;
    final username = (profile?.username?.isNotEmpty == true)
        ? '@${profile!.username}'
        : '@usuario';

    final isDark = themePrefs.themeMode == ThemeMode.dark ||
        (themePrefs.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        centerTitle: !isProfileTab,
        title: isProfileTab
            ? Text(
          username,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        )
            : const Text(
          'Balancore',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: isProfileTab
            ? [
          // Solo visible en el apartado de perfil
          IconButton(
            icon: Icon(
              isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            tooltip: isDark ? 'Tema claro' : 'Tema oscuro',
            onPressed: () {
              ref
                  .read(themePreferencesProvider.notifier)
                  .toggleLightDark();
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar perfil',
            onPressed: () {
              if (profile == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(profile: profile),
                ),
              );
            },
          ),
          IconButton(
            icon:
            const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: _openSettings,
          ),
        ]
            : null,
      ),
      body: Column(
        children: [
          const OfflineStatusBanner(),
          Expanded(
            child: Stack(
              children: [
                // IndexedStack conserva el estado de cada pestaña (carrusel,
                // scroll, filtros) al cambiar de apartado.
                Positioned.fill(
                  child: IndexedStack(
                    index: ref.watch(shellTabProvider),
                    children: const [
                      ProgressTab(),
                      NutritionTab(),
                      HomeTab(),
                      RoutineTab(),
                      ProfileTab(),
                    ],
                  ),
                ),
                const WorkoutMiniPlayer(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: ref.watch(shellTabProvider),
        onTap: (i) => ref.read(shellTabProvider.notifier).state = i,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Progreso'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), label: 'Nutrición'),
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Rutina'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

}
