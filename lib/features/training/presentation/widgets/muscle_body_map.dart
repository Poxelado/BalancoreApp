import 'package:flutter/material.dart';

import '../../domain/workout_share_metrics.dart';

/// Personaje (frente y espalda) con los músculos trabajados resaltados según
/// [intensity] (0..1). Dibujado a mano para no depender de assets.
class MuscleBodyMap extends StatelessWidget {
  final Map<BodyRegion, double> intensity;
  final Color base;
  final Color trained;

  const MuscleBodyMap({
    super.key,
    required this.intensity,
    required this.base,
    required this.trained,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BodyMapPainter(
          intensity: intensity,
          base: base,
          trained: trained,
        ),
        child: const SizedBox.expand(),
      );
}

typedef _Patch = (BodyRegion region, double x, double y, double w, double h);

// Parches musculares por figura (coordenadas normalizadas 0..1).
const _frontMuscles = <_Patch>[
  (BodyRegion.shoulders, 0.215, 0.175, 0.145, 0.105),
  (BodyRegion.shoulders, 0.640, 0.175, 0.145, 0.105),
  (BodyRegion.chest, 0.345, 0.205, 0.150, 0.135),
  (BodyRegion.chest, 0.505, 0.205, 0.150, 0.135),
  (BodyRegion.biceps, 0.215, 0.285, 0.120, 0.155),
  (BodyRegion.biceps, 0.665, 0.285, 0.120, 0.155),
  (BodyRegion.forearms, 0.185, 0.460, 0.110, 0.165),
  (BodyRegion.forearms, 0.705, 0.460, 0.110, 0.165),
  (BodyRegion.quadriceps, 0.325, 0.545, 0.155, 0.250),
  (BodyRegion.quadriceps, 0.520, 0.545, 0.155, 0.250),
  (BodyRegion.calves, 0.355, 0.805, 0.115, 0.150),
  (BodyRegion.calves, 0.530, 0.805, 0.115, 0.150),
  // Abdomen: 3 filas × 2 columnas.
  (BodyRegion.abs, 0.405, 0.350, 0.085, 0.060),
  (BodyRegion.abs, 0.510, 0.350, 0.085, 0.060),
  (BodyRegion.abs, 0.405, 0.415, 0.085, 0.060),
  (BodyRegion.abs, 0.510, 0.415, 0.085, 0.060),
  (BodyRegion.abs, 0.405, 0.480, 0.085, 0.060),
  (BodyRegion.abs, 0.510, 0.480, 0.085, 0.060),
];

const _backMuscles = <_Patch>[
  (BodyRegion.traps, 0.400, 0.175, 0.200, 0.115),
  (BodyRegion.lats, 0.325, 0.275, 0.160, 0.235),
  (BodyRegion.lats, 0.515, 0.275, 0.160, 0.235),
  (BodyRegion.lowerBack, 0.425, 0.500, 0.150, 0.075),
  (BodyRegion.triceps, 0.215, 0.285, 0.120, 0.155),
  (BodyRegion.triceps, 0.665, 0.285, 0.120, 0.155),
  (BodyRegion.forearms, 0.185, 0.460, 0.110, 0.165),
  (BodyRegion.forearms, 0.705, 0.460, 0.110, 0.165),
  (BodyRegion.glutes, 0.350, 0.555, 0.140, 0.115),
  (BodyRegion.glutes, 0.510, 0.555, 0.140, 0.115),
  (BodyRegion.hamstrings, 0.325, 0.675, 0.155, 0.145),
  (BodyRegion.hamstrings, 0.520, 0.675, 0.155, 0.145),
  (BodyRegion.calves, 0.355, 0.805, 0.115, 0.150),
  (BodyRegion.calves, 0.530, 0.805, 0.115, 0.150),
];

/// Silueta base: cabeza, torso, brazos y piernas. Se dibuja con el mismo
/// relleno en las dos figuras.
const _baseShapes = <_Patch>[
  (BodyRegion.abs, 0.460, 0.145, 0.080, 0.050),
  (BodyRegion.abs, 0.325, 0.180, 0.350, 0.400),
  (BodyRegion.biceps, 0.205, 0.200, 0.130, 0.300),
  (BodyRegion.biceps, 0.665, 0.200, 0.130, 0.300),
  (BodyRegion.forearms, 0.175, 0.470, 0.110, 0.200),
  (BodyRegion.forearms, 0.715, 0.470, 0.110, 0.200),
  (BodyRegion.quadriceps, 0.300, 0.530, 0.190, 0.280),
  (BodyRegion.quadriceps, 0.510, 0.530, 0.190, 0.280),
  (BodyRegion.calves, 0.330, 0.790, 0.145, 0.190),
  (BodyRegion.calves, 0.525, 0.790, 0.145, 0.190),
];

class _BodyMapPainter extends CustomPainter {
  final Map<BodyRegion, double> intensity;
  final Color base;
  final Color trained;

  _BodyMapPainter({
    required this.intensity,
    required this.base,
    required this.trained,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gap = size.width * 0.06;
    final figW = (size.width - gap) / 2;
    _figure(canvas, Rect.fromLTWH(0, 0, figW, size.height), _frontMuscles);
    _figure(
      canvas,
      Rect.fromLTWH(figW + gap, 0, figW, size.height),
      _backMuscles,
    );
  }

  void _figure(Canvas canvas, Rect box, List<_Patch> muscles) {
    final silhouette = Paint()..color = base;
    final patch = Paint();

    void drawShape(_Patch p, Paint paint, double radius) {
      final r = Rect.fromLTWH(
        box.left + p.$2 * box.width,
        box.top + p.$3 * box.height,
        p.$4 * box.width,
        p.$5 * box.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(radius * box.width)),
        paint,
      );
    }

    // Silueta base.
    for (final s in _baseShapes) {
      drawShape(s, silhouette, 0.06);
    }
    // Cabeza.
    canvas.drawOval(
      Rect.fromLTWH(
        box.left + 0.42 * box.width,
        box.top + 0.02 * box.height,
        0.16 * box.width,
        0.145 * box.height,
      ),
      silhouette,
    );

    // Músculos.
    for (final m in muscles) {
      final t = (intensity[m.$1] ?? 0).clamp(0.0, 1.0);
      patch.color = t <= 0
          ? Color.lerp(base, trained, 0.08)!
          : Color.lerp(base, trained, 0.35 + 0.65 * t)!;
      drawShape(m, patch, 0.045);
    }
  }

  @override
  bool shouldRepaint(_BodyMapPainter old) =>
      old.intensity != intensity || old.base != base || old.trained != trained;
}
