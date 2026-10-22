import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/screens/legal_screen.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/input_limits.dart';
import '../../../profile/domain/user_profile.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;
  bool _acceptMarketing = false;

  bool get _canSubmit => _acceptTerms && _acceptMarketing;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y las notificaciones por correo.'),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Creando tu cuenta',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Theme.of(ctx).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Estamos preparando tu espacio en Balancore.\nEsto toma solo unos segundos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final username = _usernameController.text
        .trim()
        .replaceAll('@', '')
        .toLowerCase();
    final email = _emailController.text.trim();
    final repo = ref.read(profileRepositoryProvider);
    String? createdUid;

    try {
      final available = await repo.isUsernameAvailable(username);
      if (!available) throw const ValidationException('Ese nombre de usuario ya está en uso.');

      final cred = await ref.read(authServiceProvider).registerWithEmail(
        email: email,
        password: _passwordController.text,
      );
      if (cred?.user == null) throw const AuthException('No se pudo crear la cuenta.');
      createdUid = cred!.user!.uid;

      await repo.claimUsername(
        username: username,
        uid: createdUid,
      );

      // Guardar para que el onboarding lo tenga sí o sí
      ref.read(pendingUsernameProvider.notifier).state = username;

      await repo.saveProfile(
        UserProfile(
          uid: createdUid,
          email: email,
          username: username,
          sex: 'Masculino',
          currentWeight: 70,
          height: 170,
          age: 25,
          activityLevel: 'Sedentario',
          goal: 'Mantenimiento',
          targetCalories: 2000,
          onboardingCompleted: false,
          acceptedTerms: true,
          acceptedMarketing: true,
          termsAcceptedAt: DateTime.now(),
        ),
      );

      ref.invalidate(userProfileProvider);

      final verifyError =
          ref.read(authServiceProvider).lastVerificationError;
      if (mounted) {
        Navigator.of(context).pop(); // cierra loading
        Navigator.of(context).popUntil((route) => route.isFirst);
        if (verifyError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No pudimos enviar el correo de verificación. Podrás '
                'reenviarlo más tarde desde tu perfil.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Si ya creamos la cuenta de Auth pero falló el resto (p. ej. el username
      // se tomó en la carrera), deshacemos todo para no dejar cuentas huérfanas
      // ni usernames reservados apuntando a un uid inexistente.
      if (createdUid != null) {
        try {
          await repo.releaseUsername(username);
        } catch (e) {
          debugPrint('register: no se pudo liberar el username "$username": $e');
        }
        try {
          await ref.read(authServiceProvider).currentUser?.delete();
        } catch (e) {
          debugPrint('register: no se pudo borrar la cuenta huérfana: $e');
        }
      }
      if (mounted) {
        Navigator.of(context).pop(); // cierra loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _acceptanceChecks(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _checkTile(
          value: _acceptTerms,
          onChanged: (v) => setState(() => _acceptTerms = v ?? false),
          title: 'Acepto los Términos y Condiciones y la Política de Privacidad.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.description_outlined, size: 16),
            label: const Text('Leer Términos y Condiciones'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalScreen(doc: LegalDoc.terms),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _checkTile(
          value: _acceptMarketing,
          onChanged: (v) => setState(() => _acceptMarketing = v ?? false),
          title: 'Acepto recibir correos de Balancore con recordatorios, '
              'novedades y consejos para mejorar mis hábitos.',
        ),
        const SizedBox(height: 12),
        if (!_canSubmit)
          Row(
            children: [
              Icon(Icons.info_outline, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Debes aceptar ambas casillas para crear tu cuenta.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _checkTile({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String title,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title, style: const TextStyle(fontSize: 13, height: 1.35)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: accentOf(context).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.fitness_center,
                          color: accentOf(context), size: 32),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Crea tu cuenta',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Empieza a construir mejores hábitos hoy mismo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    inputFormatters: InputFormatters.text(InputLimits.usernameMax),
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario *',
                      hintText: 'solo minúsculas, números, . y _',
                      prefixIcon: Icon(Icons.alternate_email),
                      border: OutlineInputBorder(),
                    ),
                    validator: Validators.username,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    inputFormatters: InputFormatters.text(InputLimits.emailMax),
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    inputFormatters: InputFormatters.text(InputLimits.passwordMax),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    inputFormatters: InputFormatters.text(InputLimits.passwordMax),
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirm
                            ? 'Mostrar confirmación'
                            : 'Ocultar confirmación',
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _acceptanceChecks(context),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: (_isLoading || !_canSubmit) ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Crear cuenta',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
