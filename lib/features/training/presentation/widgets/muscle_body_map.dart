import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/workout_share_metrics.dart';

/// Figura humana (de frente o de espalda) con los músculos trabajados
/// resaltados según [intensity] (0..1). Dibujada a mano para no depender de
/// assets. La silueta conserva proporciones reales (se escala de forma
/// uniforme) y cada músculo se separa con un contorno para que se distingan
/// bien los grupos musculares.
class MuscleBodyMap extends StatelessWidget {
  final Map<BodyRegion, double> intensity;
  final Color base;
  final Color trained;
  final Color outline;
  final bool front;

  const MuscleBodyMap({
    super.key,
    required this.intensity,
    required this.base,
    required this.trained,
    required this.outline,
    this.front = true,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BodyMapPainter(
          intensity: intensity,
          base: base,
          trained: trained,
          outline: outline,
          front: front,
        ),
        child: const SizedBox.expand(),
      );
}

/// `(región, forma)` en coordenadas de diseño (ver [_designW] y [_designH]).
typedef _Shape = (BodyRegion region, Path path);

const double _designW = 100;
const double _designH = 210;

// -----------------------------------------------------------------------------
// Silueta base
// -----------------------------------------------------------------------------

List<Path> _silhouetteShapes() => [
      _oval(50, 18, 11, 13.5), // cabeza
      _poly([(44, 28), (56, 28), (57.5, 41), (42.5, 41)]), // cuello
      _poly([(30, 40), (70, 40), (71, 58), (66, 78), (63, 96), (37, 96),
          (34, 78), (29, 58)]), // torso
      _poly([(37, 94), (63, 94), (62, 114), (38, 114)]), // pelvis
      _oval(24.5, 46, 9.5, 9.5), // deltoides izq.
      _oval(75.5, 46, 9.5, 9.5), // deltoides der.
      _poly([(19, 50), (31.5, 53), (30, 85), (21, 86)]), // brazo izq.
      _poly([(81, 50), (68.5, 53), (70, 85), (79, 86)]), // brazo der.
      _poly([(21, 85), (30, 84), (29, 117), (22, 119)]), // antebrazo izq.
      _poly([(79, 85), (70, 84), (71, 117), (78, 119)]), // antebrazo der.
      _poly([(37, 95), (49, 96), (48, 157), (38, 158)]), // muslo izq.
      _poly([(63, 95), (51, 96), (52, 157), (62, 158)]), // muslo der.
      _poly([(39, 158), (48, 158), (47, 196), (40, 197)]), // pantorrilla izq.
      _poly([(61, 158), (52, 158), (53, 196), (60, 197)]), // pantorrilla der.
    ];

// -----------------------------------------------------------------------------
// Músculos de frente
// -----------------------------------------------------------------------------

List<_Shape> _frontMuscles() => [
      (BodyRegion.shoulders, _oval(24.5, 45, 8.5, 8)),
      (BodyRegion.shoulders, _oval(75.5, 45, 8.5, 8)),
      (BodyRegion.chest, _poly([(33.5, 41.5), (48.5, 42.5), (49, 56),
          (46, 64), (35.5, 63), (32.5, 52)])),
      (BodyRegion.chest, _poly([(66.5, 41.5), (51.5, 42.5), (51, 56),
          (54, 64), (64.5, 63), (67.5, 52)])),
      // Abdomen: 3 filas × 2 columnas.
      (BodyRegion.abs, _rect(41.5, 66, 6.5, 7.5)),
      (BodyRegion.abs, _rect(52, 66, 6.5, 7.5)),
      (BodyRegion.abs, _rect(41.5, 75, 6.5, 7.5)),
      (BodyRegion.abs, _rect(52, 75, 6.5, 7.5)),
      (BodyRegion.abs, _rect(41.5, 84, 6.5, 7.5)),
      (BodyRegion.abs, _rect(52, 84, 6.5, 7.5)),
      (BodyRegion.abs, _poly([(35, 66), (41, 68), (41, 90), (36.5, 92)])),
      (BodyRegion.abs, _poly([(65, 66), (59, 68), (59, 90), (63.5, 92)])),
      (BodyRegion.biceps, _poly([(19, 52), (31, 54), (31, 80), (22, 83)])),
      (BodyRegion.biceps, _poly([(81, 52), (69, 54), (69, 80), (78, 83)])),
      (BodyRegion.forearms, _poly([(21, 86), (30, 85), (29, 114), (22, 117)])),
      (BodyRegion.forearms, _poly([(79, 86), (70, 85), (71, 114), (78, 117)])),
      // Cuádriceps: dos cabezas por muslo.
      (BodyRegion.quadriceps, _poly([(37, 115), (43, 115), (43, 152), (38, 154)])),
      (BodyRegion.quadriceps, _poly([(44, 115), (48.5, 115), (48.5, 152), (44, 154)])),
      (BodyRegion.quadriceps, _poly([(63, 115), (57, 115), (57, 152), (62, 154)])),
      (BodyRegion.quadriceps, _poly([(56, 115), (51.5, 115), (51.5, 152), (56, 154)])),
      (BodyRegion.calves, _poly([(43, 161), (47, 176), (43, 193), (39, 176)])),
      (BodyRegion.calves, _poly([(57, 161), (61, 176), (57, 193), (53, 176)])),
    ];

// -----------------------------------------------------------------------------
// Músculos de espalda
// -----------------------------------------------------------------------------

List<_Shape> _backMuscles() => [
      (BodyRegion.traps, _poly([(38, 40), (50, 35), (62, 40), (58, 52),
          (50, 58), (42, 52)])),
      (BodyRegion.lats, _poly([(30, 46), (44, 50), (46, 64), (42, 86),
          (34, 88), (31, 68)])),
      (BodyRegion.lats, _poly([(70, 46), (56, 50), (54, 64), (58, 86),
          (66, 88), (69, 68)])),
      (BodyRegion.lowerBack, _poly([(40, 84), (60, 84), (58, 96), (42, 96)])),
      (BodyRegion.triceps, _poly([(19, 52), (31, 54), (31, 80), (22, 83)])),
      (BodyRegion.triceps, _poly([(81, 52), (69, 54), (69, 80), (78, 83)])),
      (BodyRegion.forearms, _poly([(21, 86), (30, 85), (29, 114), (22, 117)])),
      (BodyRegion.forearms, _poly([(79, 86), (70, 85), (71, 114), (78, 117)])),
      (BodyRegion.glutes, _poly([(36, 96), (49, 96), (49, 112), (36, 113)])),
      (BodyRegion.glutes, _poly([(64, 96), (51, 96), (51, 112), (64, 113)])),
      (BodyRegion.hamstrings, _poly([(37, 116), (48, 117), (47, 142), (38, 143)])),
      (BodyRegion.hamstrings, _poly([(63, 116), (52, 117), (53, 142), (62, 143)])),
      (BodyRegion.calves, _poly([(43, 161), (47, 176), (43, 193), (39, 176)])),
      (BodyRegion.calves, _poly([(57, 161), (61, 176), (57, 193), (53, 176)])),
    ];

Path _poly(List<(double, double)> points) =>
    Path()..addPolygon([for (final (x, y) in points) Offset(x, y)], true);

Path _rect(double x, double y, double w, double h) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      const Radius.circular(1.2),
    ),
  );

