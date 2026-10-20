import 'package:flutter/foundation.dart';

part 'user_profile_account.dart';
part 'user_profile_routine.dart';
part 'user_profile_food.dart';
part 'user_profile_workouts.dart';
part 'user_profile_custom_routine.dart';

// ─── Helpers anti-null (Firestore) ─────────────────────────
String _str(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  return v.toString();
}

DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  if (v is String) {
    return DateTime.tryParse(v) ?? DateTime.now();
  }
  // Firestore Timestamp
  try {
    final d = v.toDate();
    if (d is DateTime) return d;
  } catch (e) {
    debugPrint('user_profile: fecha no parseable ($v): $e');
  }
  return DateTime.now();
}
