import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_profile.dart';

class ProfileRepository {
  ProfileRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference _userDoc(String uid) => _db.collection('users');

  // ─── Perfil ─────────────────────────────────────────────
  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _userDoc(uid).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _userDoc(profile.uid).doc(profile.uid).set(
      profile.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> updateProfileFields(String uid, Map<String, dynamic> fields) async {
    fields['updatedAt'] = DateTime.now().toIso8601String();
    await _userDoc(uid).doc(uid).update(fields);
  }

  // ─── Historial de peso ──────────────────────────────────
  Future<List<WeightEntry>> getWeightHistory(String uid) async {
    final snap = await _userDoc(uid)
        .doc(uid)
        .collection('weightHistory')
        .orderBy('date', descending: true)
        .get();

    return snap.docs
        .map((d) => WeightEntry.fromMap(d.id, d.data()))
        .toList();
  }

  Future<void> addWeightEntry(String uid, double weight, DateTime date) async {
    final entry = WeightEntry(id: '', weight: weight, date: date);
    await _userDoc(uid).doc(uid).collection('weightHistory').add(entry.toMap());

    // Peso actual + agua recomendada proporcional al peso
    final waterMl = UserProfile.calculateWaterMl(weightKg: weight);
    await updateProfileFields(uid, {
      'currentWeight': weight,
      'targetWaterMl': waterMl,
    });
  }

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
  // ─── Daily Log (agua + sueño + comidas) ─────────────────
  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  DocumentReference _todayLogRef(String uid) {
    return _userDoc(uid).doc(uid).collection('dailyLogs').doc(_todayKey());
  }

  Future<DailyLog> getTodayLog(String uid) async {
    final key = _todayKey();
    final doc = await _todayLogRef(uid).get();
    if (!doc.exists || doc.data() == null) {
      return DailyLog(date: key);
    }
    return DailyLog.fromMap(doc.data()! as Map<String, dynamic>);
  }

  Future<void> updateTodayLog(
      String uid, {
        int? waterGlasses,
        double? sleepHours,
        int? consumedCalories,
        int? proteinGrams,
        int? carbsGrams,
        int? fatGrams,
      }) async {
    final key = _todayKey();
    final data = <String, dynamic>{'date': key};
    if (waterGlasses != null) data['waterGlasses'] = waterGlasses;
    if (sleepHours != null) data['sleepHours'] = sleepHours;
    if (consumedCalories != null) data['consumedCalories'] = consumedCalories;
    if (proteinGrams != null) data['proteinGrams'] = proteinGrams;
    if (carbsGrams != null) data['carbsGrams'] = carbsGrams;
    if (fatGrams != null) data['fatGrams'] = fatGrams;
    await _todayLogRef(uid).set(data, SetOptions(merge: true));
  }

  Future<void> _saveLogWithMeals(String uid, List<MealEntry> meals) async {
    final key = _todayKey();
    final cal = meals.fold<int>(0, (s, m) => s + m.calories);
    final protein = meals.fold<int>(0, (s, m) => s + m.proteinGrams);
    final carbs = meals.fold<int>(0, (s, m) => s + m.carbsGrams);
    final fat = meals.fold<int>(0, (s, m) => s + m.fatGrams);

    // Preservar agua/sueño si ya existen
    final existing = await getTodayLog(uid);

    await _todayLogRef(uid).set({
      'date': key,
      'meals': meals.map((m) => m.toMap()).toList(),
      'consumedCalories': cal,
      'proteinGrams': protein,
      'carbsGrams': carbs,
      'fatGrams': fat,
      'waterGlasses': existing.waterGlasses,
      'sleepHours': existing.sleepHours,
    }, SetOptions(merge: true));
  }

  /// Agrega una comida y recalcula totales del día.
  Future<void> addMeal(String uid, MealEntry meal) async {
    final log = await getTodayLog(uid);
    final meals = [...log.meals, meal];
    await _saveLogWithMeals(uid, meals);
  }

  /// Elimina una comida por id y recalcula totales.
  Future<void> removeMeal(String uid, String mealId) async {
    final log = await getTodayLog(uid);
    final meals = log.meals.where((m) => m.id != mealId).toList();
    await _saveLogWithMeals(uid, meals);
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
    await ref.set(data, SetOptions(merge: true));
  }

  /// Historial de los últimos N días (más reciente primero)
  Future<List<DailyLog>> getDailyLogsHistory(String uid, {int days = 30}) async {
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
    final log = await getTodayLog(uid);
    final meals = log.meals.map((m) {
      return m.id == updated.id ? updated : m;
    }).toList();
    await _saveLogWithMeals(uid, meals);
  }

  // ─── Alimentos guardados (biblioteca personal) ──────────
  CollectionReference _savedFoods(String uid) =>
      _userDoc(uid).doc(uid).collection('savedFoods');

  Future<List<SavedFood>> getSavedFoods(String uid) async {
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

  Future<List<SavedRecipe>> getSavedRecipes(String uid) async {
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
      await incrementRecipeUse(uid, recipe.id);
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
    await incrementFoodUse(uid, food.id);
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





// ─── Sesiones de entrenamiento ──────────────────────────
  // Doc id = session.id (único). Ya NO es solo yyyy-MM-dd.

  DocumentReference _sessionRef(String uid, String sessionId) =>
      _userDoc(uid).doc(uid).collection('workoutSessions').doc(sessionId);

  WorkoutSession _sessionFromDoc(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw is! Map) {
      throw StateError('Sesión inválida');
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



  // ─── Usernames únicos (colección global) ─────────────────
  // usernames/{usernameLower} -> { uid, email, username }


  Future<void> updateWaterTargetForWeight(String uid, double weightKg) async {
    final ml = UserProfile.calculateWaterMl(weightKg: weightKg);
    await updateProfileFields(uid, {'targetWaterMl': ml, 'currentWeight': weightKg});
  }

  Future<bool> isUsernameAvailable(String username, {String? exceptUid}) async {
    final key = username.trim().toLowerCase().replaceAll('@', '');
    if (key.length < 3) return false;
    final doc = await _db.collection('usernames').doc(key).get();
    if (!doc.exists) return true;
    final data = doc.data();
    if (exceptUid != null && data != null && data['uid'] == exceptUid) {
      return true;
    }
    return false;
  }

  Future<void> claimUsername({
    required String username,
    required String uid,
    required String email,
  }) async {
    final key = username.trim().toLowerCase().replaceAll('@', '');
    if (key.length < 3) {
      throw 'El usuario debe tener al menos 3 caracteres.';
    }
    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(key)) {
      throw 'Usuario: solo letras minúsculas, números, punto y guión bajo.';
    }
    final ref = _db.collection('usernames').doc(key);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = snap.data();
        if (data == null || data['uid'] != uid) {
          throw 'Ese nombre de usuario ya está en uso.';
        }
      }
      tx.set(ref, {
        'uid': uid,
        'email': email.trim().toLowerCase(),
        'username': key,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> releaseUsername(String? username) async {
    if (username == null || username.trim().isEmpty) return;
    final key = username.trim().toLowerCase().replaceAll('@', '');
    await _db.collection('usernames').doc(key).delete();
  }

  Future<String?> resolveUsernameToEmail(String username) async {
    final key = username.trim().toLowerCase().replaceAll('@', '');
    final doc = await _db.collection('usernames').doc(key).get();
    if (!doc.exists || doc.data() == null) return null;
    return doc.data()!['email'] as String?;
  }

  Future<void> changeUsername({
    required String uid,
    required String email,
    required String? oldUsername,
    required String newUsername,
  }) async {
    final neu = newUsername.trim().toLowerCase().replaceAll('@', '');
    final old = oldUsername?.trim().toLowerCase().replaceAll('@', '');
    if (neu == old) return;
    final ok = await isUsernameAvailable(neu, exceptUid: uid);
    if (!ok) throw 'Ese nombre de usuario ya está en uso.';
    await claimUsername(username: neu, uid: uid, email: email);
    if (old != null && old.isNotEmpty && old != neu) {
      await releaseUsername(old);
    }
  }

  /// Borra el documento de perfil y subcolecciones del usuario.
  /// Borra el documento de perfil, subcolecciones Y libera el username.
  Future<void> deleteUserData(String uid) async {
    // 1) Leer el perfil ANTES de borrarlo para saber qué username liberar
    final profile = await getProfile(uid);
    final usernameToRelease = profile?.username;

    final userRef = _userDoc(uid).doc(uid);
    final subs = [
      'weightHistory',
      'routines',
      'dailyLogs',
      'savedFoods',
      'customExercises',
      'favoriteExercises',
      'workoutSessions',
    ];
    for (final name in subs) {
      final snap = await userRef.collection(name).get();
      if (snap.docs.isEmpty) continue;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    final doc = await userRef.get();
    if (doc.exists) {
      await userRef.delete();
    }

    // 2) Liberar el username para que pueda reutilizarse
    await releaseUsername(usernameToRelease);
  }
}
