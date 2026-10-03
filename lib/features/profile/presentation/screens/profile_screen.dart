import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import 'profile_tab.dart';
import 'routine_tab.dart';
import 'nutrition_tab.dart';
import 'edit_profile_screen.dart';
import 'progress_tab.dart';
import 'notification_settings_screen.dart';
import 'home_tab.dart';

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

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Se borrarán tu perfil, historial de peso, rutinas y registros diarios. '
              'Esta acción no se puede deshacer.\n\n'
              'Si iniciaste sesión hace rato, puede que debas volver a entrar antes de eliminar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;
      final uid = user.uid;
      await ref.read(profileRepositoryProvider).deleteUserData(uid);
      await ref.read(authServiceProvider).deleteAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cuenta eliminada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final prefs = ref.watch(themePreferencesProvider);
            final primary = Theme.of(context).colorScheme.primary;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Ajustes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Color de la app',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: AppColorTheme.values.map((colorTheme) {
                          final selected = prefs.colorTheme == colorTheme;
                          return GestureDetector(
                            onTap: () {
                              ref
                                  .read(themePreferencesProvider.notifier)
                                  .setColorTheme(colorTheme);
                            },
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: colorTheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? Colors.white
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow: selected
                                        ? [
                                      BoxShadow(
                                        color: colorTheme.primary
                                            .withValues(alpha: 0.45),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                        : null,
                                  ),
                                  child: selected
                                      ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 22,
                                  )
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  colorTheme.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: selected ? primary : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.notifications_outlined, color: primary),
                      title: const Text('Notificaciones'),
                      subtitle: const Text('Entreno, comidas, peso y racha'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacidad'),
                      subtitle: const Text(
                        'Tus datos se guardan en tu cuenta de Firebase',
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Privacidad'),
                            content: const Text(
                              'Balancore almacena tu perfil, peso, rutinas y '
                                  'registros diarios en Firestore asociados a tu usuario. '
                                  'Puedes eliminar tu cuenta y esos datos desde Ajustes.\n\n'
                                  'No vendemos tu información a terceros.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx),
                                child: const Text('Entendido'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        'Cerrar sesión',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await ref.read(authServiceProvider).signOut();
                      },
                    ),
                    ListTile(
                      leading:
                      const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text(
                        'Eliminar cuenta',
                        style: TextStyle(color: Colors.red),
                      ),
                      subtitle: const Text(
                        'Borra perfil y datos de forma permanente',
                      ),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _confirmDeleteAccount();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final themePrefs = ref.watch(themePreferencesProvider);
    final primary = Theme.of(context).colorScheme.primary;
    final isProfileTab = ref.watch(shellTabProvider) == 4;
    final username = (profile?.username?.isNotEmpty == true)
        ? '@${profile!.username}'
        : '@usuario';

    final isDark = themePrefs.themeMode == ThemeMode.dark ||
        (themePrefs.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: !isProfileTab,
        title: isProfileTab
            ? Text(
          username,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        )
            : const Text(
          'Balancore',
          style: TextStyle(
            color: Colors.white,
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
              color: Colors.white,
            ),
            tooltip: isDark ? 'Tema claro' : 'Tema oscuro',
            onPressed: () {
              ref
                  .read(themePreferencesProvider.notifier)
                  .toggleLightDark();
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
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
            const Icon(Icons.settings_outlined, color: Colors.white),
            tooltip: 'Ajustes',
            onPressed: _openSettings,
          ),
        ]
            : null,
      ),
      body: _buildPage(ref.watch(shellTabProvider)),
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

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const ProgressTab();
      case 1:
        return const NutritionTab();
      case 2:
        return const HomeTab();
      case 3:
        return const RoutineTab();
      case 4:
        return const ProfileTab();
      default:
        return const HomeTab();
    }
  }

}
