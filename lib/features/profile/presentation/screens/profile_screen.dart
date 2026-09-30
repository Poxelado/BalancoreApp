import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// --- MODELO PARA CADA DÍA DE RUTINA ---
class RoutineItem {
  String day;
  String title;
  String duration;
  int calories;
  bool isRestDay;

  RoutineItem({
    required this.day,
    required this.title,
    this.duration = '',
    this.calories = 0,
    this.isRestDay = false,
  });
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _currentIndex = 2; // Inicia en la pantalla de Rutinas

  // --- DATOS DEL PERFIL ---
  final TextEditingController _weightController = TextEditingController(text: '65');
  final TextEditingController _heightController = TextEditingController(text: '170');
  final TextEditingController _ageController = TextEditingController(text: '25');
  String _gender = 'Masculino';
  String _activityLevel = 'Sedentario';

  // --- CALORÍAS Y MACROS ---
  int _targetCalories = 1911;
  int _consumedCalories = 0;
  int _proteinGrams = 0;
  int _carbsGrams = 0;
  int _fatGrams = 0;
  final TextEditingController _addCalorieController = TextEditingController();
  final TextEditingController _addProteinController = TextEditingController();
  final TextEditingController _addCarbsController = TextEditingController();
  final TextEditingController _addFatController = TextEditingController();

  // Hidratación y Sueño
  int _waterGlasses = 0;
  final int _waterGoal = 8;
  double _sleepHours = 7.0;
  final double _sleepGoal = 8.0;

  // --- LISTA DE RUTINAS PERSONALIZABLES ---
  final List<RoutineItem> _routines = [
    RoutineItem(day: 'Lunes', title: 'Pecho', duration: '1h 30min', calories: 450),
    RoutineItem(day: 'Martes', title: 'Torso', duration: '1h 10min', calories: 380),
    RoutineItem(day: 'Miércoles', title: 'Descanso', isRestDay: true),
    RoutineItem(day: 'Jueves', title: 'Pierna', duration: '1h 30min', calories: 520),
    RoutineItem(day: 'Viernes', title: 'Trekking', duration: '2h 30min', calories: 700),
  ];

  @override
  void initState() {
    super.initState();
    _calculateTMB();
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _addCalorieController.dispose();
    _addProteinController.dispose();
    _addCarbsController.dispose();
    _addFatController.dispose();
    super.dispose();
  }

