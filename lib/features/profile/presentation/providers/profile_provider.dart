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

final todayLogProvider = FutureProvider<DailyLog>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return DailyLog(date: '');
  return ref.watch(profileRepositoryProvider).getTodayLog(user.uid);
});

final dailyLogsHistoryProvider =
FutureProvider.family<List<DailyLog>, int>((ref, days) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(profileRepositoryProvider).getDailyLogsHistory(
    user.uid,
    days: days,
  );
});