import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/core/steps/step_counter.dart';

void main() {
  group('stepCalories', () {
    test('10.000 pasos a 70 kg ≈ 400 kcal', () {
      expect(stepCalories(10000, 70), 400);
    });

    test('escala con el peso', () {
      expect(stepCalories(10000, 35), 200);
      expect(stepCalories(10000, 140), 800);
    });

    test('sin pasos o sin peso devuelve 0', () {
      expect(stepCalories(0, 70), 0);
      expect(stepCalories(10000, 0), 0);
      expect(stepCalories(-5, 70), 0);
    });
  });
}
