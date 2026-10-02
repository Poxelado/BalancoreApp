import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/profile_repository.dart';
import '../../domain/user_profile.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository();
});

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).getProfile(user.uid);
});

final weightHistoryProvider = FutureProvider<List<WeightEntry>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(profileRepositoryProvider).getWeightHistory(user.uid);
});

final routinesProvider = FutureProvider<List<RoutineDay>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(profileRepositoryProvider).getRoutines(user.uid);
});

final todayLogProvider = FutureProvider.autoDispose<DailyLog>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return DailyLog(date: '');
  return ref.watch(profileRepositoryProvider).getTodayLog(user.uid);
});

final dailyLogsHistoryProvider =
FutureProvider.autoDispose.family<List<DailyLog>, int>((ref, days) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(profileRepositoryProvider).getDailyLogsHistory(
    user.uid,
    days: days,
  );
});

final savedFoodsProvider = FutureProvider<List<SavedFood>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(profileRepositoryProvider).getSavedFoods(user.uid);
});

final recentMealsProvider = FutureProvider<List<MealEntry>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(profileRepositoryProvider).getRecentMeals(user.uid);
});


final todayWorkoutSessionProvider = FutureProvider<WorkoutSession?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  final key = WorkoutSession.dateKey();
  return ref.watch(profileRepositoryProvider).getWorkoutSession(user.uid, key);
});

final todayRoutineProvider = FutureProvider<RoutineDay?>((ref) async {
  final routines = await ref.watch(routinesProvider.future);
  final name = WorkoutSession.weekdayName();
  try {
    return routines.firstWhere((r) => r.day == name);
  } catch (_) {
    return null;
  }
});


final workoutHistoryProvider =
FutureProvider.autoDispose.family<List<WorkoutSession>, int>((ref, days) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  final list = await ref
      .watch(profileRepositoryProvider)
      .getWorkoutHistory(user.uid, limit: 120);
  final cutoff = DateTime.now().subtract(Duration(days: days));
  return list
      .where((s) => s.startedAt.isAfter(cutoff) || s.startedAt.isAtSameMomentAs(cutoff))
      .toList();
});


final activeWorkoutSessionProvider = FutureProvider<WorkoutSession?>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return ref.watch(profileRepositoryProvider).getActiveWorkoutSession(user.uid);
});


/// Invalida logs y entrenos para que Progreso se actualice al instante.
void invalidateProgressData(dynamic ref) {
  ref.invalidate(todayLogProvider);
  ref.invalidate(dailyLogsHistoryProvider);
  ref.invalidate(workoutHistoryProvider);
  ref.invalidate(activeWorkoutSessionProvider);
}
