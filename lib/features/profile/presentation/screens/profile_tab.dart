import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'weight_history_screen.dart';


class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B1228)),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (profile) {
        if (profile == null) {
          return const Center(child: Text('No hay perfil'));
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Header (foto + email) ─────────────────────
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF6B1228).withValues(alpha: 0.15),
                  backgroundImage: profile.photoUrl != null
                      ? NetworkImage(profile.photoUrl!)
                      : null,
                  child: profile.photoUrl == null
                      ? const Icon(Icons.person, size: 36, color: Color(0xFF6B1228))
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName ?? 'Usuario',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        profile.email ?? '',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Datos compactos ───────────────────────────
            const Text(
              'Tus datos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B1228),
              ),
            ),
            const SizedBox(height: 8),

            _DataTile(
              icon: Icons.wc,
              label: 'Sexo',
              value: profile.sex,
              onTap: () => _editSex(context, ref, profile),
            ),
            _DataTile(
              icon: Icons.monitor_weight_outlined,
              label: 'Peso',
              value: '${profile.currentWeight.toStringAsFixed(1)} kg',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WeightHistoryScreen(),
                  ),
                );
              },
              trailing: const Icon(Icons.show_chart, size: 20, color: Colors.grey),
            ),
            _DataTile(
              icon: Icons.height,
              label: 'Altura',
              value: '${profile.height.toStringAsFixed(0)} cm',
              onTap: () => _editNumber(
                context,
                ref,
                profile,
                field: 'height',
                label: 'Altura (cm)',
              ),
            ),
            _DataTile(
              icon: Icons.cake_outlined,
              label: 'Edad',
              value: '${profile.age} años',
              onTap: () => _editNumber(
                context,
                ref,
                profile,
                field: 'age',
                label: 'Edad',
              ),
            ),
            _DataTile(
              icon: Icons.fitness_center,
              label: 'Nivel de ejercicio',
              value: profile.activityLevel,
              onTap: () => _editActivity(context, ref, profile),
            ),
            _DataTile(
              icon: Icons.local_fire_department,
              label: 'Meta calórica',
              value: '${profile.targetCalories} kcal',
              onTap: null, // se recalcula al cambiar otros datos
            ),

            const SizedBox(height: 24),
            const Text(
              'Historial de entrenamientos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B1228),
              ),
            ),
            const SizedBox(height: 8),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Próximamente: aquí aparecerán\ntus entrenamientos registrados',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Recalcular TMB y guardar ───────────────────────────

  Future<void> _recalculateAndSave(WidgetRef ref, UserProfile profile) async {
    final newCalories = UserProfile.calculateTMB(
      sex: profile.sex,
      weight: profile.currentWeight,
      height: profile.height,
      age: profile.age,
      activityLevel: profile.activityLevel,
    );
    final updated = profile.copyWith(targetCalories: newCalories);
    await ref.read(profileRepositoryProvider).saveProfile(updated);
    ref.invalidate(userProfileProvider);
  }

  // ─── Editar sexo ────────────────────────────────────────

  void _editSex(BuildContext context, WidgetRef ref, UserProfile profile) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Masculino'),
                trailing: profile.sex == 'Masculino'
                    ? const Icon(Icons.check, color: Color(0xFF6B1228))
                    : null,
                onTap: () async {
                  final updated = profile.copyWith(sex: 'Masculino');
                  await _recalculateAndSave(ref, updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('Femenino'),
                trailing: profile.sex == 'Femenino'
                    ? const Icon(Icons.check, color: Color(0xFF6B1228))
                    : null,
                onTap: () async {
                  final updated = profile.copyWith(sex: 'Femenino');
                  await _recalculateAndSave(ref, updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Editar nivel de actividad ──────────────────────────

  void _editActivity(BuildContext context, WidgetRef ref, UserProfile profile) {
    const levels = ['Sedentario', 'Moderado', 'Experto'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: levels.map((level) {
              return ListTile(
                title: Text(level),
                trailing: profile.activityLevel == level
                    ? const Icon(Icons.check, color: Color(0xFF6B1228))
                    : null,
                onTap: () async {
                  final updated = profile.copyWith(activityLevel: level);
                  await _recalculateAndSave(ref, updated);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ─── Editar número (altura / edad) ──────────────────────

  void _editNumber(
      BuildContext context,
      WidgetRef ref,
      UserProfile profile, {
        required String field,
        required String label,
      }) {
    final controller = TextEditingController(
      text: field == 'height'
          ? profile.height.toStringAsFixed(0)
          : profile.age.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Editar $label'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B1228),
              ),
              onPressed: () async {
                final value = num.tryParse(controller.text);
                if (value == null) return;

                final UserProfile updated;
                if (field == 'height') {
                  updated = profile.copyWith(height: value.toDouble());
                } else {
                  updated = profile.copyWith(age: value.toInt());
                }

                await _recalculateAndSave(ref, updated);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

// ─── Tile reutilizable ────────────────────────────────────

class _DataTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _DataTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF6B1228)),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.edit, size: 18, color: Colors.grey)
              : null),
      onTap: onTap,
    );
  }
}