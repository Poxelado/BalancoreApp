import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/preferences/units_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/user_profile.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/input_limits.dart';
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
  late final UnitSystem _units;

  @override
  void initState() {
    super.initState();
    _units = ref.read(unitsProvider);
    final p = widget.profile;
    _nameController = TextEditingController(text: p.displayName ?? '');
    _usernameController = TextEditingController(text: p.username ?? '');
    _bioController = TextEditingController(text: p.bio ?? '');
    _weightController = TextEditingController(
        text: _units.weightToDisplay(p.currentWeight).toStringAsFixed(1));
    _heightController = TextEditingController(
        text: _units.heightToDisplay(p.height).toStringAsFixed(0));
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

  /// Peso del formulario convertido a kg (unidad interna de cálculo).
  double _weightKg() {
    final v = double.tryParse(_weightController.text.replaceAll(',', '.'));
    return v == null ? widget.profile.currentWeight : _units.weightToKg(v);
  }

  /// Altura del formulario convertida a cm (unidad interna de cálculo).
  double _heightCm() {
    final v = double.tryParse(_heightController.text.replaceAll(',', '.'));
    return v == null ? widget.profile.height : _units.heightToCm(v);
  }

  void _recalculate({bool silent = false}) {
    final weight = _weightKg();
    final height = _heightCm();
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
      height: height,
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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// Valida en unidades internas (kg/cm) para no depender de la unidad visible.
  String? _validateRanges({
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    return Validators.doubleInRange(
          '$weightKg',
          min: InputLimits.weightKgMin,
          max: InputLimits.weightKgMax,
          label: 'Peso',
        ) ??
        Validators.doubleInRange(
          '$heightCm',
          min: InputLimits.heightCmMin,
          max: InputLimits.heightCmMax,
          label: 'Altura',
        ) ??
        Validators.intInRange(
          '$age',
          min: InputLimits.ageMin,
          max: InputLimits.ageMax,
          label: 'Edad',
        );
  }

  Future<void> _save() async {
    final rawWeight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    final rawHeight = double.tryParse(_heightController.text.replaceAll(',', '.'));
    final age = int.tryParse(_ageController.text);

    if (rawWeight == null || rawHeight == null || age == null) {
      _showError('Revisa peso, altura y edad');
      return;
    }
    final weight = _units.weightToKg(rawWeight);
    final height = _units.heightToCm(rawHeight);

    final rangeError = _validateRanges(
      weightKg: weight,
      heightCm: height,
      age: age,
    );
    if (rangeError != null) {
      _showError(rangeError);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final newUsername = Validators.cleanUsername(_usernameController.text);
      final usernameError = Validators.username(newUsername);
      if (usernameError != null) {
        throw ValidationException(usernameError);
      }
      if (_nameController.text.trim().length > InputLimits.nameMax) {
        throw const ValidationException(
            'El nombre es demasiado largo.');
      }
      if (_bioController.text.trim().length > InputLimits.bioMax) {
        throw const ValidationException('La bio es demasiado larga.');
      }

      final oldU = (widget.profile.username ?? '').toLowerCase();
      var changeDates = List<String>.from(widget.profile.usernameChangeDates);
      if (newUsername != oldU) {
        if (!widget.profile.canChangeUsername) {
          throw const ValidationException('Ya cambiaste el usuario 3 veces en los últimos 30 días.');
        }
        await ref.read(profileRepositoryProvider).changeUsername(
          uid: widget.profile.uid,
          oldUsername: widget.profile.username,
          newUsername: newUsername,
        );
        changeDates.add(DateTime.now().toIso8601String());
      }

      final waterMl = UserProfile.calculateWaterMl(weightKg: weight);

      final updated = widget.profile.copyWith(
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        username: newUsername,
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
        targetWaterMl: waterMl,
        usernameChangeDates: changeDates,
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
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
            inputFormatters: InputFormatters.text(InputLimits.nameMax),
            decoration: const InputDecoration(
              labelText: 'Nombre (opcional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Correo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
              helperText: 'El correo no se puede cambiar',
            ),
            child: Text(
              widget.profile.email ?? '—',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _usernameController,
            inputFormatters: InputFormatters.text(InputLimits.usernameMax),
            decoration: InputDecoration(
              labelText: 'Usuario *',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.alternate_email),
              helperText: widget.profile.canChangeUsername
                  ? 'Máximo 3 cambios en 30 días (usados: ${widget.profile.usernameChangesLast30Days()}/3)'
                  : 'Límite de 3 cambios/mes alcanzado',
            ),
            enabled: widget.profile.canChangeUsername ||
                _usernameController.text.trim().toLowerCase() ==
                    (widget.profile.username ?? ''),
            validator: Validators.username,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLines: 2,
            inputFormatters: InputFormatters.text(InputLimits.bioMax),
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
                  initialValue: _sex,
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
                  inputFormatters: InputFormatters.digits(maxLength: 3),
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
                  inputFormatters: InputFormatters.decimal(maxLength: 6),
                  decoration: InputDecoration(
                    labelText: 'Peso (${_units.weightUnit})',
                    border: const OutlineInputBorder(),
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
                  inputFormatters: InputFormatters.decimal(maxLength: 6),
                  decoration: InputDecoration(
                    labelText: 'Altura (${_units.heightUnit})',
                    border: const OutlineInputBorder(),
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
            initialValue: UserProfile.activityLevels.contains(_activityLevel)
                ? _activityLevel
                : 'Sedentario',
            decoration: const InputDecoration(
              labelText: 'Nivel de actividad',
              border: OutlineInputBorder(),
              helperText: 'Influye en el cálculo de calorías objetivo',
            ),
            items: UserProfile.activityLevels
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _activityLevel = v);
              if (!_manualCalories) _recalculate(silent: true);
            },
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final ml = UserProfile.calculateWaterMl(weightKg: _weightKg());
              final glasses = UserProfile.waterGlassesFromMl(ml);
              return InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Agua recomendada',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop_outlined),
                  helperText: 'Se calcula con tu peso (~35 ml/kg)',
                ),
                child: Text(
                  '$ml ml/día  ·  ~$glasses vasos de 250 ml',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _goal,
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
            inputFormatters: InputFormatters.digits(maxLength: 5),
            decoration: InputDecoration(
              labelText: 'Calorías objetivo (kcal)',
              border: const OutlineInputBorder(),
              helperText: _manualCalories
                  ? 'Valor manual'
                  : 'Calculado según tus datos',
            ),
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0 && n <= InputLimits.caloriesMax) {
                setState(() {
                  _targetCalories = n;
                  _manualCalories = true;
                  final macros = UserProfile.calculateMacros(
                    weight: _weightKg(),
                    height: _heightCm(),
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
                child: _macroBox('Proteína', '$_targetProtein g', AppDataColors.protein),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroBox('Carbos', '$_targetCarbs g', AppDataColors.carbs),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _macroBox('Grasas', '$_targetFat g', AppDataColors.fat),
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
