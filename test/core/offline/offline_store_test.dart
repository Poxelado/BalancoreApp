import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balancore/core/offline/offline_op.dart';
import 'package:balancore/core/offline/offline_store.dart';

OfflineOp _op(String key) => OfflineOp(
      type: OfflineOpType.mealUpsert,
      uid: 'u1',
      dedupeKey: key,
      payload: {'k': key},
      createdAt: 'now',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('put reemplaza por dedupeKey y remove borra', () async {
    final store = OfflineStore();
    await store.put(_op('meal:d:m1'));
    await store.put(_op('meal:d:m2'));
    expect(store.length, 2);

    await store.put(_op('meal:d:m1'));
    expect(store.length, 2, reason: 'misma dedupeKey se reemplaza');

    await store.remove('meal:d:m1');
    expect(store.length, 1);
    expect(store.ops.first.dedupeKey, 'meal:d:m2');
  });

  test('la cola sobrevive al reinicio (persistencia)', () async {
    final store = OfflineStore();
    await store.put(const OfflineOp(
      type: OfflineOpType.workoutSession,
      uid: 'u1',
      dedupeKey: 'ws:s1',
      payload: {'id': 's1'},
      createdAt: 'now',
    ));

    final reloaded = OfflineStore();
    await reloaded.load();
    expect(reloaded.length, 1);
    expect(reloaded.ops.first.type, OfflineOpType.workoutSession);
    expect(reloaded.ops.first.payload['id'], 's1');
  });

  test('clear vacía la cola', () async {
    final store = OfflineStore();
    await store.put(_op('a'));
    await store.put(_op('b'));
    await store.clear();
    expect(store.length, 0);
  });
}
