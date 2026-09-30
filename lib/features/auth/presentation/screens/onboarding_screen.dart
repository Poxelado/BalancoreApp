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
  final _weightController = TextEditingController(text: '65');
  final _heightController = TextEditingController(text: '170');
  final _ageController = TextEditingController(text: '25');

  String _gender = 'Masculino';
  String _activityLevel = 'Sedentario';
  bool _isLoading = false;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
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

      final targetCalories = UserProfile.calculateTMB(
        sex: _gender,
        weight: weight,
        height: height,
        age: age,
        activityLevel: _activityLevel,
      );

      final profile = UserProfile(
        uid: user.uid,
        email: user.email,
        sex: _gender, // puedes renombrar la variable a _sex
        currentWeight: weight,
        height: height,
        age: age,
        activityLevel: _activityLevel,
        targetCalories: targetCalories,
        onboardingCompleted: true,
        createdAt: DateTime.now(),
      );

      await ref.read(profileRepositoryProvider).saveProfile(profile);
      await ref.read(profileRepositoryProvider).addWeightEntry(
        user.uid,
        weight,
        DateTime.now(),
      );
      await ref.read(profileRepositoryProvider).saveAllRoutines(
        user.uid,
        // las 7 del default
        [
          RoutineDay(day: 'Lunes', title: 'Pecho', duration: '1h 30min', calories: 450),
          RoutineDay(day: 'Martes', title: 'Espalda', duration: '1h 10min', calories: 380),
          RoutineDay(day: 'Miércoles', title: 'Descanso', isRestDay: true),
          RoutineDay(day: 'Jueves', title: 'Pierna', duration: '1h 30min', calories: 520),
          RoutineDay(day: 'Viernes', title: 'Hombros', duration: '1h', calories: 350),
          RoutineDay(day: 'Sábado', title: 'Cardio', duration: '45min', calories: 400),
          RoutineDay(day: 'Domingo', title: 'Descanso', isRestDay: true),
        ],
      );

      // Invalidar el provider para que AuthWrapper se actualice
      ref.invalidate(userProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                const SizedBox(height: 16),
                const Text(
                  '¡Bienvenido a Balancore!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B1228),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cuéntanos un poco sobre ti para calcular tu plan',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 32),

                // Género
                const Text('Género', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Masculino', label: Text('Masculino'), icon: Icon(Icons.male)),
                    ButtonSegment(value: 'Femenino', label: Text('Femenino'), icon: Icon(Icons.female)),
                  ],
                  selected: {_gender},
                  onSelectionChanged: (s) => setState(() => _gender = s.first),
                ),
                const SizedBox(height: 20),

                // Peso
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Peso (kg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu peso';
                    if (double.tryParse(v) == null) return 'Número inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Altura
                TextFormField(
                  controller: _heightController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Estatura (cm)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.height),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu estatura';
                    if (double.tryParse(v) == null) return 'Número inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Edad
                TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Edad',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa tu edad';
                    if (int.tryParse(v) == null) return 'Número inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Nivel de actividad
                const Text('Nivel de ejercicio diario', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _activityLevel,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'Sedentario', child: Text('Sedentario (poco o ningún ejercicio)')),
                    DropdownMenuItem(value: 'Moderado', child: Text('Moderado (3-5 días/semana)')),
                    DropdownMenuItem(value: 'Experto', child: Text('Experto (entrenamiento intenso)')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _activityLevel = v);
                  },
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B1228),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : const Text(
                    'Continuar',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}