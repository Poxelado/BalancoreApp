import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_profile.dart';

class ProfileRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

    // Actualizar peso actual del perfil
    await updateProfileFields(uid, {'currentWeight': weight});
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
    final snap = await _savedFoods(uid).orderBy('name').get();
    return snap.docs
        .map((d) => SavedFood.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<String> saveFood(String uid, SavedFood food) async {
    final data = food.toMap();
    if (food.id.isEmpty) {
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



  // ─── Sesiones de entrenamiento ──────────────────────────
  DocumentReference _sessionRef(String uid, String dateKey) =>
      _userDoc(uid).doc(uid).collection('workoutSessions').doc(dateKey);

  Future<WorkoutSession?> getWorkoutSession(String uid, String dateKey) async {
    final doc = await _sessionRef(uid, dateKey).get();
    if (!doc.exists || doc.data() == null) return null;
    return WorkoutSession.fromMap(doc.data()! as Map<String, dynamic>);
  }

  Future<void> saveWorkoutSession(String uid, WorkoutSession session) async {
    await _sessionRef(uid, session.id).set(session.toMap());
  }

  Future<List<WorkoutSession>> getWorkoutHistory(String uid, {int limit = 30}) async {
    final snap = await _userDoc(uid)
        .doc(uid)
        .collection('workoutSessions')
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => WorkoutSession.fromMap(d.data() as Map<String, dynamic>))
        .toList();
  }

  /// Borra el documento de perfil y subcolecciones del usuario.
  Future<void> deleteUserData(String uid) async {
    final userRef = _userDoc(uid).doc(uid);
    final subs = ['weightHistory', 'routines', 'dailyLogs', 'savedFoods', 'customExercises', 'favoriteExercises', 'workoutSessions'];
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
  }
}
