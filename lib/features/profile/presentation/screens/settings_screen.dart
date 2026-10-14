import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/preferences/units_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/settings_tiles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../training/presentation/screens/ai_settings_screen.dart';
import 'change_email_screen.dart';
import 'change_password_screen.dart';
import 'change_username_screen.dart';
import 'edit_profile_screen.dart';
import 'help_screen.dart';
import 'legal_screen.dart';
import 'notification_settings_screen.dart';
import 'theme_settings_screen.dart';
import 'units_settings_screen.dart';

/// Ajustes de la app en una vista propia, agrupados por secciones
/// (Cuenta, Notificaciones, Preferencias, Ayuda, Legal y Sesión).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
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
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) return;
      await ref.read(profileRepositoryProvider).deleteUserData(user.uid);
      await ref.read(authServiceProvider).deleteAccount();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cuenta eliminada. Puedes registrarte de nuevo si quieres.'),
        ),
      );
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: errorColor),
      );
    }
  }

  String _modeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Oscuro',
        ThemeMode.system => 'Sistema',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final themePrefs = ref.watch(themePreferencesProvider);
    final units = ref.watch(unitsProvider);
    final email = ref.watch(authServiceProvider).currentEmail;

    void push(Widget screen) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (profile != null) _AccountHeader(profile: profile),
          SettingsSection(
            title: 'CUENTA',
            children: [
              SettingsTile(
                icon: Icons.person_outline,
                title: 'Perfil',
                subtitle: 'Nombre, sexo, peso, altura y objetivo',
                onTap: () => push(EditProfileScreen(profile: profile!)),
              ),
              SettingsTile(
                icon: Icons.alternate_email,
                title: 'Nombre de usuario',
                subtitle: profile?.username?.isNotEmpty == true
                    ? '@${profile!.username}'
                    : 'Sin definir',
                onTap: () => push(const ChangeUsernameScreen()),
              ),
              SettingsTile(
                icon: Icons.mail_outline,
                title: 'Correo electrónico',
                subtitle: email ?? '—',
                onTap: () => push(const ChangeEmailScreen()),
              ),
              SettingsTile(
                icon: Icons.lock_outline,
                title: 'Contraseña',
                subtitle: 'Cambiar o restablecer',
                onTap: () => push(const ChangePasswordScreen()),
              ),
            ],
          ),
          SettingsSection(
            title: 'NOTIFICACIONES',
            children: [
              SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Recordatorios',
                subtitle: 'Entreno, comidas, peso y racha',
                onTap: () => push(const NotificationSettingsScreen()),
              ),
            ],
          ),
          SettingsSection(
            title: 'PREFERENCIAS',
            children: [
              SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Tema',
                subtitle:
                    '${_modeLabel(themePrefs.themeMode)} · ${themePrefs.colorTheme.label}',
                onTap: () => push(const ThemeSettingsScreen()),
              ),
              SettingsTile(
                icon: Icons.straighten,
                title: 'Unidades',
                subtitle: '${units.label} · ${units.shortLabel}',
                onTap: () => push(const UnitsSettingsScreen()),
              ),
              SettingsTile(
                icon: Icons.auto_awesome_outlined,
                title: 'Asistente de IA',
                subtitle: 'Clave y modelo del generador de rutinas',
                onTap: () => push(const AiSettingsScreen()),
              ),
            ],
          ),
          SettingsSection(
            title: 'AYUDA Y SOPORTE',
            children: [
              SettingsTile(
                icon: Icons.help_outline,
                title: 'Ayuda y soporte',
                subtitle: 'Preguntas frecuentes y contacto',
                onTap: () => push(const HelpScreen()),
              ),
            ],
          ),
          SettingsSection(
            title: 'LEGAL',
            children: [
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Política de privacidad',
                onTap: () => push(const LegalScreen(doc: LegalDoc.privacy)),
              ),
              SettingsTile(
                icon: Icons.description_outlined,
                title: 'Términos y condiciones',
                onTap: () => push(const LegalScreen(doc: LegalDoc.terms)),
              ),
            ],
          ),
          SettingsSection(
            title: 'SESIÓN',
            children: [
              SettingsTile(
                icon: Icons.logout,
                title: 'Cerrar sesión',
                color: Theme.of(context).colorScheme.error,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await ref.read(authServiceProvider).signOut();
                  navigator.popUntil((route) => route.isFirst);
                },
              ),
              SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Eliminar cuenta',
                subtitle: 'Borra perfil y datos de forma permanente',
                color: Theme.of(context).colorScheme.error,
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountHeader extends StatelessWidget {
  final UserProfile profile;

  const _AccountHeader({required this.profile});

  String get _initials {
    final name =
        profile.displayName ?? profile.username ?? profile.email ?? 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName ?? profile.username ?? 'Tu cuenta';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              _initials,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (profile.email != null && profile.email!.isNotEmpty)
                  Text(
                    profile.email!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
