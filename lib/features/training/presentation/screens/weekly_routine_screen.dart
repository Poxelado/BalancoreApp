import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/routine_templates.dart';
import 'edit_routine_day_screen.dart';

class WeeklyRoutineScreen extends ConsumerWidget {
  const WeeklyRoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutina semanal'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => _showTemplates(context, ref),
            child: const Text(
              'Plantillas',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: routinesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (days) {
          if (days.isEmpty) {
            return const Center(child: Text('No hay días configurados'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final day = days[i];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: day.isRestDay
                        ? Colors.blueGrey.withValues(alpha: 0.2)
                        : primary.withValues(alpha: 0.15),
                    child: Text(
                      day.day.substring(0, 2),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: day.isRestDay ? Colors.blueGrey : primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    day.day,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    day.isRestDay
                        ? 'Descanso'
                        : '${day.title} · ${day.exercises.length} ejercicios'
                        '${day.duration.isNotEmpty ? ' · ${day.duration}' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditRoutineDayScreen(day: day),
                      ),
                    );
                    ref.invalidate(routinesProvider);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showTemplates(BuildContext context, WidgetRef ref) async {
    final primary = Theme.of(context).colorScheme.primary;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Elegir plantilla',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reemplaza tu semana actual. Luego puedes editar cada día.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ...RoutineTemplates.all.map((t) {
                  return Card(
                    child: ListTile(
                      title: Text(t.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(t.description),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('Aplicar plantilla'),
                            content: Text(
                              'Se reemplazará tu rutina semanal por "${t.name}". ¿Continuar?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dCtx, true),
                                child: const Text('Aplicar'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        final user =
                            ref.read(authServiceProvider).currentUser;
                        if (user == null) return;
                        await ref
                            .read(profileRepositoryProvider)
                            .saveAllRoutines(user.uid, t.week);
                        ref.invalidate(routinesProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Plantilla "${t.name}" aplicada'),
                            ),
                          );
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
