import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/offline/local_cache.dart';
import '../../../core/offline/offline_op.dart';
import '../../../core/offline/offline_store.dart';
import '../domain/user_profile.dart';

part 'profile_repository_routines.dart';
part 'profile_repository_nutrition.dart';
part 'profile_repository_workouts.dart';
part 'profile_repository_account.dart';
part 'profile_repository_custom_routines.dart';
part 'profile_repository_offline.dart';

class ProfileRepository {
  ProfileRepository({
    FirebaseFirestore? db,
    OfflineStore? offline,
    LocalCache? cache,
    bool Function()? isOnline,
  })  : _db = db ?? FirebaseFirestore.instance,
        _offline = offline ?? OfflineStore(),
        _cache = cache ?? LocalCache(),
        _isOnline = isOnline;

  final FirebaseFirestore _db;
  final OfflineStore _offline;
  final LocalCache _cache;
  final bool Function()? _isOnline;

  CollectionReference _userDoc(String uid) => _db.collection('users');

  // ─── Perfil ─────────────────────────────────────────────
  Future<UserProfile?> getProfile(String uid) async {
    try {
      final doc = await _userDoc(uid)
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 8));
      if (!doc.exists || doc.data() == null) return null;
      final profile = UserProfile.fromMap(doc.data() as Map<String, dynamic>);
      unawaited(_cache.save('profile:$uid', profile.toMap()));
      return profile;
    } catch (e) {
      final cached = await _cache.read('profile:$uid');
      if (cached is Map) {
        return UserProfile.fromMap(Map<String, dynamic>.from(cached));
      }
      rethrow;
    }
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
