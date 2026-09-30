import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'weight_history_screen.dart';
import 'edit_profile_screen.dart';

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

        final username = profile.username?.isNotEmpty == true
            ? '@${profile.username}'
            : '@usuario';

        return CustomScrollView(
          slivers: [
            // ─── Mini barra superior ───────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        username,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Editar perfil
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar perfil',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(profile: profile),
                          ),
                        );
                      },
                    ),
                    // Ajustes (próximamente)
                    IconButton(
                      icon: const Icon(Icons.settings_outlined),
                      tooltip: 'Ajustes',
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ajustes — próximamente'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ─── Header: avatar + stats ────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: const Color(0xFF6B1228).withValues(alpha: 0.15),
                      // Si más adelante hay photoUrl de otro lado, se puede usar
                      backgroundImage: profile.photoUrl != null
                          ? NetworkImage(profile.photoUrl!)
                          : null,
                      child: profile.photoUrl == null
                          ? Text(
                        _initials(profile),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B1228),
                        ),
                      )
                          : null,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatColumn(
                            value: '0',
                            label: 'Entrenos',
                          ),
                          _StatColumn(
                            value: '${profile.currentWeight.toStringAsFixed(0)}',
                            label: 'kg',
                          ),
                          _StatColumn(
                            value: '${profile.targetCalories}',
                            label: 'kcal meta',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Nombre + bio
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName ?? 'Usuario',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile.bio!,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${profile.sex} · ${profile.height.toStringAsFixed(0)} cm · ${profile.activityLevel}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Botones: Próximamente | Peso ──────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Escaneo corporal — próximamente'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.accessibility_new, size: 18),
                        label: const Text('Próximamente'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WeightHistoryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                        label: const Text('Peso'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B1228),
                          side: const BorderSide(color: Color(0xFF6B1228)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Filtro temporal del historial ─────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Text(
                      'Historial de entrenamientos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B1228),
                      ),
                    ),
                    const Spacer(),
                    _PeriodChip(label: '1M', selected: true),
                    _PeriodChip(label: '3M'),
                    _PeriodChip(label: '6M'),
                    _PeriodChip(label: '1A'),
                  ],
                ),
              ),
            ),

            // ─── Grid de entrenamientos (placeholder) ─────
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    // Placeholder hasta que registremos entrenos reales
                    return _WorkoutCardPlaceholder(
                      date: _placeholderDates[index % _placeholderDates.length],
                      duration: _placeholderDurations[index % _placeholderDurations.length],
                      isEmpty: index > 2, // solo 3 de ejemplo “con datos”
                    );
                  },
                  childCount: 6,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }
}

// Fechas de ejemplo (solo visual)
const _placeholderDates = ['22/09', '20/09', '18/09', '15/09', '12/09', '10/09'];
const _placeholderDurations = ['50m', '1h 2m', '45m', '38m', '1h', '40m'];

// ─── Widgets auxiliares ───────────────────────────────────

String _initials(UserProfile profile) {
  final name = profile.displayName ?? profile.username ?? profile.email ?? 'U';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : 'U';
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _PeriodChip({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6B1228)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _WorkoutCardPlaceholder extends StatelessWidget {
  final String date;
  final String duration;
  final bool isEmpty;

  const _WorkoutCardPlaceholder({
    required this.date,
    required this.duration,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isEmpty ? Colors.grey.shade100 : const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              date,
              style: TextStyle(
                fontSize: 10,
                color: isEmpty ? Colors.grey : Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Icon(
              Icons.accessibility_new,
              size: 48,
              color: isEmpty
                  ? Colors.grey.shade300
                  : const Color(0xFF6B1228).withValues(alpha: 0.8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              isEmpty ? '—' : duration,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isEmpty ? Colors.grey : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}