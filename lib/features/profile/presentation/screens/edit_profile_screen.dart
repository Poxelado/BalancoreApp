import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _ageController;

  late String _sex;
  late String _activityLevel;
  late String _goal;
  late int _targetCalories;
  late int _targetProtein;
  late int _targetCarbs;
  late int _targetFat;
  late final TextEditingController _caloriesController;

  bool _isLoading = false;
  bool _manualCalories = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameController = TextEditingController(text: p.displayName ?? '');
    _usernameController = TextEditingController(text: p.username ?? '');
    _bioController = TextEditingController(text: p.bio ?? '');
    _weightController =
        TextEditingController(text: p.currentWeight.toStringAsFixed(1));
    _heightController =
        TextEditingController(text: p.height.toStringAsFixed(0));
    _ageController = TextEditingController(text: '${p.age}');
    _sex = p.sex;
    _activityLevel = UserProfile.activityLevels.contains(p.activityLevel)
        ? p.activityLevel
        : 'Sedentario';
    _goal = UserProfile.goals.contains(p.goal) ? p.goal : 'Mantenimiento';
    _targetCalories = p.targetCalories;
    _targetProtein = p.targetProtein;
    _targetCarbs = p.targetCarbs;
    _targetFat = p.targetFat;
    _caloriesController = TextEditingController(text: '${p.targetCalories}');

    // Si no hay macros guardados, calcular
    if (_targetProtein == 0) {
      _recalculate(silent: true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _recalculate({bool silent = false}) {
    final weight = double.tryParse(_weightController.text) ??
        widget.profile.currentWeight;
    final height =
        double.tryParse(_heightController.text) ?? widget.profile.height;
    final age = int.tryParse(_ageController.text) ?? widget.profile.age;

    final cal = UserProfile.calculateTMB(
      sex: _sex,
      weight: weight,
      height: height,
      age: age,
      activityLevel: _activityLevel,
      goal: _goal,
    );
    final macros = UserProfile.calculateMacros(
      weight: weight,
      calories: cal,
      goal: _goal,
    );

    setState(() {
      _targetCalories = cal;
      _targetProtein = macros.protein;
      _targetCarbs = macros.carbs;
      _targetFat = macros.fat;
      _manualCalories = false;
      _caloriesController.text = '$cal';
    });

    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recalculado: $cal kcal · P $_targetProtein g'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _save() async {
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    final age = int.tryParse(_ageController.text);

    if (weight == null || height == null || age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa peso, altura y edad'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final updated = widget.profile.copyWith(
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        username: _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim().replaceAll('@', ''),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        sex: _sex,
        currentWeight: weight,
        height: height,
        age: age,
        activityLevel: _activityLevel,
        goal: _goal,
        targetCalories: _targetCalories,
        targetProtein: _targetProtein,
        targetCarbs: _targetCarbs,
        targetFat: _targetFat,
      );

      await ref.read(profileRepositoryProvider).saveProfile(updated);
      ref.invalidate(userProfileProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Text(
              'Guardar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Identidad', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Usuario',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.alternate_email),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Bio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Datos corporales',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sex,
                  decoration: const InputDecoration(
                    labelText: 'Sexo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'Masculino', child: Text('Masculino')),
                    DropdownMenuItem(
                        value: 'Femenino', child: Text('Femenino')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _sex = v);
                    if (!_manualCalories) _recalculate(silent: true);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Edad',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (!_manualCalories) _recalculate(silent: true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso (kg)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (!_manualCalories) _recalculate(silent: true);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Altura (cm)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (!_manualCalories) _recalculate(silent: true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _activityLevel,
            decoration: const InputDecoration(
              labelText: 'Nivel de actividad',
              border: OutlineInputBorder(),
            ),
            items: UserProfile.activityLevels
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _activityLevel = v);
              if (!_manualCalories) _recalculate(silent: true);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _goal,
            decoration: const InputDecoration(
              labelText: 'Objetivo',
              border: OutlineInputBorder(),
            ),
            items: UserProfile.goals
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _goal = v);
              if (!_manualCalories) _recalculate(silent: true);
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Targets nutricionales',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _recalculate(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Recalcular'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _caloriesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Calorías objetivo (kcal)',
              border: const OutlineInputBorder(),
              helperText: _manualCalories
                  ? 'Valor manual'
                  : 'Calculado según tus datos',
            ),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0) {
                setState(() {
                  _targetCalories = n;
                  _manualCalories = true;
                  final weight = double.tryParse(_weightController.text) ??
                      widget.profile.currentWeight;
                  final macros = UserProfile.calculateMacros(
                    weight: weight,
                    calories: n,
                    goal: _goal,
                  );
                  _targetProtein = macros.protein;
                  _targetCarbs = macros.carbs;
                  _targetFat = macros.fat;
                });
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _macroBox('Proteína', '$_targetProtein g', Colors.orange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroBox('Carbos', '$_targetCarbs g', Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroBox('Grasas', '$_targetFat g', Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _macroBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
