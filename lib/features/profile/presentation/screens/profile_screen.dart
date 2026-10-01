import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import 'profile_tab.dart';
import 'routine_tab.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _currentIndex = 0;
  final _addCalorieController = TextEditingController();

  @override
  void dispose() {
    _addCalorieController.dispose();
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
    final isProfileTab = _currentIndex == 0;
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
      body: _buildPage(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: primary,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: 'Calorías',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Rutina',
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const ProfileTab();
      case 1:
        return _buildCalorieScreen();
      case 2:
        return const RoutineTab();
      default:
        return const ProfileTab();
    }
  }

  Widget _buildCalorieScreen() {
    final logAsync = ref.watch(todayLogProvider);
    final profile = ref.watch(userProfileProvider).value;
    final target = profile?.targetCalories ?? 2000;
    final primary = Theme.of(context).colorScheme.primary;

    return logAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: primary),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (log) {
        final consumed = log.consumedCalories;
        final progress =
        target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
        final remaining = target - consumed;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'Resumen Nutricional del Día',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 12,
                                backgroundColor: Colors.grey.shade200,
                                color: primary,
                              ),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$consumed',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  'kcal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Meta: $target kcal',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Restantes: ${remaining >= 0 ? remaining : 0} kcal',
                              style: TextStyle(
                                color:
                                remaining < 0 ? Colors.red : Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _macroChip(
                    'Proteínas',
                    '${log.proteinGrams} g',
                    Colors.orange,
                  ),
                  _macroChip('Carbos', '${log.carbsGrams} g', Colors.blue),
                  _macroChip('Grasas', '${log.fatGrams} g', Colors.redAccent),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addCalorieController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Calorías (kcal)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onPressed: () async {
                      final v = int.tryParse(_addCalorieController.text);
                      if (v == null || v <= 0) return;

                      final user = ref.read(authServiceProvider).currentUser;
                      if (user == null) return;

                      final newTotal = log.consumedCalories + v;
                      await ref.read(profileRepositoryProvider).updateTodayLog(
                        user.uid,
                        consumedCalories: newTotal,
                      );

                      ref.invalidate(todayLogProvider);
                      _addCalorieController.clear();
                    },
                    child: const Text(
                      'Agregar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}