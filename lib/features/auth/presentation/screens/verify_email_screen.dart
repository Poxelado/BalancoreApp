import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../../../../../core/theme/app_theme.dart';

/// Pantalla bloqueante que se muestra mientras el correo no está verificado.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with WidgetsBindingObserver {
  bool _sending = false;
  bool _checking = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de verificar en el navegador/correo, comprobamos solo.
    if (state == AppLifecycleState.resumed) {
      _checkVerified(silent: true);
    }
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    if (_sending || _cooldown > 0) return;
    setState(() => _sending = true);
    try {
      await ref.read(authServiceProvider).sendEmailVerification();
      _startCooldown();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Te reenviamos el correo de verificación.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkVerified({bool silent = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final verified = await ref.read(authServiceProvider).reloadAndCheckVerified();
      if (!mounted) return;
      if (verified) {
        // Fuerza a AuthWrapper a reconstruirse con el usuario ya verificado.
        ref.invalidate(authStateProvider);
      } else if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Todavía no confirmamos tu correo. Revisa tu bandeja.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authServiceProvider).currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_unread_outlined, size: 72, color: accentOf(context)),
                const SizedBox(height: 24),
                const Text(
                  'Verifica tu correo',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Te enviamos un enlace de confirmación a:\n$email\n\n'
                  'Ábrelo y vuelve aquí. Sin verificarlo no podemos mostrarte tus datos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _checking ? null : () => _checkVerified(),
                    child: _checking
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ya verifiqué mi correo'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: (_sending || _cooldown > 0) ? null : _resend,
                    child: Text(
                      _cooldown > 0
                          ? 'Reenviar en ${_cooldown}s'
                          : 'Reenviar correo',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  child: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
