part of 'profile_repository.dart';

extension ProfileAccount on ProfileRepository {
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
  }) async {
    final key = username.trim().toLowerCase().replaceAll('@', '');
    if (key.length < 3) {
      throw const ValidationException('El usuario debe tener al menos 3 caracteres.');
    }
    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(key)) {
      throw const ValidationException('Usuario: solo letras minúsculas, números, punto y guión bajo.');
    }
    final ref = _db.collection('usernames').doc(key);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        final data = snap.data();
        if (data == null || data['uid'] != uid) {
          throw const ValidationException('Ese nombre de usuario ya está en uso.');
        }
      }
      tx.set(ref, {
        'uid': uid,
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

  Future<void> changeUsername({
    required String uid,
    required String? oldUsername,
    required String newUsername,
  }) async {
    final neu = newUsername.trim().toLowerCase().replaceAll('@', '');
    final old = oldUsername?.trim().toLowerCase().replaceAll('@', '');
    if (neu == old) return;
    final ok = await isUsernameAvailable(neu, exceptUid: uid);
    if (!ok) throw const ValidationException('Ese nombre de usuario ya está en uso.');
    await claimUsername(username: neu, uid: uid);
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
    // Debe incluir TODAS las subcolecciones del perfil; si falta alguna,
    // sus datos quedan huérfanos tras borrar la cuenta.
    const subs = [
      'weightHistory',
      'routines',
      'exerciseDefaults',
      'dailyLogs',
      'savedFoods',
      'savedRecipes',
      'workoutSessions',
      'customExercises',
      'favoriteExercises',
    ];
    // Firestore limita un batch a 500 operaciones: borramos por páginas.
    const pageSize = 400;
    for (final name in subs) {
      final col = userRef.collection(name);
      while (true) {
        final snap = await col.limit(pageSize).get();
        if (snap.docs.isEmpty) break;
        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < pageSize) break;
      }
    }
    final doc = await userRef.get();
    if (doc.exists) {
      await userRef.delete();
    }

    // 2) Liberar el username para que pueda reutilizarse
    await releaseUsername(usernameToRelease);
  }
}
