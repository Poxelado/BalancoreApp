import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/user_profile.dart';

class ProfileRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection('users');

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
  }

  Future<void> saveProfile(UserProfile profile) async {
    await _users.doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  Future<bool> hasCompletedOnboarding(String uid) async {
    final profile = await getProfile(uid);
    return profile?.onboardingCompleted ?? false;
  }
}