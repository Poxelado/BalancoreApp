import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/workout_share_metrics.dart';

/// Figura humana (de frente o de espalda) con los músculos trabajados
/// resaltados según [intensity] (0..1). Dibujada a mano para no depender de
/// assets. La silueta conserva proporciones reales (se escala de forma
/// uniforme), por lo que nunca se ve alargada ni achatada.
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

/// `(región, x, y, ancho, alto, radio)` en coordenadas de diseño (ver
/// [_designW] y [_designH]).
typedef _Patch = (BodyRegion region, double x, double y, double w, double h, double r);

const double _designW = 100;
const double _designH = 210;

const _frontMuscles = <_Patch>[
  (BodyRegion.shoulders, 16.5, 39.5, 19, 18, 9),
  (BodyRegion.shoulders, 64.5, 39.5, 19, 18, 9),
  (BodyRegion.chest, 32.5, 41, 17.5, 26, 7),
  (BodyRegion.chest, 50, 41, 17.5, 26, 7),
  (BodyRegion.abs, 41, 70, 8, 8, 2.5),
  (BodyRegion.abs, 51, 70, 8, 8, 2.5),
  (BodyRegion.abs, 41, 80, 8, 8, 2.5),
  (BodyRegion.abs, 51, 80, 8, 8, 2.5),
  (BodyRegion.abs, 41, 90, 8, 8, 2.5),
  (BodyRegion.abs, 51, 90, 8, 8, 2.5),
  (BodyRegion.abs, 33, 70, 7, 24, 3.5),
  (BodyRegion.abs, 60, 70, 7, 24, 3.5),
  (BodyRegion.biceps, 18, 55, 13, 31, 6),
  (BodyRegion.biceps, 69, 55, 13, 31, 6),
  (BodyRegion.forearms, 17, 88, 12, 30, 6),
  (BodyRegion.forearms, 71, 88, 12, 30, 6),
  (BodyRegion.quadriceps, 34, 114, 16, 44, 8),
  (BodyRegion.quadriceps, 50, 114, 16, 44, 8),
  (BodyRegion.calves, 35, 162, 13, 36, 6),
  (BodyRegion.calves, 52, 162, 13, 36, 6),
];

const _backMuscles = <_Patch>[
  (BodyRegion.traps, 38, 37, 24, 16, 7),
  (BodyRegion.lats, 30, 48, 19, 40, 9),
  (BodyRegion.lats, 51, 48, 19, 40, 9),
  (BodyRegion.lowerBack, 40, 86, 20, 14, 6),
  (BodyRegion.triceps, 18, 55, 13, 31, 6),
  (BodyRegion.triceps, 69, 55, 13, 31, 6),
  (BodyRegion.forearms, 17, 88, 12, 30, 6),
  (BodyRegion.forearms, 71, 88, 12, 30, 6),
  (BodyRegion.glutes, 33.5, 97, 16, 19, 9),
  (BodyRegion.glutes, 50.5, 97, 16, 19, 9),
  (BodyRegion.hamstrings, 34, 118, 16, 28, 8),
  (BodyRegion.hamstrings, 50, 118, 16, 28, 8),
  (BodyRegion.calves, 35, 162, 13, 36, 6),
  (BodyRegion.calves, 52, 162, 13, 36, 6),
];

/// Silueta base: torso, pelvis, cuello, brazos y piernas.
const _baseShapes = <_Patch>[
  (BodyRegion.abs, 43, 28, 14, 12, 4),
  (BodyRegion.abs, 29, 36, 42, 60, 15),
  (BodyRegion.abs, 32, 92, 36, 22, 9),
  (BodyRegion.shoulders, 17, 39, 19, 19, 9),
  (BodyRegion.shoulders, 64, 39, 19, 19, 9),
  (BodyRegion.biceps, 18, 52, 14, 36, 7),
  (BodyRegion.biceps, 68, 52, 14, 36, 7),
  (BodyRegion.forearms, 17, 86, 12, 34, 6),
  (BodyRegion.forearms, 71, 86, 12, 34, 6),
  (BodyRegion.quadriceps, 34, 112, 15, 48, 7),
  (BodyRegion.quadriceps, 51, 112, 15, 48, 7),
  (BodyRegion.calves, 35, 160, 13, 40, 6),
  (BodyRegion.calves, 52, 160, 13, 40, 6),
];

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
    final drawW = _designW * scale;
    final drawH = _designH * scale;
    final box = Rect.fromLTWH(
      (size.width - drawW) / 2,
      (size.height - drawH) / 2,
      drawW,
      drawH,
    );
    _figure(canvas, box, front ? _frontMuscles : _backMuscles);
  }

  void _figure(Canvas canvas, Rect box, List<_Patch> muscles) {
    final silhouette = Paint()..color = base;
    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, box.width * 0.014)
      ..color = outline;

    Rect rect(_Patch p) => Rect.fromLTWH(
          box.left + p.$2 / _designW * box.width,
          box.top + p.$3 / _designH * box.height,
          p.$4 / _designW * box.width,
          p.$5 / _designH * box.height,
        );
    double radius(_Patch p) => p.$6 / _designW * box.width;

    void shape(_Patch p, Paint paint) => canvas.drawRRect(
          RRect.fromRectAndRadius(rect(p), Radius.circular(radius(p))),
          paint,
        );

    // Cabeza.
    canvas.drawOval(
      Rect.fromLTWH(
        box.left + 38.5 / _designW * box.width,
        box.top + 3 / _designH * box.height,
        23 / _designW * box.width,
        28 / _designH * box.height,
      ),
      silhouette,
    );

    // Silueta base.
    for (final s in _baseShapes) {
      shape(s, silhouette);
    }

    // Músculos (siempre visibles; se resaltan según intensidad).
    for (final m in muscles) {
      final t = (intensity[m.$1] ?? 0).clamp(0.0, 1.0);
      fill.color = t <= 0
          ? Color.lerp(base, trained, 0.12)!
          : Color.lerp(base, trained, 0.45 + 0.55 * t)!;
      final r = RRect.fromRectAndRadius(rect(m), Radius.circular(radius(m)));
      canvas.drawRRect(r, fill);
      canvas.drawRRect(r, stroke);
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
