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
      case OfflineOpType.workoutDelete:
        await _sessionRef(op.uid, op.payload['id']?.toString() ?? '').delete();
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
      case OfflineOpType.dailyLog:
        final data = Map<String, dynamic>.from(
          (op.payload['data'] as Map?) ?? const <String, dynamic>{},
        );
        final key = op.payload['dateKey']?.toString() ?? _todayKey();
        data['date'] = key;
        await _logRef(op.uid, key).set(data, SetOptions(merge: true));
      case OfflineOpType.foodUpsert:
        final id = op.payload['id']?.toString() ?? '';
        final raw = op.payload['food'];
        if (id.isEmpty || raw is! Map) break;
        await _savedFoods(op.uid)
            .doc(id)
            .set(Map<String, dynamic>.from(raw), SetOptions(merge: true));
      case OfflineOpType.foodDelete:
        final id = op.payload['id']?.toString() ?? '';
        if (id.isEmpty) break;
        await _savedFoods(op.uid).doc(id).delete();
      case OfflineOpType.recipeUpsert:
        final id = op.payload['id']?.toString() ?? '';
        final raw = op.payload['recipe'];
        if (id.isEmpty || raw is! Map) break;
        await _savedRecipes(op.uid)
            .doc(id)
            .set(Map<String, dynamic>.from(raw), SetOptions(merge: true));
      case OfflineOpType.recipeDelete:
        final id = op.payload['id']?.toString() ?? '';
        if (id.isEmpty) break;
        await _savedRecipes(op.uid).doc(id).delete();
    }
  }

  /// Aplica sobre [list] los alimentos guardados pendientes de subir.
  List<SavedFood> overlayFoods(String uid, List<SavedFood> list) {
    final byId = {for (final f in list) f.id: f};
    for (final op in _offline.ops) {
      if (op.uid != uid) continue;
      if (op.type == OfflineOpType.foodUpsert) {
        final id = op.payload['id']?.toString() ?? '';
        final raw = op.payload['food'];
        if (id.isEmpty || raw is! Map) continue;
        byId[id] = SavedFood.fromMap(id, Map<String, dynamic>.from(raw));
      } else if (op.type == OfflineOpType.foodDelete) {
        byId.remove(op.payload['id']?.toString() ?? '');
      }
    }
    return byId.values.toList()
      ..sort((a, b) {
        final c = b.useCount.compareTo(a.useCount);
        if (c != 0) return c;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  /// Aplica sobre [list] las recetas pendientes de subir.
  List<SavedRecipe> overlayRecipes(String uid, List<SavedRecipe> list) {
    final byId = {for (final r in list) r.id: r};
    for (final op in _offline.ops) {
      if (op.uid != uid) continue;
      if (op.type == OfflineOpType.recipeUpsert) {
        final id = op.payload['id']?.toString() ?? '';
        final raw = op.payload['recipe'];
        if (id.isEmpty || raw is! Map) continue;
        byId[id] = SavedRecipe.fromMap(id, Map<String, dynamic>.from(raw));
      } else if (op.type == OfflineOpType.recipeDelete) {
        byId.remove(op.payload['id']?.toString() ?? '');
      }
    }
    return byId.values.toList()
      ..sort((a, b) {
        final c = b.useCount.compareTo(a.useCount);
        if (c != 0) return c;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  /// Genera un id local para un alimento o receta creado sin conexión.
  String _localId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Guarda agua/sueño/pasos del día, encolando en el dispositivo si no hay
  /// red. Fusiona con lo ya pendiente para no pisar otros campos.
  Future<void> _queueDailyPatch(
    String uid,
    String dateKey,
    Map<String, dynamic> data,
  ) async {
    var merged = <String, dynamic>{...data};
    for (final op in _offline.ops) {
      if (op.type != OfflineOpType.dailyLog || op.uid != uid) continue;
      if (op.payload['dateKey']?.toString() != dateKey) continue;
      final raw = op.payload['data'];
      if (raw is Map) {
        merged = {...Map<String, dynamic>.from(raw), ...merged};
      }
    }
    await _runOrQueue(
      OfflineOp(
        type: OfflineOpType.dailyLog,
        uid: uid,
        dedupeKey: 'dailyLog:$dateKey',
        payload: {'dateKey': dateKey, 'data': merged},
        createdAt: DateTime.now().toIso8601String(),
      ),
      () => _logRef(uid, dateKey).set(merged, SetOptions(merge: true)),
    );
  }

  /// Sesiones de [uid] que están en la cola sin subir.
  List<WorkoutSession> _pendingSessions(String uid) => _offline.ops
      .where((o) => o.type == OfflineOpType.workoutSession && o.uid == uid)
      .map((o) => WorkoutSession.fromMap(o.payload))
      .toList();

  /// Ids de sesiones de [uid] con borrado pendiente de subir.
  Set<String> _pendingSessionDeletes(String uid) => _offline.ops
      .where((o) => o.type == OfflineOpType.workoutDelete && o.uid == uid)
      .map((o) => o.payload['id']?.toString() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();

  /// Lee una lista de Firestore y guarda copia local. Sin conexión devuelve
  /// directamente la copia local (o lista vacía) para no colgar la UI.
  Future<List<T>> _cachedList<T>(
    String key, {
    required Future<List<T>> Function() fetch,
    required Map<String, dynamic> Function(T) encode,
    required T Function(Map<String, dynamic>) decode,
  }) async {
    if (!_online()) {
      final cached = await _readCacheList(key, decode);
      if (cached != null) {
        debugPrint('cache: usando $key (${cached.length})');
        return cached;
      }
      debugPrint('cache: sin datos para $key (sin conexión)');
      return <T>[];
    }
    try {
      final list = await fetch().timeout(const Duration(seconds: 8));
      unawaited(_cache.save(key, list.map(encode).toList()));
      return list;
    } catch (e) {
      debugPrint('cache: falló la lectura de $key: $e');
      final cached = await _readCacheList(key, decode);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Decodifica una lista cacheada; devuelve null si no hay copia utilizable.
  Future<List<T>?> _readCacheList<T>(
    String key,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final cached = await _cache.read(key);
    if (cached is! List) return null;
    final out = <T>[];
    for (final item in cached) {
      if (item is Map) {
        try {
          out.add(decode(Map<String, dynamic>.from(item)));
        } catch (_) {}
      }
    }
    if (out.isNotEmpty || cached.isEmpty) return out;
    return null;
  }
}
