part of 'profile_repository.dart';

extension ProfileRoutines on ProfileRepository {
  // ─── Rutinas ────────────────────────────────────────────
  Future<List<RoutineDay>> getRoutines(String uid) async {
    final snap = await _userDoc(uid).doc(uid).collection('routines').get();
    if (snap.docs.isEmpty) {
      // Crear rutina por defecto (Lun-Dom)
      return _defaultRoutines();
    }
    final list = snap.docs.map((d) => RoutineDay.fromMap(d.data())).toList();
    // Ordenar por día de la semana
    const order = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    list.sort((a, b) => order.indexOf(a.day).compareTo(order.indexOf(b.day)));
    return list;
  }

  Future<void> saveRoutine(String uid, RoutineDay routine) async {
    await _userDoc(uid)
        .doc(uid)
        .collection('routines')
        .doc(routine.day.toLowerCase())
        .set(routine.toMap());
  }

  Future<void> saveAllRoutines(String uid, List<RoutineDay> routines) async {
    final batch = _db.batch();
    for (final r in routines) {
      final ref = _userDoc(uid).doc(uid).collection('routines').doc(r.day.toLowerCase());
      batch.set(ref, r.toMap());
    }
    await batch.commit();
  }

  List<RoutineDay> _defaultRoutines() {
    return [
      RoutineDay(day: 'Lunes', title: 'Pecho', duration: '1h 30min', calories: 450),
      RoutineDay(day: 'Martes', title: 'Espalda', duration: '1h 10min', calories: 380),
      RoutineDay(day: 'Miércoles', title: 'Descanso', isRestDay: true),
      RoutineDay(day: 'Jueves', title: 'Pierna', duration: '1h 30min', calories: 520),
      RoutineDay(day: 'Viernes', title: 'Hombros', duration: '1h', calories: 350),
      RoutineDay(day: 'Sábado', title: 'Cardio', duration: '45min', calories: 400),
      RoutineDay(day: 'Domingo', title: 'Descanso', isRestDay: true),
    ];
  }

  CollectionReference _exerciseDefaults(String uid) =>
      _userDoc(uid).doc(uid).collection('exerciseDefaults');

  Future<Map<String, dynamic>?> getExerciseDefault(
      String uid,
      String exerciseId,
      ) async {
    final doc = await _exerciseDefaults(uid).doc(exerciseId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Map<String, dynamic>.from(doc.data() as Map);
  }

  Future<void> saveExerciseDefault({
    required String uid,
    required String exerciseId,
    required List<PlannedSet> plannedSets,
    required int restSeconds,
    String notes = '',
  }) async {
    await _exerciseDefaults(uid).doc(exerciseId).set({
      'plannedSets': plannedSets.map((s) => s.toMap()).toList(),
      'restSeconds': restSeconds,
      'notes': notes,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
