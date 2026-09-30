import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'package:balancore/features/profile/presentation/screens/profile_tab.dart';
import 'package:balancore/features/profile/presentation/screens/routine_tab.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _currentIndex = 0;

  // ─── Estado local de Calorías (lo dejas por ahora) ───────
  int _targetCalories = 1911;
  int _consumedCalories = 0;
  int _proteinGrams = 0;
  int _carbsGrams = 0;
  int _fatGrams = 0;
  final _addCalorieController = TextEditingController();
  final _addProteinController = TextEditingController();
  final _addCarbsController = TextEditingController();
  final _addFatController = TextEditingController();

  @override
  void dispose() {
    _addCalorieController.dispose();
    _addProteinController.dispose();
    _addCarbsController.dispose();
    _addFatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6B1228),
        title: const Text(
          'Balancore',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: _buildPage(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF6B1228),
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Calorías'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Rutina'),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return ProfileTab();          // sin const
      case 1:
        return _buildCalorieScreen();
      case 2:
        return RoutineTab();          // sin const
      default:
        return ProfileTab();          // sin const
    }
  }

  // ─── Calorías (tu versión actual simplificada) ───────────
  Widget _buildCalorieScreen() {
    final progress = _targetCalories > 0
        ? (_consumedCalories / _targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final remaining = _targetCalories - _consumedCalories;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          const Text(
            'Resumen Nutricional del Día',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B1228),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 100,
                          height: 100,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey.shade200,
                            color: const Color(0xFF6B1228),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$_consumedCalories',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold)),
                            const Text('kcal',
                                style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Meta: $_targetCalories kcal',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(
                          'Restantes: ${remaining >= 0 ? remaining : 0} kcal',
                          style: TextStyle(
                            color: remaining < 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Macros
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _macroChip('Proteínas', '$_proteinGrams g', Colors.orange),
              _macroChip('Carbos', '$_carbsGrams g', Colors.blue),
              _macroChip('Grasas', '$_fatGrams g', Colors.redAccent),
            ],
          ),
          const SizedBox(height: 16),
          // Agregar calorías rápido
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addCalorieController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Calorías (kcal)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B1228),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onPressed: () {
                  final v = int.tryParse(_addCalorieController.text);
                  if (v != null && v > 0) {
                    setState(() {
                      _consumedCalories += v;
                      _addCalorieController.clear();
                    });
                  }
                },
                child: const Text('Agregar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}