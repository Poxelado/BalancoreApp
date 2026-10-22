import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/input_limits.dart';

/// Cambio de contraseña en la app (pide la actual + nueva).
/// También ofrece enviar un correo de restablecimiento si no la recuerda.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _isLoading = false;
  bool _sendingReset = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _save() async {
    final current = _currentController.text;
    final next = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty) {
      _snack('Ingresa tu contraseña actual', error: true);
      return;
    }
    final passwordError = Validators.password(next);
    if (passwordError != null) {
      _snack('Nueva contraseña: $passwordError', error: true);
      return;
    }
    if (next != confirm) {
      _snack('Las contraseñas nuevas no coinciden', error: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).changePassword(
            currentPassword: current,
            newPassword: next,
          );
      _snack('Contraseña actualizada');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendResetEmail() async {
    final email = ref.read(authServiceProvider).currentEmail;
    if (email == null || email.isEmpty) {
      _snack('Tu cuenta no tiene un correo asociado', error: true);
      return;
    }
    setState(() => _sendingReset = true);
    try {
      await ref.read(authServiceProvider).resetPassword(email);
      _snack('Te enviamos un correo a $email para restablecerla');
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPassword = ref.read(authServiceProvider).hasPasswordProvider;

    return Scaffold(
      appBar: AppBar(title: const Text('Contraseña')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasPassword)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Tu cuenta inicia sesión con Google, así que no tiene '
                  'contraseña de Balancore. Usa "Iniciar con Google" para entrar.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ),
            )
          else ...[
            TextField(
              controller: _currentController,
              obscureText: _obscureCurrent,
              inputFormatters: InputFormatters.text(InputLimits.passwordMax),
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscureCurrent ? 'Mostrar' : 'Ocultar',
                  icon: Icon(_obscureCurrent
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newController,
              obscureText: _obscureNew,
              inputFormatters: InputFormatters.text(InputLimits.passwordMax),
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  tooltip: _obscureNew ? 'Mostrar' : 'Ocultar',
                  icon: Icon(_obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmController,
              obscureText: _obscureNew,
              inputFormatters: InputFormatters.text(InputLimits.passwordMax),
              decoration: const InputDecoration(
                labelText: 'Repite la nueva contraseña',
                prefixIcon: Icon(Icons.lock_reset),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Actualizar contraseña'),
            ),
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '¿No recuerdas tu contraseña?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Te enviamos un enlace a tu correo para crear una nueva.',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _sendingReset ? null : _sendResetEmail,
              icon: const Icon(Icons.mark_email_read_outlined, size: 18),
              label: Text(_sendingReset
                  ? 'Enviando…'
                  : 'Enviar correo de restablecimiento'),
            ),
          ],
        ],
      ),
    );
  }
}
