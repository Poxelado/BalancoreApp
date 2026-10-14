import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balancore/core/offline/local_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('guarda y recupera valores JSON', () async {
    final cache = LocalCache();
    await cache.save('k', {
      'a': 1,
      'b': [true, null, 'x'],
    });
    expect(await cache.read('k'), {
      'a': 1,
      'b': [true, null, 'x'],
    });
  });

  test('read devuelve null si la clave no existe', () async {
    final cache = LocalCache();
    expect(await cache.read('nope'), isNull);
  });

  test('persiste entre instancias (comparte prefs)', () async {
    await LocalCache().save('k', [1, 2, 3]);
    expect(await LocalCache().read('k'), [1, 2, 3]);
  });
}
