import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/input_limits.dart';

/// Cambio de correo electrónico de la cuenta.
/// Pide la contraseña actual (reauth) y envía verificación al nuevo correo.
class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Theme.of(context).colorScheme.error : null),
    );
  }

  Future<void> _save() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final emailError = Validators.email(email);
    if (emailError != null) {
      _snack(emailError, error: true);
      return;
    }
    if (password.isEmpty) {
      _snack('Ingresa tu contraseña actual para confirmar', error: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).changeEmail(
            currentPassword: password,
            newEmail: email,
          );
      _snack('Te enviamos un correo de verificación. El cambio se aplica al '
          'confirmarlo desde tu bandeja.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    final currentEmail = auth.currentEmail ?? '—';
    final hasPassword = auth.hasPasswordProvider;

    return Scaffold(
      appBar: AppBar(title: const Text('Correo electrónico')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Correo actual',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            child: Text(
              currentEmail,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!hasPassword)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Tu cuenta usa Google, así que el correo se administra '
                  'desde esa cuenta y no puede cambiarse aquí.',
                  style: TextStyle(color: Theme.of(context).hintColor),
                ),
              ),
            )
          else ...[
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              inputFormatters: InputFormatters.text(InputLimits.emailMax),
              decoration: const InputDecoration(
                labelText: 'Nuevo correo',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Te enviaremos un correo de verificación al nuevo correo.',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              inputFormatters: InputFormatters.text(InputLimits.passwordMax),
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                prefixIcon: const Icon(Icons.lock_outline),
                helperText: 'La pedimos por seguridad antes de cambiarlo',
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
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
                  : const Text('Actualizar correo'),
            ),
          ],
        ],
      ),
    );
  }
}
