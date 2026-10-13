import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/user_profile.dart';

part 'profile_repository_routines.dart';
part 'profile_repository_nutrition.dart';
part 'profile_repository_workouts.dart';
part 'profile_repository_account.dart';
part 'profile_repository_custom_routines.dart';

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

  Future<void> updateWaterTargetForWeight(String uid, double weightKg) async {
    final ml = UserProfile.calculateWaterMl(weightKg: weightKg);
    await updateProfileFields(uid, {'targetWaterMl': ml, 'currentWeight': weightKg});
  }
}
