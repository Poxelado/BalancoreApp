import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/features/training/presentation/widgets/session_plates_sheet.dart';

void main() {
  group('computePlates', () {
    test('barra sola: sin discos', () {
      final bd = computePlates(20, bar: 20);
      expect(bd.perSide, isEmpty);
      expect(bd.achieved, 20);
      expect(bd.exact, isTrue);
    });

    test('100 kg con barra de 20 → 25 + 15 por lado', () {
      final bd = computePlates(100, bar: 20);
      expect(bd.perSide, [25, 15]);
      expect(bd.achieved, 100);
      expect(bd.exact, isTrue);
    });

    test('combina discos pequeños exactos', () {
      final bd = computePlates(102.5, bar: 20);
      expect(bd.perSide, [25, 15, 1.25]);
      expect(bd.achieved, 102.5);
      expect(bd.exact, isTrue);
    });

    test('marca el sobrante no alcanzable', () {
      final bd = computePlates(61.25, bar: 20);
      expect(bd.achieved, 60);
      expect(bd.exact, isFalse);
      expect(bd.remainder, closeTo(1.25, 0.001));
    });

    test('peso por debajo de la barra', () {
      final bd = computePlates(15, bar: 20);
      expect(bd.perSide, isEmpty);
      expect(bd.achieved, 20);
    });

    test('peso 0 o negativo no calcula discos', () {
      final bd = computePlates(0);
      expect(bd.isEmpty, isTrue);
      expect(bd.achieved, 0);
    });
  });
}
