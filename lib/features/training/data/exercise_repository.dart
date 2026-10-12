import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/exercise.dart';

class ExerciseRepository {
  ExerciseRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference _custom(String uid) =>
      _db.collection('users').doc(uid).collection('customExercises');

  CollectionReference _favorites(String uid) =>
      _db.collection('users').doc(uid).collection('favoriteExercises');

  /// Carga el catálogo free-exercise-db (filtrado) una sola vez.
  Future<List<Exercise>> loadCatalog() async {
    if (ExerciseCatalog.cache != null) return ExerciseCatalog.cache!;
    try {
      final raw = await rootBundle.loadString('assets/exercises_fedb.json');
      final list = (jsonDecode(raw) as List)
          .map((e) => Exercise.fromFedbAsset(Map<String, dynamic>.from(e as Map)))
          .where((e) => e.id.isNotEmpty)
          .toList();
      ExerciseCatalog.cache = list;
      return list;
    } catch (_) {
      ExerciseCatalog.cache = ExerciseCatalog.fallback;
      return ExerciseCatalog.fallback;
    }
  }

  Future<List<Exercise>> getAllExercises(String uid) async {
    final catalog = await loadCatalog();
    final customSnap = await _custom(uid).get();
    final custom = customSnap.docs
        .map((d) => Exercise.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
    final all = [...catalog, ...custom];
    all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return all;
  }

  Future<List<Exercise>> getCustomExercises(String uid) async {
    final snap = await _custom(uid).orderBy('name').get();
    return snap.docs
        .map((d) => Exercise.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
  }

  Future<String> saveCustomExercise(String uid, Exercise exercise) async {
    final data = exercise.toMap()..['isCustom'] = true;
    if (exercise.id.isEmpty || !exercise.isCustom) {
      final ref = await _custom(uid).add(data);
      return ref.id;
    }
    await _custom(uid).doc(exercise.id).set(data, SetOptions(merge: true));
    return exercise.id;
  }

  Future<void> deleteCustomExercise(String uid, String exerciseId) async {
    await _custom(uid).doc(exerciseId).delete();
    final fav = await _favorites(uid).doc(exerciseId).get();
    if (fav.exists) {
      await _favorites(uid).doc(exerciseId).delete();
    }
  }

  Future<Set<String>> getFavoriteIds(String uid) async {
    final snap = await _favorites(uid).get();
    return snap.docs.map((d) => d.id).toSet();
  }

  Future<void> toggleFavorite(String uid, String exerciseId) async {
    final ref = _favorites(uid).doc(exerciseId);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({'createdAt': FieldValue.serverTimestamp()});
    }
  }
}
