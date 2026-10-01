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

  // ─── Daily Log (agua + sueño) ───────────────────────────
  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<DailyLog> getTodayLog(String uid) async {
    final key = _todayKey();
    final doc = await _userDoc(uid).doc(uid).collection('dailyLogs').doc(key).get();
    if (!doc.exists || doc.data() == null) {
      return DailyLog(date: key);
    }
    return DailyLog.fromMap(doc.data()!);
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
    final ref = _userDoc(uid).doc(uid).collection('dailyLogs').doc(key);
    final data = <String, dynamic>{'date': key};
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
}