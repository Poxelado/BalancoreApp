import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';

/// Cambio del @nombre de usuario, respetando el límite de 3 cambios/30 días.
class ChangeUsernameScreen extends ConsumerStatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  ConsumerState<ChangeUsernameScreen> createState() =>
      _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends ConsumerState<ChangeUsernameScreen> {
  final _controller = TextEditingController();
  bool _initialized = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _save(UserProfile profile) async {
    final newUsername =
        _controller.text.trim().replaceAll('@', '').toLowerCase();
    if (newUsername.length < 3) {
      _snack('El usuario debe tener al menos 3 caracteres', error: true);
      return;
    }
    final oldU = (profile.username ?? '').toLowerCase();
    if (newUsername == oldU) {
      Navigator.pop(context);
      return;
    }
    if (!profile.canChangeUsername) {
      _snack('Ya cambiaste el usuario 3 veces en los últimos 30 días',
          error: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(profileRepositoryProvider).changeUsername(
            uid: profile.uid,
            email: profile.email ?? '',
            oldUsername: profile.username,
            newUsername: newUsername,
          );
      final dates = List<String>.from(profile.usernameChangeDates)
        ..add(DateTime.now().toIso8601String());
      await ref
          .read(profileRepositoryProvider)
          .saveProfile(profile.copyWith(
            username: newUsername,
            usernameChangeDates: dates,
          ));
      ref.invalidate(userProfileProvider);
      _snack('Usuario actualizado a @$newUsername');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_initialized) {
      _controller.text = profile.username ?? '';
      _initialized = true;
    }

    final remaining = 3 - profile.usernameChangesLast30Days();

    return Scaffold(
      appBar: AppBar(title: const Text('Nombre de usuario')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Usuario actual',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            child: Text(
              profile.username?.isNotEmpty == true
                  ? '@${profile.username}'
                  : '—',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autocorrect: false,
            enabled: profile.canChangeUsername,
            decoration: InputDecoration(
              labelText: 'Nuevo usuario',
              prefixIcon: const Icon(Icons.alternate_email),
              helperText: profile.canChangeUsername
                  ? 'Te quedan $remaining de 3 cambios en 30 días'
                  : 'Límite de 3 cambios/mes alcanzado',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'El usuario es único y con él pueden encontrarte. Solo letras, '
            'números y guion bajo; mínimo 3 caracteres.',
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed:
                (_isLoading || !profile.canChangeUsername) ? null : () => _save(profile),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar usuario'),
          ),
        ],
      ),
    );
  }
}
