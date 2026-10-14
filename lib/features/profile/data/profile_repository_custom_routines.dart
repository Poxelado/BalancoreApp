part of 'profile_repository.dart';

extension ProfileCustomRoutines on ProfileRepository {
  // ─── Rutinas extras (además de la rutina semanal) ───────
  // Doc id = routine.id, guardado en users/{uid}/customRoutines/{id}.

  CollectionReference _customRoutines(String uid) =>
      _userDoc(uid).doc(uid).collection('customRoutines');

  Future<List<CustomRoutine>> getCustomRoutines(String uid) => _cachedList(
        'customRoutines:$uid',
        fetch: () => _fetchCustomRoutines(uid),
        encode: (r) => r.toMap(),
        decode: CustomRoutine.fromMap,
      );

  Future<List<CustomRoutine>> _fetchCustomRoutines(String uid) async {
    final snap = await _customRoutines(uid).get();
    final list = <CustomRoutine>[];
    for (final d in snap.docs) {
      final raw = d.data();
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      if ((map['id']?.toString() ?? '').isEmpty) map['id'] = d.id;
      list.add(CustomRoutine.fromMap(map));
    }
    list.sort((a, b) {
      final da = a.createdAt;
      final db = b.createdAt;
      if (da != null && db != null) return db.compareTo(da);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<void> saveCustomRoutine(String uid, CustomRoutine routine) async {
    final id = routine.id.isEmpty ? CustomRoutine.newId() : routine.id;
    await _customRoutines(uid).doc(id).set({
      ...routine.toMap(),
      'id': id,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteCustomRoutine(String uid, String id) async {
    if (id.isEmpty) return;
    await _customRoutines(uid).doc(id).delete();
  }
}
