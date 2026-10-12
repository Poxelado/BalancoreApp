part of 'profile_repository.dart';

extension ProfileWorkouts on ProfileRepository {
// ─── Sesiones de entrenamiento ──────────────────────────
  // Doc id = session.id (único). Ya NO es solo yyyy-MM-dd.

  DocumentReference _sessionRef(String uid, String sessionId) =>
      _userDoc(uid).doc(uid).collection('workoutSessions').doc(sessionId);

  WorkoutSession _sessionFromDoc(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw is! Map) {
      throw const DataException('Sesión inválida');
    }
    final map = Map<String, dynamic>.from(raw);
    if (_str(map['id']).isEmpty) {
      map['id'] = doc.id;
    }
    return WorkoutSession.fromMap(map);
  }

  String _str(dynamic v) => v?.toString() ?? '';

  Future<WorkoutSession?> getWorkoutSession(String uid, String sessionId) async {
    final doc = await _sessionRef(uid, sessionId).get();
    if (!doc.exists || doc.data() == null) return null;
    return _sessionFromDoc(doc);
  }

  Future<void> saveWorkoutSession(String uid, WorkoutSession session) async {
    final data = session.toMap();
    data['id'] = session.id;
    await _sessionRef(uid, session.id).set(data);
  }

  Future<void> deleteWorkoutSession(String uid, String sessionId) async {
    await _sessionRef(uid, sessionId).delete();
  }

  Future<WorkoutSession?> getActiveWorkoutSession(String uid) async {
    final snap = await _userDoc(uid)
        .doc(uid)
        .collection('workoutSessions')
        .where('completed', isEqualTo: false)
        .limit(20)
        .get();
    if (snap.docs.isEmpty) return null;
    final list = snap.docs.map(_sessionFromDoc).toList();
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return list.first;
  }

  /// Sesión incompleta de esta rutina (mismo dayName), si existe.
  Future<WorkoutSession?> findIncompleteSessionForRoutine(
      String uid, {
        required String dayName,
        String? title,
      }) async {
    final snap = await _userDoc(uid)
        .doc(uid)
        .collection('workoutSessions')
        .where('completed', isEqualTo: false)
        .limit(20)
        .get();
    if (snap.docs.isEmpty) return null;
    final list = snap.docs.map(_sessionFromDoc).toList();
    list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    for (final s in list) {
      if (s.dayName == dayName) {
        if (title == null || title.isEmpty || s.title == title) {
          return s;
        }
      }
    }
    return null;
  }

  /// Todas las sesiones que empezaron en un día calendario (yyyy-MM-dd).
  Future<List<WorkoutSession>> getSessionsForDate(
      String uid,
      String dateKey,
      ) async {
    final list = await getWorkoutHistory(uid, limit: 80);
    return list.where((s) {
      final k = WorkoutSession.dateKey(s.startedAt);
      return k == dateKey;
    }).toList();
  }

  Future<List<WorkoutSession>> getWorkoutHistory(String uid,
      {int limit = 30}) async {
    final snap = await _userDoc(uid)
        .doc(uid)
        .collection('workoutSessions')
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(_sessionFromDoc).toList();
  }
}
