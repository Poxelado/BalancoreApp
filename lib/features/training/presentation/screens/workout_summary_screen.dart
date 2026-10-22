import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/personal_records.dart';
import '../../domain/session_stats.dart';
import '../../domain/workout_share_metrics.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../widgets/muscle_body_map.dart';
import '../../../../core/preferences/units_provider.dart';
import '../../../../core/theme/app_theme.dart';

/// Estilo (marco/fondo) de una tarjeta para compartir.
class ShareCardStyle {
  final String name;
  final List<Color> colors;
  final Color on;
  final Color muted;
  final Color accent;
  final Color chip;

  const ShareCardStyle({
    required this.name,
    required this.colors,
    required this.on,
    required this.muted,
    required this.accent,
    required this.chip,
  });
}

const shareCardStyles = <ShareCardStyle>[
  ShareCardStyle(
    name: 'Aurora',
    colors: [Color(0xFF1F1147), Color(0xFF4527A0), Color(0xFF7C4DFF)],
    on: Colors.white,
    muted: Color(0xB3FFFFFF),
    accent: Color(0xFFB388FF),
    chip: Color(0x1FFFFFFF),
  ),
  ShareCardStyle(
    name: 'Fuego',
    colors: [Color(0xFF3E1103), Color(0xFFB71C1C), Color(0xFFFF6D00)],
    on: Colors.white,
    muted: Color(0xB3FFFFFF),
    accent: Color(0xFFFFD54F),
    chip: Color(0x1FFFFFFF),
  ),
  ShareCardStyle(
    name: 'Océano',
    colors: [Color(0xFF041C3B), Color(0xFF0D47A1), Color(0xFF00BCD4)],
    on: Colors.white,
    muted: Color(0xB3FFFFFF),
    accent: Color(0xFF4DD0E1),
    chip: Color(0x1FFFFFFF),
  ),
  ShareCardStyle(
    name: 'Menta',
    colors: [Color(0xFF06251C), Color(0xFF00695C), Color(0xFF26A69A)],
    on: Colors.white,
    muted: Color(0xB3FFFFFF),
    accent: Color(0xFF80CBC4),
    chip: Color(0x1FFFFFFF),
  ),
  ShareCardStyle(
    name: 'Atardecer',
    colors: [Color(0xFF3A0B2E), Color(0xFFAD1457), Color(0xFFFF8A65)],
    on: Colors.white,
    muted: Color(0xB3FFFFFF),
    accent: Color(0xFFFFAB91),
    chip: Color(0x1FFFFFFF),
  ),
  ShareCardStyle(
    name: 'Noche',
    colors: [Color(0xFF0B0B0F), Color(0xFF1C1C24), Color(0xFF2A2A38)],
    on: Colors.white,
    muted: Color(0xB3FFFFFF),
    accent: Color(0xFF90CAF9),
    chip: Color(0x1FFFFFFF),
  ),
  ShareCardStyle(
    name: 'Claro',
    colors: [Color(0xFFF6F7FB), Color(0xFFE7EAF4), Color(0xFFD5DAEC)],
    on: Color(0xFF14161C),
    muted: Color(0x99000000),
    accent: Color(0xFF5C6BC0),
    chip: Color(0x0F000000),
  ),
];

