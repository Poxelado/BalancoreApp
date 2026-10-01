import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/exercise_repository.dart';
import '../../domain/exercise.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepository();
});

final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return ExerciseCatalog.builtIn;
  return ref.watch(exerciseRepositoryProvider).getAllExercises(user.uid);
});

final favoriteExerciseIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return {};
  return ref.watch(exerciseRepositoryProvider).getFavoriteIds(user.uid);
});
