part of 'profile_repository.dart';

extension ProfileNutrition on ProfileRepository {
  // ─── Daily Log (agua + sueño + comidas) ─────────────────
  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  DocumentReference _logRef(String uid, String dateKey) {
    return _userDoc(uid).doc(uid).collection('dailyLogs').doc(dateKey);
  }

  Future<DailyLog> getTodayLog(String uid) async {
    final key = _todayKey();
    DailyLog log;
    var fromCache = false;
    if (_online()) {
      try {
        log = await _fetchLog(uid, key);
        unawaited(_cache.save('dailyLog:$uid:$key', log.toMap()));
      } catch (e) {
        debugPrint('cache: falló el log de hoy: $e');
        final cached = await _cache.read('dailyLog:$uid:$key');
        log = cached is Map
            ? DailyLog.fromMap(Map<String, dynamic>.from(cached))
            : DailyLog(date: key);
        fromCache = true;
      }
    } else {
      final cached = await _cache.read('dailyLog:$uid:$key');
      log = cached is Map
          ? DailyLog.fromMap(Map<String, dynamic>.from(cached))
          : DailyLog(date: key);
      fromCache = true;
    }
    if (fromCache) {
      debugPrint('cache: log de hoy desde copia local (${log.meals.length})');
    }
    return _overlayDailyOps(uid, key, _overlayMeals(uid, key, log));
  }

  Future<DailyLog> _fetchLog(String uid, String dateKey) async {
    final doc = await _userDoc(uid)
        .doc(uid)
        .collection('dailyLogs')
        .doc(dateKey)
        .get()
        .timeout(const Duration(seconds: 8));
    if (!doc.exists || doc.data() == null) return DailyLog(date: dateKey);
    return DailyLog.fromMap(Map<String, dynamic>.from(doc.data() as Map));
  }

  /// Aplica sobre [log] las comidas pendientes de subir (cola local) para que
  /// se vean al instante aunque todavía no se hayan sincronizado.
  DailyLog _overlayMeals(String uid, String dateKey, DailyLog log) {
    var meals = List<MealEntry>.from(log.meals);
    var changed = false;
    for (final op in _offline.ops) {
      if (op.uid != uid) continue;
      if (op.payload['dateKey']?.toString() != dateKey) continue;
      if (op.type == OfflineOpType.mealUpsert) {
        final raw = op.payload['meal'];
        if (raw is! Map) continue;
        final meal = MealEntry.fromMap(Map<String, dynamic>.from(raw));
        meals = [
          for (final m in meals)
            if (m.id != meal.id) m,
          meal,
        ];
        changed = true;
      } else if (op.type == OfflineOpType.mealRemove) {
        final id = op.payload['mealId']?.toString();
        if (id == null) continue;
        meals = meals.where((m) => m.id != id).toList();
        changed = true;
      }
    }
    if (!changed) return log;
    return DailyLog.fromMap({
      ...log.toMap(),
      'meals': meals.map((m) => m.toMap()).toList(),
    });
  }

  /// Aplica sobre [log] los cambios de agua/sueño/pasos pendientes de subir.
  DailyLog _overlayDailyOps(String uid, String dateKey, DailyLog log) {
    Map<String, dynamic>? data;
    for (final op in _offline.ops) {
      if (op.uid != uid || op.type != OfflineOpType.dailyLog) continue;
      if (op.payload['dateKey']?.toString() != dateKey) continue;
      final raw = op.payload['data'];
      if (raw is! Map) continue;
      data = {...(data ?? const {}), ...Map<String, dynamic>.from(raw)};
    }
    if (data == null) return log;
    return DailyLog.fromMap({...log.toMap(), ...data});
  }

  Future<void> updateTodayLog(
      String uid, {
        int? waterGlasses,
        double? sleepHours,
        int? consumedCalories,
        int? proteinGrams,
        int? carbsGrams,
        int? fatGrams,
        int? exerciseCalories,
        int? steps,
      }) async {
    final key = _todayKey();
    final data = <String, dynamic>{'date': key};
    if (waterGlasses != null) data['waterGlasses'] = waterGlasses;
    if (sleepHours != null) data['sleepHours'] = sleepHours;
    if (consumedCalories != null) data['consumedCalories'] = consumedCalories;
    if (proteinGrams != null) data['proteinGrams'] = proteinGrams;
    if (carbsGrams != null) data['carbsGrams'] = carbsGrams;
    if (fatGrams != null) data['fatGrams'] = fatGrams;
    if (exerciseCalories != null) data['exerciseCalories'] = exerciseCalories;
    if (steps != null) data['steps'] = steps;
    await _queueDailyPatch(uid, key, data);
  }

