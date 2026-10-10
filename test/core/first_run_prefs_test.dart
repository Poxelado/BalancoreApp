import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:balancore/core/first_run/first_run_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('el tutorial no está hecho al inicio', () async {
    expect(await FirstRunPrefs.isTutorialDone(), isFalse);
  });

  test('markTutorialDone lo marca como completado', () async {
    await FirstRunPrefs.markTutorialDone();
    expect(await FirstRunPrefs.isTutorialDone(), isTrue);
  });

  test('resetTutorial vuelve a desactivarlo', () async {
    await FirstRunPrefs.markTutorialDone();
    await FirstRunPrefs.resetTutorial();
    expect(await FirstRunPrefs.isTutorialDone(), isFalse);
  });
}