/// Resumen de una sesión recién terminada, en formato carrusel tipo Hevy: seis
/// tarjetas para compartir (mapa de músculos, radar, métricas, dato divertido)
/// con opciones de estilo, compartir y guardar.
class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  final SessionStats stats;
  final List<PersonalRecord> records;
  final String title;
  final int calories;
  final WorkoutSession? session;

  const WorkoutSummaryScreen({
    super.key,
    required this.stats,
    this.records = const [],
    this.title = 'Entrenamiento completado',
    this.calories = 0,
    this.session,
  });

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  static const _cardCount = 6;

  final _pageController = PageController();
  final _cardKeys = List.generate(_cardCount, (_) => GlobalKey());
  int _page = 0;
  int _styleIndex = 0;
  bool _busy = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Vuelve al hub dejando seleccionada la pestaña Rutina, sin importar desde
  /// dónde se arrancó la sesión (Rutina, Progreso o el mini reproductor).
  void _close() {
    ref.read(shellTabProvider.notifier).state = 3;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  WorkoutShareData get _data =>
      buildWorkoutShareData(widget.session ?? _emptySession());

  WorkoutSession _emptySession() => WorkoutSession(
        id: 'empty',
        dayName: '',
        title: '',
        startedAt: DateTime.now(),
        exercises: const [],
      );

  ShareCardStyle get _style => shareCardStyles[_styleIndex];

  String get _username {
    final profile = ref.watch(userProfileProvider).value;
    final name = profile?.username?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'atleta';
  }

  Future<void> _captureAndShare() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    setState(() => _busy = true);
    try {
      final bytes = await _captureCurrent();
      if (bytes == null) {
        _snack('No se pudo generar la imagen');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/balancore_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes, flush: true);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'mira mi entrenamiento en balancore',
          subject: 'Mi entrenamiento en Balancore',
          sharePositionOrigin: origin,
        ),
      );
      if (result.status == ShareResultStatus.unavailable) {
        _snack('No hay aplicaciones para compartir en este dispositivo');
      }
    } catch (e, st) {
      debugPrint('Error al compartir el resumen: $e\n$st');
      _snack('No se pudo compartir: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureAndSave() async {
    setState(() => _busy = true);
    try {
      final bytes = await _captureCurrent();
      if (bytes == null) return;
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(
        bytes,
        name: 'balancore_${DateTime.now().millisecondsSinceEpoch}',
      );
      _snack('Imagen guardada en tu galería');
    } catch (e) {
      _snack('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List?> _captureCurrent() async {
    final ctx = _cardKeys[_page].currentContext;
    final boundary = ctx?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openStyles() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Marco y color',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < shareCardStyles.length; i++)
                    GestureDetector(
                      onTap: () {
                        setState(() => _styleIndex = i);
                        setSheet(() {});
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: shareCardStyles[i].colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: i == _styleIndex
                                    ? accentOf(context)
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(shareCardStyles[i].name,
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final style = _style;
    final units = ref.watch(unitsProvider);
    final username = _username;

    return Scaffold(
      appBar: AppBar(title: const Text('Resumen')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _card(0, _musclesCard(data, style, username)),
                  _card(1, _radarCard(data, style, username, units)),
                  _card(2, _routineCard(data, style, username, units)),
                  _card(3, _funCard(data, style, username, units)),
                  _card(4, _bigMetricsCard(data, style, username, units)),
                  _card(5, _metricsExercisesCard(data, style, username, units)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _dots(),
            const SizedBox(height: 10),
            _actions(context),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: FilledButton(
            onPressed: _close,
            child: const Text('Listo'),
          ),
        ),
      ),
    );
  }

  Widget _card(int i, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Center(
          child: RepaintBoundary(
            key: _cardKeys[i],
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: child,
            ),
          ),
        ),
      );

  Widget _dots() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _cardCount; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 20 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: i == _page
                    ? accentOf(context)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      );

  Widget _actions(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _openStyles,
              icon: const Icon(Icons.palette_outlined, size: 18),
              label: const Text('Estilo'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _captureAndShare,
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('Compartir'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _busy ? null : _captureAndSave,
              tooltip: 'Guardar en galería',
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 20),
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------------------
  // Tarjetas
  // ---------------------------------------------------------------------------

  Widget _musclesCard(WorkoutShareData data, ShareCardStyle style, String user) {
    return _frame(
      style,
      user,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Músculos trabajados', style),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in data.exerciseLines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${line.sets}×',
                                  style: TextStyle(
                                    color: style.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    shadows: _halo(style),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    line.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: style.on,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      shadows: _halo(style),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      Expanded(
                        child: _bodyFigure(style, data,
                            front: true, label: 'Frente'),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _bodyFigure(style, data,
                            front: false, label: 'Espalda'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyFigure(ShareCardStyle style, WorkoutShareData data,
      {required bool front, required String label}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
      decoration: BoxDecoration(
        color: style.chip,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Expanded(
            child: MuscleBodyMap(
              intensity: data.bodyIntensity,
              base: style.on.withValues(alpha: 0.16),
              trained: style.accent,
              outline: style.on.withValues(alpha: 0.28),
              front: front,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: style.muted, fontSize: 9.5)),
        ],
      ),
    );
  }

  Widget _radarCard(
      WorkoutShareData data, ShareCardStyle style, String user, UnitSystem units) {
    return _frame(
      style,
      user,
      Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _metric(style, Icons.timer_outlined, 'Tiempo',
                    _fmtDuration(data.durationSeconds)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(style, Icons.fitness_center, 'Volumen',
                    _fmtVolume(data.volumeKg, units)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(style, Icons.check_circle_outline, 'Series',
                    '${data.completedSets}/${data.totalSets}'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(child: _radar(data, style)),
        ],
      ),
    );
  }

  Widget _radar(WorkoutShareData data, ShareCardStyle style) {
    final values = [
      for (final g in radarGroups) (data.volumeByGroup[g] ?? 0),
    ];
    final maxV = values.fold<double>(0, (a, b) => a > b ? a : b);
    final normalized =
        maxV <= 0 ? List<double>.filled(radarGroups.length, 0) : [
      for (final v in values) (v / maxV).clamp(0.08, 1.0),
    ];

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        radarBackgroundColor: style.on.withValues(alpha: 0.05),
        borderData: FlBorderData(show: false),
        radarBorderData: BorderSide(color: style.on.withValues(alpha: 0.25)),
        gridBorderData:
            BorderSide(color: style.on.withValues(alpha: 0.18), width: 1),
        tickBorderData:
            BorderSide(color: style.on.withValues(alpha: 0.14), width: 1),
        ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),
        tickCount: 4,
        titleTextStyle: TextStyle(
          color: style.on,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          shadows: _halo(style, blur: 5, alpha: 0.6),
        ),
        titlePositionPercentageOffset: 0.12,
        getTitle: (index, angle) =>
            RadarChartTitle(text: radarGroups[index], angle: 0),
        dataSets: [
          RadarDataSet(
            fillColor: style.accent.withValues(alpha: 0.28),
            borderColor: style.accent,
            borderWidth: 2,
            entryRadius: 3,
            dataEntries: [
              for (final v in normalized) RadarEntry(value: v),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routineCard(
      WorkoutShareData data, ShareCardStyle style, String user, UnitSystem units) {
    final routine = data.session.dayName.trim().isNotEmpty
        ? data.session.dayName.trim()
        : data.session.title.trim();
    return _frame(
      style,
      user,
      Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: BoxDecoration(
            color: style.on.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: style.on.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('RUTINA',
                  style: TextStyle(
                    color: style.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    shadows: _halo(style),
                  )),
              const SizedBox(height: 8),
              Text(
                routine.isEmpty ? 'Entrenamiento libre' : routine,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: style.on,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  shadows: _halo(style),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _metric(style, Icons.timer_outlined, 'Duración',
                        _fmtDuration(data.durationSeconds)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metric(style, Icons.fitness_center, 'Volumen',
                        _fmtVolume(data.volumeKg, units)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _metric(style, Icons.list_alt, 'Ejercicios',
                        '${data.exerciseCount}'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metric(style, Icons.check_circle_outline, 'Series',
                        '${data.completedSets}/${data.totalSets}'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _funCard(WorkoutShareData data, ShareCardStyle style, String user,
      UnitSystem units) {
    final eq = equivalenceFor(data.volumeKg);
    final count = eq.count.round();
    final comparison = '${count > 1 ? '$count× ' : ''}${eq.item}';
    return _frame(
      style,
      user,
      Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Has levantado un total de',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: style.muted, fontSize: 15)),
              const SizedBox(height: 2),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: data.volumeValue),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text(
                  data.volumeKg > 0 ? _fmtVolume(v, units) : '${v.round()}',
                  style: TextStyle(
                    color: style.on,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    shadows: _halo(style),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('eso es como levantar',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: style.muted, fontSize: 15)),
              Text(
                comparison,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: style.accent,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: _halo(style),
                ),
              ),
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1.25),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: Text(eq.emoji, style: const TextStyle(fontSize: 96)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bigMetricsCard(
      WorkoutShareData data, ShareCardStyle style, String user, UnitSystem units) {
    return _frame(
      style,
      user,
      Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _bigMetric(style, Icons.timer_outlined, 'Duración',
                  _fmtDuration(data.durationSeconds)),
              const SizedBox(height: 22),
              _bigMetric(style, Icons.fitness_center, 'Volumen',
                  _fmtVolume(data.volumeKg, units)),
              const SizedBox(height: 22),
              _bigMetric(style, Icons.check_circle_outline, 'Series',
                  '${data.completedSets}/${data.totalSets}'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricsExercisesCard(
      WorkoutShareData data, ShareCardStyle style, String user, UnitSystem units) {
    return _frame(
      style,
      user,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _metric(style, Icons.timer_outlined, 'Duración',
                    _fmtDuration(data.durationSeconds)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(style, Icons.fitness_center, 'Volumen',
                    _fmtVolume(data.volumeKg, units)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metric(style, Icons.check_circle_outline, 'Series',
                    '${data.completedSets}/${data.totalSets}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text('Ejercicios',
                style: TextStyle(
                  color: style.on,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  shadows: _halo(style),
                )),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  for (final line in data.exerciseLines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              line.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: style.on,
                                fontSize: 14,
                                shadows: _halo(style),
                              ),
                            ),
                          ),
                          Text('${line.sets} series',
                              style: TextStyle(
                                color: style.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              )),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Piezas compartidas
  // ---------------------------------------------------------------------------

  Widget _frame(ShareCardStyle style, String username, Widget child) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: style.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: child),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.fitness_center, size: 16, color: style.accent),
                const SizedBox(width: 6),
                Text('Balancore',
                    style: TextStyle(
                      color: style.on,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    )),
                const Spacer(),
                Text('@$username',
                    style: TextStyle(color: style.muted, fontSize: 13)),
              ],
            ),
          ],
        ),
      );

  Widget _cardTitle(String text, ShareCardStyle style) => Text(
        text,
        style: TextStyle(
          color: style.on,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          shadows: _halo(style),
        ),
      );

  /// Sombra suave de color opuesto al texto, para que cualquier texto sea
  /// legible aunque caiga sobre una zona clara del fondo.
  List<Shadow> _halo(ShareCardStyle style, {double blur = 4, double alpha = 0.4}) {
    final halo = style.on.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return [
      Shadow(color: halo.withValues(alpha: alpha), blurRadius: blur),
      Shadow(color: halo.withValues(alpha: alpha * 0.7), blurRadius: blur * 0.5),
    ];
  }

  Widget _metric(
      ShareCardStyle style, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: style.chip,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: style.accent),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(value,
                style: TextStyle(
                  color: style.on,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  shadows: _halo(style),
                )),
          ),
          Text(label,
              style: TextStyle(
                color: style.muted,
                fontSize: 10,
                shadows: _halo(style),
              )),
        ],
      ),
    );
  }

  Widget _bigMetric(
      ShareCardStyle style, IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 30, color: style.accent),
        const SizedBox(height: 8),
        FittedBox(
          child: Text(value,
              style: TextStyle(
                color: style.on,
                fontSize: 44,
                fontWeight: FontWeight.bold,
                shadows: _halo(style),
              )),
        ),
        Text(label,
            style: TextStyle(
              color: style.muted,
              fontSize: 14,
              letterSpacing: 1,
              shadows: _halo(style),
            )),
      ],
    );
  }

  static String _fmtDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}min ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  static String _fmtVolume(double kg, UnitSystem units) {
    final v = units.weightToDisplay(kg);
    final rounded = v.round();
    final s = rounded.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (m) => '${m[1]}.',
        );
    return '$s ${units.weightUnit}';
  }
}
