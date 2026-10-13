import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/routine_templates.dart';
import '../providers/exercise_provider.dart';
import 'edit_routine_day_screen.dart';
import 'routine_generator_screen.dart';
import '../../../../core/theme/app_theme.dart';

class WeeklyRoutineScreen extends ConsumerStatefulWidget {
  const WeeklyRoutineScreen({super.key});

  @override
  ConsumerState<WeeklyRoutineScreen> createState() =>
      _WeeklyRoutineScreenState();
}

class _WeeklyRoutineScreenState extends ConsumerState<WeeklyRoutineScreen> {
  /// Por defecto en bloques (2 por fila); se puede cambiar a cascada.
  bool _gridView = true;

  Future<void> _editDay(RoutineDay day) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditRoutineDayScreen(day: day)),
    );
    ref.invalidate(routinesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final primary = accentOf(context);
    final routinesAsync = ref.watch(routinesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutina semanal'),
        actions: [
          IconButton(
            tooltip: _gridView ? 'Ver como cascada' : 'Ver en bloques',
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
        ],
      ),
      body: routinesAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: accentOf(context))),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (days) {
          if (days.isEmpty) {
            return const Center(child: Text('No hay días configurados'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showTemplates(context, ref),
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text('Sugerir plantillas'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentOf(context),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _gridView
                    ? _buildGrid(days, primary)
                    : _buildList(days, primary),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<RoutineDay> days, Color primary) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final day = days[i];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            subtitle: Text(_daySubtitle(day)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _editDay(day),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<RoutineDay> days, Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final full = constraints.maxWidth;
          final half = (full - gap) / 2;
          final lastSpans = days.length.isOdd;
          return SingleChildScrollView(
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < days.length; i++)
                  SizedBox(
                    width: lastSpans && i == days.length - 1 ? full : half,
                    height: 132,
                    child: _DayBlock(
                      day: days[i],
                      primary: primary,
                      onTap: () => _editDay(days[i]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _daySubtitle(RoutineDay day) {
    if (day.isRestDay) return 'Descanso';
    return '${day.title} · ${day.exercises.length} ejercicios'
        '${day.duration.isNotEmpty ? ' · ${day.duration}' : ''}';
  }

  Future<void> _showTemplates(BuildContext context, WidgetRef ref) async {
    // Garantiza que el catálogo esté cargado para resolver nombres/grupos
    // de los ejercicios de las plantillas.
    await ref.read(exerciseRepositoryProvider).loadCatalog();
    if (!context.mounted) return;
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
                    color: accentOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reemplaza tu semana actual. Luego puedes editar cada día.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: const Text(
                      'Crear con el asistente',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Genera una rutina según tu objetivo, nivel y días',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RoutineGeneratorScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
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

/// Bloque compacto de un día de la semana, para la vista en cuadrícula.
class _DayBlock extends StatelessWidget {
  final RoutineDay day;
  final Color primary;
  final VoidCallback onTap;

  const _DayBlock({
    required this.day,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = day.day == WorkoutSession.weekdayName();
    final rest = day.isRestDay;
    final accent = rest ? Colors.blueGrey : primary;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isToday
            ? BorderSide(color: accentOf(context), width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    child: Text(
                      day.day.substring(0, 2),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      day.day,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'HOY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: accentOf(context),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  rest ? 'Descanso' : day.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: rest ? Colors.blueGrey : null,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                rest
                    ? 'Día de recuperación'
                    : '${day.exercises.length} ejercicios'
                        '${day.duration.isEmpty ? '' : ' · ${day.duration}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
