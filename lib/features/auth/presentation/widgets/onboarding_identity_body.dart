part of 'onboarding_pages.dart';

/// Página 1: identidad (nombre opcional y sexo).
class IdentityPage extends StatelessWidget {
  final TextEditingController nameController;
  final String sex;
  final Color primary;
  final ValueChanged<String> onSexChanged;

  const IdentityPage({
    super.key,
    required this.nameController,
    required this.sex,
    required this.primary,
    required this.onSexChanged,
  });

  @override
  Widget build(BuildContext context) {
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
            'Tu usuario ya quedó definido al crear la cuenta. Aquí solo el nombre (opcional) y el sexo.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre (opcional)',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Sexo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _sexChip('Masculino')),
              const SizedBox(width: 12),
              Expanded(child: _sexChip('Femenino')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sexChip(String value) {
    final selected = sex == value;
    return InkWell(
      onTap: () => onSexChanged(value),
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
}

/// Página 2: datos corporales (edad, peso, altura, actividad y agua).
class BodyPage extends StatelessWidget {
  final TextEditingController ageController;
  final TextEditingController weightController;
  final TextEditingController heightController;
  final String activityLevel;
  final Color primary;
  final ValueChanged<String> onActivityChanged;
  final VoidCallback onFieldChanged;

  const BodyPage({
    super.key,
    required this.ageController,
    required this.weightController,
    required this.heightController,
    required this.activityLevel,
    required this.primary,
    required this.onActivityChanged,
    required this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
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
            controller: ageController,
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
            onChanged: (_) => onFieldChanged(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: weightController,
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
            onChanged: (_) => onFieldChanged(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: heightController,
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
            onChanged: (_) => onFieldChanged(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nivel de actividad',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Úsalo para estimar tus calorías. Luego se puede refinar con tus entrenos.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ..._activityOptions(),
          const SizedBox(height: 24),
          // Agua recomendada según peso
          Builder(
            builder: (context) {
              final w = double.tryParse(weightController.text) ?? 70;
              final ml = UserProfile.calculateWaterMl(weightKg: w);
              final glasses = UserProfile.waterGlassesFromMl(ml);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.water_drop, color: accentOf(context), size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agua recomendada',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: accentOf(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$ml ml/día  ·  ~$glasses vasos',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Se calcula con tu peso (~35 ml/kg). Se ajustará solo.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _activityOptions() {
    const items = <(String, String)>[
      ('Sedentario', 'Poco o nada de ejercicio'),
      ('Ligero', '1–3 días / semana'),
      ('Moderado', '3–5 días / semana'),
      ('Activo', '6–7 días / semana'),
      ('Muy activo', 'Entrenamiento intenso diario'),
    ];
    return [
      for (final (value, subtitle) in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: activityLevel == value
                ? primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onActivityChanged(value),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activityLevel == value
                        ? primary
                        : Colors.grey.shade400,
                    width: activityLevel == value ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: activityLevel == value ? primary : null,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (activityLevel == value)
                      Icon(Icons.check_circle, color: primary, size: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }
}
