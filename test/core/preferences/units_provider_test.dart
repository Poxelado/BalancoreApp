import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:balancore/core/preferences/units_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnitSystemX conversion', () {
    test('métrico es identidad', () {
      expect(UnitSystem.metric.weightToDisplay(80), 80);
      expect(UnitSystem.metric.weightToKg(80), 80);
      expect(UnitSystem.metric.heightToDisplay(180), 180);
      expect(UnitSystem.metric.heightToCm(180), 180);
    });

    test('kg → lb y de vuelta', () {
      const kg = 80.0;
      final lb = UnitSystem.imperial.weightToDisplay(kg);
      expect(lb, closeTo(176.37, 0.01));
      expect(UnitSystem.imperial.weightToKg(lb), closeTo(kg, 1e-9));
    });

    test('cm → in y de vuelta', () {
      const cm = 180.0;
      final inch = UnitSystem.imperial.heightToDisplay(cm);
      expect(inch, closeTo(70.87, 0.01));
      expect(UnitSystem.imperial.heightToCm(inch), closeTo(cm, 1e-9));
    });

    test('formatWeight y formatHeight usan la etiqueta correcta', () {
      expect(UnitSystem.metric.formatWeight(72.5), '72.5 kg');
      expect(UnitSystem.imperial.formatWeight(72.5), '159.8 lb');
      expect(UnitSystem.metric.formatHeight(178), '178 cm');
      expect(UnitSystem.imperial.formatHeight(178), '70 in');
      expect(UnitSystem.metric.shortLabel, 'kg · cm');
      expect(UnitSystem.imperial.shortLabel, 'lb · in');
    });
  });

  group('UnitsNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('arranca en métrico', () {
      final notifier = UnitsNotifier();
      expect(notifier.state, UnitSystem.metric);
    });

    test('set persiste y se relee', () async {
      final notifier = UnitsNotifier();
      await notifier.set(UnitSystem.imperial);
      expect(notifier.state, UnitSystem.imperial);

      final reloaded = UnitsNotifier();
      await Future<void>.delayed(Duration.zero);
      expect(reloaded.state, UnitSystem.imperial);
    });
  });
}