Path _oval(double cx, double cy, double rx, double ry) => Path()
  ..addOval(Rect.fromCenter(
    center: Offset(cx, cy),
    width: rx * 2,
    height: ry * 2,
  ));

class _BodyMapPainter extends CustomPainter {
  final Map<BodyRegion, double> intensity;
  final Color base;
  final Color trained;
  final Color outline;
  final bool front;

  _BodyMapPainter({
    required this.intensity,
    required this.base,
    required this.trained,
    required this.outline,
    required this.front,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / _designW, size.height / _designH);
    canvas.save();
    canvas.translate(
      (size.width - _designW * scale) / 2,
      (size.height - _designH * scale) / 2,
    );
    canvas.scale(scale);
    _figure(canvas);
    canvas.restore();
  }

  void _figure(Canvas canvas) {
    final shapes = _silhouetteShapes();
    var body = shapes.first;
    for (var i = 1; i < shapes.length; i++) {
      body = Path.combine(PathOperation.union, body, shapes[i]);
    }
    canvas.drawPath(body, Paint()..color = base);

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round
      ..color = outline;
    canvas.drawPath(body, edge);

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeJoin = StrokeJoin.round
      ..color = outline;

    for (final (region, path) in front ? _frontMuscles() : _backMuscles()) {
      final t = (intensity[region] ?? 0).clamp(0.0, 1.0);
      fill.color = t <= 0
          ? Color.lerp(base, trained, 0.14)!
          : Color.lerp(base, trained, 0.5 + 0.5 * t)!;
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_BodyMapPainter old) =>
      old.intensity != intensity ||
      old.base != base ||
      old.trained != trained ||
      old.outline != outline ||
      old.front != front;
}