  void _calculateTMB() {
    double weight = double.tryParse(_weightController.text) ?? 65;
    double height = double.tryParse(_heightController.text) ?? 170;
    int age = int.tryParse(_ageController.text) ?? 25;

    double tmb = 0;
    if (_gender == 'Masculino') {
      tmb = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      tmb = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    double activityMultiplier = 1.2;
    if (_activityLevel == 'Moderado') {
      activityMultiplier = 1.55;
    } else if (_activityLevel == 'Experto') {
      activityMultiplier = 1.9;
    }

    setState(() {
      _targetCalories = (tmb * activityMultiplier).round();
    });
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    // AuthWrapper detecta user == null y muestra LoginScreen automáticamente
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
            onPressed: _signOut,
          ),
        ],
      ),
      body: _buildPage(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF6B1228),
        onTap: (index) => setState(() => _currentIndex = index),
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
        return _buildProfileScreen();
      case 1:
        return _buildCalorieScreen();
      case 2:
        return _buildRoutineScreen();
      default:
        return _buildCalorieScreen();
    }
  }

  // --- PANTALLA 1: PERFIL ---
  Widget _buildProfileScreen() {
    final user = ref.watch(authStateProvider).value;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // Email del usuario logueado
          if (user != null) ...[
            Text(
              'Sesión: ${user.email ?? "Usuario"}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Cuéntanos sobre ti',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B1228)),
          ),
          const SizedBox(height: 16),
          const Text('Género', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'Masculino', label: Text('Masculino'), icon: Icon(Icons.male)),
              ButtonSegment<String>(value: 'Femenino', label: Text('Femenino'), icon: Icon(Icons.female)),
            ],
            selected: {_gender},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _gender = newSelection.first;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Peso (kg)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _heightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Estatura (cm)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Edad', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          const Text('Nivel de ejercicio diario', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _activityLevel,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'Sedentario', child: Text('Sedentario (Poco o ningún ejercicio)')),
              DropdownMenuItem(value: 'Moderado', child: Text('Moderado (3 a 5 días/semana)')),
              DropdownMenuItem(value: 'Experto', child: Text('Experto / Activo (Entrenamiento intenso)')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _activityLevel = value);
              }
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B1228),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              _calculateTMB();
              setState(() => _currentIndex = 1);
            },
            child: const Text('Continuar', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          const SizedBox(height: 16),
          // Botón de cerrar sesión también aquí (opcional)
          OutlinedButton.icon(
            onPressed: _signOut,
            icon: const Icon(Icons.logout, color: Color(0xFF6B1228)),
            label: const Text('Cerrar sesión', style: TextStyle(color: Color(0xFF6B1228))),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF6B1228)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  // --- PANTALLA 2: CALORÍAS ---
  Widget _buildCalorieScreen() {
    double progress = (_consumedCalories / _targetCalories).clamp(0.0, 1.0);
    int remainingCalories = _targetCalories - _consumedCalories;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text(
            'Resumen Nutricional del Día',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B1228)),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 110,
                          height: 110,
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
                            Text('$_consumedCalories', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const Text('kcal', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCalorieInfoRow('Meta calculada:', '$_targetCalories kcal', Colors.black),
                        const SizedBox(height: 8),
                        _buildCalorieInfoRow(
                          'Restantes:',
                          '${remainingCalories >= 0 ? remainingCalories : 0} kcal',
                          remainingCalories < 0 ? Colors.red : Colors.green,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          color: const Color(0xFF6B1228),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Macronutrientes Consumidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroBadge('Proteínas', '${_proteinGrams}g', Colors.orange),
                      _buildMacroBadge('Carbohidratos', '${_carbsGrams}g', Colors.blue),
                      _buildMacroBadge('Grasas', '${_fatGrams}g', Colors.redAccent),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ingresar Registro Rápido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addCalorieController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Calorías (kcal)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B1228),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onPressed: _addCustomCalories,
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Agregar', style: TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _showDetailedMacroDialog,
                    icon: const Icon(Icons.tune, color: Color(0xFF6B1228)),
                    label: const Text('Ajustar macros detalladamente', style: TextStyle(color: Color(0xFF6B1228))),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.water_drop, color: Colors.blue, size: 30),
                      const SizedBox(width: 10),
                      Text('Agua: $_waterGlasses / $_waterGoal vasos', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue, size: 32),
                    onPressed: () {
                      setState(() {
                        if (_waterGlasses < _waterGoal) _waterGlasses++;
                      });
                    },
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Colors.indigo.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bedtime, color: Colors.indigo, size: 30),
                      const SizedBox(width: 10),
                      Text(
                        'Sueño: ${_sleepHours.toStringAsFixed(1)} / ${_sleepGoal.toStringAsFixed(0)} hrs',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.indigo),
                        onPressed: () {
                          setState(() {
                            if (_sleepHours >= 0.5) _sleepHours -= 0.5;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: Colors.indigo, size: 32),
                        onPressed: () {
                          setState(() {
                            if (_sleepHours < 24) _sleepHours += 0.5;
                          });
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- PANTALLA 3: RUTINA ---
  Widget _buildRoutineScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tu rutina semanal de ejercicio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF6B1228)),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Color(0xFF6B1228)),
                onPressed: () => _showEditRoutineDialog(),
              )
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _routines.length,
              itemBuilder: (context, index) {
                final item = _routines[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.isRestDay
                          ? Colors.blueGrey.shade100
                          : const Color(0xFF6B1228).withValues(alpha: 0.15),
                      child: Icon(
                        item.isRestDay ? Icons.bed : Icons.fitness_center,
                        color: item.isRestDay ? Colors.blueGrey : const Color(0xFF6B1228),
                      ),
                    ),
                    title: Text(
                      '${item.day} - ${item.title}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      item.isRestDay
                          ? 'Día de descanso y recuperación'
                          : '${item.duration} | ${item.calories} kcal',
                      style: TextStyle(color: item.isRestDay ? Colors.grey.shade600 : Colors.black87),
                    ),
                    trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
                    onTap: () => _showEditRoutineDialog(item: item, index: index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- DIÁLOGO PARA EDITAR / AGREGAR RUTINAS ---
  void _showEditRoutineDialog({RoutineItem? item, int? index}) {
    final dayController = TextEditingController(text: item?.day ?? '');
    final titleController = TextEditingController(text: item?.title ?? '');
    final durationController = TextEditingController(text: item?.duration ?? '');
    final caloriesController = TextEditingController(
      text: item != null && !item.isRestDay ? item.calories.toString() : '',
    );
    bool isRest = item?.isRestDay ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(item == null ? 'Agregar Día a la Rutina' : 'Editar Rutina'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: dayController,
                      decoration: const InputDecoration(
                        labelText: 'Día (ej. Lunes, Sábado)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('¿Es día de Descanso?'),
                      value: isRest,
                      activeColor: const Color(0xFF6B1228),
                      onChanged: (val) {
                        setDialogState(() {
                          isRest = val;
                          if (isRest) titleController.text = 'Descanso';
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    if (!isRest) ...[
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Enfoque / Ejercicio (ej. Pecho, Cardio)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duración (ej. 1h 30min)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: caloriesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Calorías estimadas (kcal)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              actions: [
                if (index != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() => _routines.removeAt(index));
                      Navigator.pop(context);
                    },
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B1228)),
                  onPressed: () {
                    if (dayController.text.isEmpty) return;
                    setState(() {
                      final newItem = RoutineItem(
                        day: dayController.text,
                        title: isRest
                            ? 'Descanso'
                            : (titleController.text.isEmpty ? 'Ejercicio' : titleController.text),
                        duration: isRest ? '' : durationController.text,
                        calories: isRest ? 0 : (int.tryParse(caloriesController.text) ?? 0),
                        isRestDay: isRest,
                      );
                      if (index != null) {
                        _routines[index] = newItem;
                      } else {
                        _routines.add(newItem);
                      }
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCalorieInfoRow(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildMacroBadge(String title, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _addCustomCalories() {
    int? added = int.tryParse(_addCalorieController.text);
    if (added != null && added > 0) {
      setState(() {
        _consumedCalories += added;
        _addCalorieController.clear();
      });
    }
  }

  void _showDetailedMacroDialog() {
    _addProteinController.text = _proteinGrams.toString();
    _addCarbsController.text = _carbsGrams.toString();
    _addFatController.text = _fatGrams.toString();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ajustar Macronutrientes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _addProteinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Proteínas (g)'),
              ),
              TextField(
                controller: _addCarbsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Carbohidratos (g)'),
              ),
              TextField(
                controller: _addFatController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Grasas (g)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B1228)),
              onPressed: () {
                setState(() {
                  _proteinGrams = int.tryParse(_addProteinController.text) ?? _proteinGrams;
                  _carbsGrams = int.tryParse(_addCarbsController.text) ?? _carbsGrams;
                  _fatGrams = int.tryParse(_addFatController.text) ?? _fatGrams;
                });
                Navigator.pop(context);
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}