import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/offline/offline_store.dart';
import '../../../../core/offline/offline_sync.dart';
import '../../data/profile_repository.dart';
import '../../domain/user_profile.dart';

export '../../data/profile_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Cola local de escrituras pendientes de subir (compartida por toda la app).
final offlineStoreProvider = Provider<OfflineStore>((ref) {
  final store = OfflineStore();
  ref.onDispose(store.dispose);
  return store;
});

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

/// ¿Hay conexión a internet? Se actualiza sola cuando cambia la red.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = ref.watch(connectivityProvider);
  try {
    yield _onlineFrom(await connectivity.checkConnectivity());
    yield* connectivity.onConnectivityChanged.map(_onlineFrom).distinct();
  } catch (_) {
    // Sin el plugin (p. ej. en tests) asumimos que hay red.
    yield true;
  }
});

bool _onlineFrom(List<ConnectivityResult> results) =>
    results.isEmpty || results.any((r) => r != ConnectivityResult.none);

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    offline: ref.watch(offlineStoreProvider),
    isOnline: () => ref.read(isOnlineProvider).value ?? true,
  );
});

/// Cuántas escrituras quedan pendientes de subir (para el indicador).
final pendingUploadsProvider = StreamProvider<int>((ref) async* {
  final store = ref.watch(offlineStoreProvider);
  await store.load();
  yield store.length;
  yield* store.changes.map((_) => store.length);
});

/// Reenvía la cola al recuperar la conexión.
final offlineSyncProvider = Provider<OfflineSync>((ref) {
  return OfflineSync(
    store: ref.watch(offlineStoreProvider),
    apply: (op) => ref.read(profileRepositoryProvider).applyOfflineOp(op),
    onSynced: () => invalidateProgressData(ref),
  );
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

final customRoutinesProvider = FutureProvider<List<CustomRoutine>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.watch(profileRepositoryProvider).getCustomRoutines(user.uid);
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

final savedRecipesProvider = FutureProvider<List<SavedRecipe>>((ref) async {
  final user = ref.watch(authServiceProvider).currentUser;
  if (user == null) return [];
  return ref.watch(profileRepositoryProvider).getSavedRecipes(user.uid);
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
  final list = await ref
      .watch(profileRepositoryProvider)
      .getSessionsForDate(user.uid, key);
  if (list.isEmpty) return null;
  // La más reciente del día (completa o no)
  list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return list.first;
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


/// 0 Progreso, 1 Nutrición, 2 Inicio, 3 Rutina, 4 Perfil
final shellTabProvider = StateProvider<int>((ref) => 2);

/// 0 Entrenos, 1 Constancia, 2 Hábitos
final progressSectionProvider = StateProvider<int>((ref) => 1);

/// null = resumen, 0 kcal, 1 agua, 2 sueño, 3 macros
final habitsMetricProvider = StateProvider<int?>((ref) => null);

/// Username elegido en el registro; el onboarding lo usa si el perfil aún no carga.
final pendingUsernameProvider = StateProvider<String?>((ref) => null);

/// Uid del usuario que decidió continuar sin verificar el correo por ahora.
/// Guardar el uid (y no un bool) evita que el salto se herede a otra cuenta en
/// el mismo dispositivo.
final skipEmailVerificationProvider = StateProvider<String?>((ref) => null);
