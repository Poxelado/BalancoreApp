import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/auth_provider.dart';

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
      // Validar nombre opcional, username opcional — pasar a datos
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
                  children: List.generate(3, (i) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
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
                      _page < 2 ? 'Continuar' : 'Empezar en Balancore',
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

  Widget _macroPreview(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