  /// Suma kcal de entrenamiento al día indicado (o a hoy). Acumula si hay
  /// varios entrenos en el mismo día.
  Future<void> addExerciseCalories(
      String uid, int kcal, {
        String? dateKey,
      }) async {
    if (kcal <= 0) return;
    final key = dateKey ?? _todayKey();
    await _userDoc(uid).doc(uid).collection('dailyLogs').doc(key).set({
      'date': key,
      'exerciseCalories': FieldValue.increment(kcal),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Guarda los pasos del podómetro para hoy (valor absoluto del día).
  Future<void> setTodaySteps(String uid, int steps) async {
    final key = _todayKey();
    await _queueDailyPatch(uid, key, {
      'date': key,
      'steps': steps < 0 ? 0 : steps,
    });
  }

  Future<void> _writeMeals(
    String uid,
    String dateKey,
    List<MealEntry> meals,
    DailyLog existing,
  ) async {
    final cal = meals.fold<int>(0, (s, m) => s + m.calories);
    final protein = meals.fold<int>(0, (s, m) => s + m.proteinGrams);
    final carbs = meals.fold<int>(0, (s, m) => s + m.carbsGrams);
    final fat = meals.fold<int>(0, (s, m) => s + m.fatGrams);

    await _userDoc(uid).doc(uid).collection('dailyLogs').doc(dateKey).set({
      'date': dateKey,
      'meals': meals.map((m) => m.toMap()).toList(),
      'consumedCalories': cal,
      'proteinGrams': protein,
      'carbsGrams': carbs,
      'fatGrams': fat,
      // Preservar agua/sueño si ya existen
      'waterGlasses': existing.waterGlasses,
      'sleepHours': existing.sleepHours,
    }, SetOptions(merge: true));
  }

  Future<void> _saveLogWithMeals(String uid, List<MealEntry> meals) async {
    final key = _todayKey();
    final existing = await _fetchLog(uid, key);
    await _writeMeals(uid, key, meals, existing);
  }

  /// Inserta o reemplaza por id una comida del día (idempotente).
  Future<void> _applyMealUpsert(
      String uid, String dateKey, MealEntry meal) async {
    final log = await _fetchLog(uid, dateKey);
    final meals = [
      for (final m in log.meals)
        if (m.id != meal.id) m,
      meal,
    ];
    await _writeMeals(uid, dateKey, meals, log);
  }

  /// Quita por id una comida del día (idempotente).
  Future<void> _applyMealRemove(
      String uid, String dateKey, String mealId) async {
    final log = await _fetchLog(uid, dateKey);
    final meals = log.meals.where((m) => m.id != mealId).toList();
    await _writeMeals(uid, dateKey, meals, log);
  }

  OfflineOp _mealOp(String uid, String dateKey, MealEntry meal) => OfflineOp(
        type: OfflineOpType.mealUpsert,
        uid: uid,
        dedupeKey: 'meal:$dateKey:${meal.id}',
        payload: {'dateKey': dateKey, 'meal': meal.toMap()},
        createdAt: DateTime.now().toIso8601String(),
      );

  OfflineOp _mealRemoveOp(String uid, String dateKey, String mealId) =>
      OfflineOp(
        type: OfflineOpType.mealRemove,
        uid: uid,
        dedupeKey: 'meal:$dateKey:$mealId',
        payload: {'dateKey': dateKey, 'mealId': mealId},
        createdAt: DateTime.now().toIso8601String(),
      );

  /// Agrega (o reemplaza por id) una comida y recalcula totales del día.
  Future<void> addMeal(String uid, MealEntry meal) async {
    final key = _todayKey();
    await _runOrQueue(
      _mealOp(uid, key, meal),
      () => _applyMealUpsert(uid, key, meal),
    );
  }

  /// Elimina una comida por id y recalcula totales.
  Future<void> removeMeal(String uid, String mealId) async {
    final key = _todayKey();
    await _runOrQueue(
      _mealRemoveOp(uid, key, mealId),
      () => _applyMealRemove(uid, key, mealId),
    );
  }

  /// Actualiza un día concreto del historial (no solo hoy).
  Future<void> updateDailyLog(
      String uid,
      String dateKey, {
        int? waterGlasses,
        double? sleepHours,
        int? consumedCalories,
        int? proteinGrams,
        int? carbsGrams,
        int? fatGrams,
        int? exerciseCalories,
        int? steps,
      }) async {
    final ref = _userDoc(uid).doc(uid).collection('dailyLogs').doc(dateKey);
    final data = <String, dynamic>{
      'date': dateKey,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (waterGlasses != null) data['waterGlasses'] = waterGlasses;
    if (sleepHours != null) data['sleepHours'] = sleepHours;
    if (consumedCalories != null) data['consumedCalories'] = consumedCalories;
    if (proteinGrams != null) data['proteinGrams'] = proteinGrams;
    if (carbsGrams != null) data['carbsGrams'] = carbsGrams;
    if (fatGrams != null) data['fatGrams'] = fatGrams;
    if (exerciseCalories != null) data['exerciseCalories'] = exerciseCalories;
    if (steps != null) data['steps'] = steps;
    await ref.set(data, SetOptions(merge: true));
  }

  /// Historial de los últimos N días (más reciente primero)
  Future<List<DailyLog>> getDailyLogsHistory(String uid, {int days = 30}) =>
      _cachedList(
        'dailyLogsHistory:$uid:$days',
        fetch: () => _fetchDailyLogsHistory(uid, days: days),
        encode: (l) => l.toMap(),
        decode: DailyLog.fromMap,
      );

  Future<List<DailyLog>> _fetchDailyLogsHistory(String uid,
      {int days = 30}) async {
    final snap = await _userDoc(uid)
        .doc(uid)
        .collection('dailyLogs')
        .orderBy('date', descending: true)
        .limit(days)
        .get();

    return snap.docs.map((d) => DailyLog.fromMap(d.data())).toList();
  }



  /// Actualiza una comida existente por id y recalcula totales.
  Future<void> updateMeal(String uid, MealEntry updated) async {
    final key = _todayKey();
    await _runOrQueue(
      _mealOp(uid, key, updated),
      () => _applyMealUpsert(uid, key, updated),
    );
  }

  // ─── Alimentos guardados (biblioteca personal) ──────────
  CollectionReference _savedFoods(String uid) =>
      _userDoc(uid).doc(uid).collection('savedFoods');

  Future<List<SavedFood>> getSavedFoods(String uid) => _cachedList(
        'savedFoods:$uid',
        fetch: () => _fetchSavedFoods(uid),
        encode: (f) => {...f.toMap(), 'id': f.id},
        decode: (m) => SavedFood.fromMap(m['id']?.toString() ?? '', m),
      );

  Future<List<SavedFood>> _fetchSavedFoods(String uid) async {
    final snap = await _savedFoods(uid).get();
    final list = snap.docs
        .map((d) => SavedFood.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
    // Frecuentes primero (useCount), luego nombre
    list.sort((a, b) {
      final c = b.useCount.compareTo(a.useCount);
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<String> saveFood(String uid, SavedFood food) async {
    final data = food.toMap();
    // Evitar duplicados por nombre (case-insensitive)
    if (food.id.isEmpty) {
      final existing = await getSavedFoods(uid);
      final key = food.name.trim().toLowerCase();
      for (final f in existing) {
        if (f.name.trim().toLowerCase() == key) {
          await _savedFoods(uid).doc(f.id).set({
            ...data,
            'useCount': f.useCount, // no resetear
            'updatedAt': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
          return f.id;
        }
      }
      final ref = await _savedFoods(uid).add(data);
      return ref.id;
    }
    await _savedFoods(uid).doc(food.id).set(data, SetOptions(merge: true));
    return food.id;
  }

  Future<void> deleteSavedFood(String uid, String foodId) async {
    await _savedFoods(uid).doc(foodId).delete();
  }

  Future<void> incrementFoodUse(String uid, String foodId) async {
    final ref = _savedFoods(uid).doc(foodId);
    await ref.set({
      'useCount': FieldValue.increment(1),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }



  // ─── Recetas / platos ───────────────────────────────────
  CollectionReference _savedRecipes(String uid) =>
      _userDoc(uid).doc(uid).collection('savedRecipes');

  Future<List<SavedRecipe>> getSavedRecipes(String uid) => _cachedList(
        'savedRecipes:$uid',
        fetch: () => _fetchSavedRecipes(uid),
        encode: (r) => {...r.toMap(), 'id': r.id},
        decode: (m) => SavedRecipe.fromMap(m['id']?.toString() ?? '', m),
      );

  Future<List<SavedRecipe>> _fetchSavedRecipes(String uid) async {
    final snap = await _savedRecipes(uid).get();
    final list = snap.docs
        .map((d) => SavedRecipe.fromMap(
      d.id,
      d.data() as Map<String, dynamic>,
    ))
        .toList();
    list.sort((a, b) {
      final c = b.useCount.compareTo(a.useCount);
      if (c != 0) return c;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<String> saveRecipe(String uid, SavedRecipe recipe) async {
    final data = recipe.toMap();
    if (recipe.id.isEmpty) {
      final ref = await _savedRecipes(uid).add(data);
      return ref.id;
    }
    await _savedRecipes(uid).doc(recipe.id).set(data, SetOptions(merge: true));
    return recipe.id;
  }

  Future<void> deleteRecipe(String uid, String recipeId) async {
    await _savedRecipes(uid).doc(recipeId).delete();
  }

  Future<void> incrementRecipeUse(String uid, String recipeId) async {
    await _savedRecipes(uid).doc(recipeId).set({
      'useCount': FieldValue.increment(1),
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// Registra un plato en el día (con escala de porción).
  Future<void> addRecipeMeal(
      String uid,
      SavedRecipe recipe, {
        required String mealType,
        double scale = 1.0,
      }) async {
    final meal = recipe.toMealEntry(mealType: mealType, scale: scale);
    await addMeal(uid, meal);
    if (recipe.id.isNotEmpty) {
      try {
        await incrementRecipeUse(uid, recipe.id);
      } catch (e) {
        debugPrint('offline: uso de receta no incrementado: $e');
      }
    }
  }

  /// Comidas recientes de los últimos [days] días (únicas por nombre).
  Future<List<MealEntry>> getRecentMeals(String uid, {int days = 14}) async {
    final logs = await getDailyLogsHistory(uid, days: days);
    final seen = <String>{};
    final recent = <MealEntry>[];
    for (final log in logs) {
      for (final meal in log.meals) {
        final key = meal.name.trim().toLowerCase();
        if (key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        recent.add(meal);
        if (recent.length >= 20) return recent;
      }
    }
    return recent;
  }

  /// Copia comidas de [fromDateKey] (yyyy-MM-dd) al día de hoy.
  /// [replace]=true reemplaza las de hoy; false las agrega.
  /// Devuelve cuántas comidas se copiaron.
  Future<int> copyMealsFromDay(
      String uid,
      String fromDateKey, {
        bool replace = false,
      }) async {
    final fromDoc = await _userDoc(uid)
        .doc(uid)
        .collection('dailyLogs')
        .doc(fromDateKey)
        .get();
    if (!fromDoc.exists || fromDoc.data() == null) return 0;
    final fromLog = DailyLog.fromMap(
      Map<String, dynamic>.from(fromDoc.data() as Map),
    );
    if (fromLog.meals.isEmpty) return 0;

    final today = await getTodayLog(uid);
    final base = DateTime.now().millisecondsSinceEpoch;
    final copied = <MealEntry>[];
    for (var i = 0; i < fromLog.meals.length; i++) {
      final m = fromLog.meals[i];
      copied.add(
        MealEntry(
          id: '${base}_$i',
          name: m.name,
          mealType: m.mealType,
          calories: m.calories,
          proteinGrams: m.proteinGrams,
          carbsGrams: m.carbsGrams,
          fatGrams: m.fatGrams,
        ),
      );
    }
    final meals = replace ? copied : [...today.meals, ...copied];
    await _saveLogWithMeals(uid, meals);
    return copied.length;
  }

  /// Añade al instante un alimento guardado (1 toque).
  Future<void> quickAddSavedFood(
      String uid,
      SavedFood food, {
        String? mealType,
      }) async {
    final type = mealType ??
        food.defaultMealType ??
        _guessMealTypeNow();
    final meal = food.toMeal(mealType: type);
    await addMeal(uid, meal);
    try {
      await incrementFoodUse(uid, food.id);
    } catch (e) {
      debugPrint('offline: uso de alimento no incrementado: $e');
    }
  }

  /// Añade al instante una comida reciente como plantilla.
  Future<void> quickAddMealTemplate(
      String uid,
      MealEntry template, {
        String? mealType,
      }) async {
    final type = mealType ?? template.mealType;
    final meal = MealEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: template.name,
      mealType: type,
      calories: template.calories,
      proteinGrams: template.proteinGrams,
      carbsGrams: template.carbsGrams,
      fatGrams: template.fatGrams,
    );
    await addMeal(uid, meal);
  }

  String _guessMealTypeNow() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Desayuno';
    if (h < 16) return 'Almuerzo';
    if (h < 21) return 'Cena';
    return 'Snack';
  }
}
