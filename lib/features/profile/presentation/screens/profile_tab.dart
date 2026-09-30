import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/user_profile.dart';
import '../providers/profile_provider.dart';
import 'weight_history_screen.dart';
import 'edit_profile_screen.dart';
import 'daily_history_screen.dart';


class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  String _initials(UserProfile profile) {
    final name =
        profile.displayName ?? profile.username ?? profile.email ?? 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

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

        return CustomScrollView(
          slivers: [
            // ─── Avatar + stats ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(profile: profile),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor:
                        const Color(0xFF6B1228).withValues(alpha: 0.15),
                        child: Text(
                          _initials(profile),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B1228),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatColumn(value: '0', label: 'Entrenos'),
                          _StatColumn(
                            value: profile.currentWeight.toStringAsFixed(0),
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

            // ─── Nombre + bio + datos ─────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile.displayName != null &&
                        profile.displayName!.isNotEmpty)
                      Text(
                        profile.displayName!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        profile.bio!,
                        style: const TextStyle(fontSize: 13),
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

            // ─── Botones Próximamente | Peso ───────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DailyHistoryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('Historial'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B1228),
                          side: const BorderSide(color: Color(0xFF6B1228)),
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

            // ─── Historial ─────────────────────────────────
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
                    return _WorkoutCardPlaceholder(
                      date: _placeholderDates[index % _placeholderDates.length],
                      duration: _placeholderDurations[
                      index % _placeholderDurations.length],
                      isEmpty: index > 2,
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

const _placeholderDates = ['22/09', '20/09', '18/09', '15/09', '12/09', '10/09'];
const _placeholderDurations = ['50m', '1h 2m', '45m', '38m', '1h', '40m'];

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
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
          color: selected ? const Color(0xFF6B1228) : Colors.grey.shade200,
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
                  : const Color(0xFF6B1228).withValues(alpha: 0.85),
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