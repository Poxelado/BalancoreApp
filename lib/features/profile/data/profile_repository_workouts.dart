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

  Future<void> _writeSession(String uid, WorkoutSession session) async {
    final data = session.toMap();
    data['id'] = session.id;
    await _sessionRef(uid, session.id).set(data);
  }

  Future<void> saveWorkoutSession(String uid, WorkoutSession session) async {
    await _runOrQueue(
      OfflineOp(
        type: OfflineOpType.workoutSession,
        uid: uid,
        dedupeKey: 'ws:${session.id}',
        payload: session.toMap(),
        createdAt: DateTime.now().toIso8601String(),
      ),
      () => _writeSession(uid, session),
    );
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
    final list = snap.docs.map(_sessionFromDoc).toList();
    // Sumar las que están en la cola local sin subir.
    for (final p in _pendingSessions(uid)) {
      if (!p.completed) list.add(p);
    }
    if (list.isEmpty) return null;
    final byId = {for (final s in list) s.id: s};
    final merged = byId.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return merged.first;
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
    final list = snap.docs.map(_sessionFromDoc).toList();
    final byId = {for (final s in list) s.id: s};
    for (final p in _pendingSessions(uid)) {
      byId[p.id] = p;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    if (limit > 0 && merged.length > limit) {
      return merged.sublist(0, limit);
    }
    return merged;
  }

  /// Ajusta el nivel de actividad según los entrenos completados en los últimos
  /// 7 días. Solo sube el nivel (nunca baja el que eligió el usuario). Si
  /// cambia, recalcula calorías y macros y devuelve el perfil actualizado; si
  /// no hay cambios devuelve null.
  Future<UserProfile?> refineActivityFromWorkouts(String uid) async {
    final profile = await getProfile(uid);
    if (profile == null || !profile.onboardingCompleted) return null;

    final history = await getWorkoutHistory(uid, limit: 60);
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final sessions = history
        .where((s) => s.completed && !s.startedAt.isBefore(cutoff))
        .length;

    final refined = profile.refinedActivityLevel(sessions);
    if (refined == profile.activityLevel) return null;

    final kcal = UserProfile.calculateTMB(
      sex: profile.sex,
      weight: profile.currentWeight,
      height: profile.height,
      age: profile.age,
      activityLevel: refined,
      goal: profile.goal,
    );
    final macros = UserProfile.calculateMacros(
      weight: profile.currentWeight,
      height: profile.height,
      calories: kcal,
      goal: profile.goal,
    );

    await updateProfileFields(uid, {
      'activityLevel': refined,
      'targetCalories': kcal,
      'targetProtein': macros.protein,
      'targetCarbs': macros.carbs,
      'targetFat': macros.fat,
    });

    return profile.copyWith(
      activityLevel: refined,
      targetCalories: kcal,
      targetProtein: macros.protein,
      targetCarbs: macros.carbs,
      targetFat: macros.fat,
    );
  }
}
