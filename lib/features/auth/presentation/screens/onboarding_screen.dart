import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../../../../core/notifications/notification_preferences.dart';
import '../../../../core/notifications/notification_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _weightController = TextEditingController(text: '70');
  final _heightController = TextEditingController(text: '170');
  final _ageController = TextEditingController(text: '25');

  int _page = 0;
  String _sex = 'Masculino';
  String _activityLevel = 'Sedentario';
  String _goal = 'Mantenimiento';
  bool _isLoading = false;
  int _workoutMin = 18 * 60;
  int _mealMin = 13 * 60;
  int _weightMin = 8 * 60;
  int _weightWeekday = DateTime.monday;
  int _streakInterval = 4;
  bool? _wantNotifs;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  int get _previewCalories {
    final w = double.tryParse(_weightController.text) ?? 70;
    final h = double.tryParse(_heightController.text) ?? 170;
    final a = int.tryParse(_ageController.text) ?? 25;
    return UserProfile.calculateTMB(
      sex: _sex,
      weight: w,
      height: h,
      age: a,
      activityLevel: _activityLevel,
      goal: _goal,
    );
  }

  ({int protein, int carbs, int fat}) get _previewMacros {
    final w = double.tryParse(_weightController.text) ?? 70;
    return UserProfile.calculateMacros(
      weight: w,
      calories: _previewCalories,
      goal: _goal,
    );
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw 'No hay usuario autenticado';

      final weight = double.parse(_weightController.text);
      final height = double.parse(_heightController.text);
      final age = int.parse(_ageController.text);

      final calories = UserProfile.calculateTMB(
        sex: _sex,
        weight: weight,
        height: height,
        age: age,
        activityLevel: _activityLevel,
        goal: _goal,
      );
      final macros = UserProfile.calculateMacros(
        weight: weight,
        calories: calories,
        goal: _goal,
      );

      final profile = UserProfile(
        uid: user.uid,
        email: user.email,
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        username: _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim().replaceAll('@', ''),
        sex: _sex,
        currentWeight: weight,
        height: height,
        age: age,
        activityLevel: _activityLevel,
        goal: _goal,
        targetCalories: calories,
        targetProtein: macros.protein,
        targetCarbs: macros.carbs,
        targetFat: macros.fat,
        onboardingCompleted: true,
        createdAt: DateTime.now(),
      );

      await ref.read(profileRepositoryProvider).saveProfile(profile);
      await ref.read(profileRepositoryProvider).addWeightEntry(
        user.uid,
        weight,
        DateTime.now(),
      );

      ref.invalidate(userProfileProvider);

      await ref.read(notificationPreferencesProvider.notifier).update(
        NotificationPreferences(
          masterEnabled: _wantNotifs == true,
          workoutEnabled: _wantNotifs == true,
          mealEnabled: _wantNotifs == true,
          weightEnabled: _wantNotifs == true,
          progressEnabled: _wantNotifs == true,
          streakEnabled: _wantNotifs == true,
          workoutMinutes: _workoutMin,
          mealMinutes: _mealMin,
          weightMinutes: _weightMin,
          weightWeekday: _weightWeekday,
          streakIntervalHours: _streakInterval,
        ),
      );
      await NotificationService.instance.init();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _next() {
    if (_page == 0) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if (_page == 1) {
      if (!_formKey.currentState!.validate()) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if (_page == 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _saveAndContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    if (_page > 0)
                      IconButton(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                        icon: const Icon(Icons.arrow_back),
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        'Configura tu perfil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // Indicador de pasos
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: List.generate(4, (i) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? primary
                              : Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    _buildIdentityPage(primary),
                    _buildBodyPage(primary),
                    _buildGoalPage(primary),
                    _buildRemindersPage(primary),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      _page < 3 ? 'Continuar' : 'Empezar en Balancore',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentityPage(Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿Cómo te llamamos?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Estos datos se verán en tu perfil. Puedes cambiarlos después.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre (opcional)',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Usuario (opcional)',
              prefixIcon: Icon(Icons.alternate_email),
              border: OutlineInputBorder(),
              hintText: 'sin espacios',
            ),
          ),
          const SizedBox(height: 24),
          const Text('Sexo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _sexChip('Masculino', primary)),
              const SizedBox(width: 12),
              Expanded(child: _sexChip('Femenino', primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sexChip(String value, Color primary) {
    final selected = _sex == value;
    return InkWell(
      onTap: () => setState(() => _sex = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.15) : null,
          border: Border.all(color: selected ? primary : Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: selected ? primary : null,
          ),
        ),
      ),
    );
  }

  Widget _buildBodyPage(Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tus datos corporales',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Los usamos para calcular tus calorías y macros objetivo.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Edad',
              prefixIcon: Icon(Icons.cake_outlined),
              border: OutlineInputBorder(),
              suffixText: 'años',
            ),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 12 || n > 100) return 'Edad entre 12 y 100';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Peso actual',
              prefixIcon: Icon(Icons.monitor_weight_outlined),
              border: OutlineInputBorder(),
              suffixText: 'kg',
            ),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n < 30 || n > 300) return 'Peso no válido';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _heightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Altura',
              prefixIcon: Icon(Icons.height),
              border: OutlineInputBorder(),
              suffixText: 'cm',
            ),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n < 100 || n > 250) return 'Altura no válida';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nivel de actividad',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...UserProfile.activityLevels.map((level) {
            final selected = _activityLevel == level;
            final subtitle = switch (level) {
              'Sedentario' => 'Poco o nada de ejercicio',
              'Ligero' => '1–3 días / semana',
              'Moderado' => '3–5 días / semana',
              'Activo' => '6–7 días / semana',
              _ => 'Entrenamiento intenso diario',
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected ? primary : Colors.grey.shade300,
                  ),
                ),
                selected: selected,
                selectedTileColor: primary.withValues(alpha: 0.08),
                title: Text(level),
                subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
                trailing: selected
                    ? Icon(Icons.check_circle, color: primary)
                    : null,
                onTap: () => setState(() => _activityLevel = level),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGoalPage(Color primary) {
    final macros = _previewMacros;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tu objetivo',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajusta las calorías según lo que quieras lograr.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ...UserProfile.goals.map((g) {
            final selected = _goal == g;
            final subtitle = switch (g) {
              'Perder grasa' => 'Déficit ~15 % sobre tu gasto',
              'Ganar músculo' => 'Superávit ~10 % sobre tu gasto',
              _ => 'Mantener peso actual',
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selected ? primary : Colors.grey.shade300,
                  ),
                ),
                selected: selected,
                selectedTileColor: primary.withValues(alpha: 0.08),
                title: Text(g),
                subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
                trailing: selected
                    ? Icon(Icons.check_circle, color: primary)
                    : null,
                onTap: () => setState(() => _goal = g),
              ),
            );
          }),
          const SizedBox(height: 24),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Tu plan diario estimado',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$_previewCalories',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                  const Text('kcal / día', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _macroPreview('Prot', '${macros.protein} g', Colors.orange),
                      _macroPreview('Carb', '${macros.carbs} g', Colors.blue),
                      _macroPreview('Grasa', '${macros.fat} g', Colors.redAccent),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Podrás ajustar todo en tu perfil.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRemindersPage(Color primary) {
    String hhmm(int m) =>
        '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    final enabled = _wantNotifs == true;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      children: [
        Text(
          '¿Quieres recibir recordatorios?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Te avisamos de entrenar, comer, peso y racha. Puedes cambiarlo después en Ajustes.',
          style: TextStyle(color: onSurface.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: primary,
                  side: BorderSide(
                    color: primary,
                    width: _wantNotifs == false ? 2.5 : 1.5,
                  ),
                  backgroundColor: _wantNotifs == false
                      ? primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                ),
                onPressed: () => setState(() => _wantNotifs = false),
                child: Text(
                  'No',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  setState(() => _wantNotifs = true);
                  final ok =
                  await NotificationService.instance.requestPermission();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        ok
                            ? 'Permiso de notificaciones concedido'
                            : 'Activa las notificaciones en Ajustes del sistema',
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Sí',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_wantNotifs == null) ...[
          const SizedBox(height: 24),
          Text(
            'Elige Sí o No para continuar.',
            style: TextStyle(fontSize: 13, color: onSurface.withValues(alpha: 0.6)),
          ),
        ],
        if (enabled) ...[
          const SizedBox(height: 28),
          Text(
            'Horarios',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: primary,
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.fitness_center, color: primary),
            title: Text('Entrenamiento', style: TextStyle(color: onSurface)),
            subtitle: Text(hhmm(_workoutMin)),
            trailing: Icon(Icons.edit_outlined, color: onSurface),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                    hour: _workoutMin ~/ 60, minute: _workoutMin % 60),
              );
              if (picked != null) {
                setState(
                        () => _workoutMin = picked.hour * 60 + picked.minute);
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.restaurant, color: primary),
            title: Text('Comida', style: TextStyle(color: onSurface)),
            subtitle: Text(hhmm(_mealMin)),
            trailing: Icon(Icons.edit_outlined, color: onSurface),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime:
                TimeOfDay(hour: _mealMin ~/ 60, minute: _mealMin % 60),
              );
              if (picked != null) {
                setState(() => _mealMin = picked.hour * 60 + picked.minute);
              }
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.monitor_weight_outlined, color: primary),
            title: Text('Peso (semanal)', style: TextStyle(color: onSurface)),
            subtitle: Text(
              '${NotificationPreferences.weekdayNames[_weightWeekday]} · ${hhmm(_weightMin)}',
            ),
            trailing: Icon(Icons.edit_outlined, color: onSurface),
            onTap: () async {
              final day = await showModalBottomSheet<int>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        ListTile(
                          title:
                          Text(NotificationPreferences.weekdayNames[d]!),
                          onTap: () => Navigator.pop(ctx, d),
                        ),
                    ],
                  ),
                ),
              );
              if (day != null) setState(() => _weightWeekday = day);
              if (!mounted) return;
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                    hour: _weightMin ~/ 60, minute: _weightMin % 60),
              );
              if (picked != null) {
                setState(
                        () => _weightMin = picked.hour * 60 + picked.minute);
              }
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Avisos de racha (después de las 12:00)',
            style: TextStyle(fontWeight: FontWeight.w600, color: primary),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return primary;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return primary;
                }
                return Colors.transparent;
              }),
              side: WidgetStatePropertyAll(BorderSide(color: primary)),
            ),
            segments: const [
              ButtonSegment(value: 4, label: Text('Cada 4 h')),
              ButtonSegment(value: 6, label: Text('Cada 6 h')),
            ],
            selected: {_streakInterval},
            onSelectionChanged: (s) =>
                setState(() => _streakInterval = s.first),
          ),
          const SizedBox(height: 8),
          Text(
            _streakInterval == 4
                ? '12:00 · 16:00 · 20:00 — no perder la racha (3 de 4)'
                : '12:00 · 18:00 — no perder la racha (3 de 4)',
            style: TextStyle(
                fontSize: 12, color: onSurface.withValues(alpha: 0.65)),
          ),
        ],
      ],
    );
  }

  Widget _macroPreview(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
