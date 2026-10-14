part of 'profile_repository.dart';

extension ProfileOffline on ProfileRepository {
  bool _online() => _isOnline?.call() ?? true;

  /// Intenta escribir en Firestore; si no hay red (o falla), encola la
  /// operación en el dispositivo para subirla cuando vuelva la conexión.
  Future<void> _runOrQueue(
    OfflineOp op,
    Future<void> Function() run, {
    bool forceQueue = false,
  }) async {
    if (!forceQueue && _online()) {
      try {
        await run().timeout(const Duration(seconds: 12));
        // Solo tocamos la cola si había algo (evita abrir el disco de más).
        if (_offline.length > 0) await _offline.remove(op.dedupeKey);
        return;
      } catch (e) {
        debugPrint('offline: se encola ${op.type.name}: $e');
      }
    }
    await _offline.put(op);
  }

  /// Aplica una operación encolada (lo usa el sincronizador al reconectar).
  Future<void> applyOfflineOp(OfflineOp op) async {
    switch (op.type) {
      case OfflineOpType.workoutSession:
        await _writeSession(op.uid, WorkoutSession.fromMap(op.payload));
      case OfflineOpType.mealUpsert:
        await _applyMealUpsert(
          op.uid,
          op.payload['dateKey']?.toString() ?? _todayKey(),
          MealEntry.fromMap(
            Map<String, dynamic>.from(op.payload['meal'] as Map),
          ),
        );
      case OfflineOpType.mealRemove:
        await _applyMealRemove(
          op.uid,
          op.payload['dateKey']?.toString() ?? _todayKey(),
          op.payload['mealId']?.toString() ?? '',
        );
    }
  }

  /// Sesiones de [uid] que están en la cola sin subir.
  List<WorkoutSession> _pendingSessions(String uid) => _offline.ops
      .where((o) => o.type == OfflineOpType.workoutSession && o.uid == uid)
      .map((o) => WorkoutSession.fromMap(o.payload))
      .toList();
}
