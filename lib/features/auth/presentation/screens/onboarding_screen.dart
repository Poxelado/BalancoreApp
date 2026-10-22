import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/domain/user_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../training/domain/routine_generator.dart';
import '../../../training/presentation/providers/exercise_provider.dart';
import '../providers/auth_provider.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/notifications/notification_preferences.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/utils/input_limits.dart';
import '../widgets/onboarding_pages.dart';
import '../../../../core/theme/app_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController(text: '70');
  final _heightController = TextEditingController(text: '170');
  final _ageController = TextEditingController(text: '25');

  int _page = 0;
  String _sex = 'Masculino';
  String _activityLevel = 'Sedentario';
  String _goal = 'Mantenimiento';
  bool _isLoading = false;
  int _workoutMin = 18 * 60;
  int _mealMin = 13 * 60;
  int _weightMin = 8 * 60;
  int _weightWeekday = DateTime.monday;
  int _streakInterval = 4;
  bool? _wantNotifs;

  // Rutina dinámica
  RoutineLevel _rLevel = RoutineLevel.intermedio;
  int _rDays = 4;
  int _rMinutes = 60;
  final Set<String> _rEquipment = {};
  List<RoutineDay>? _generatedDays;
  bool _generatingRoutine = false;

  // Términos (para usuarios que no pasan por el registro por correo)
  bool _acceptedTerms = false;
  bool _termsAlreadyAccepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromAuth());
    // Prefetch del catálogo para poder generar la rutina en el paso 4.
    ref.read(exerciseRepositoryProvider).loadCatalog();
  }

  Future<void> _prefillFromAuth() async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    UserProfile? profile = ref.read(userProfileProvider).value;
    profile ??= await ref.read(profileRepositoryProvider).getProfile(user.uid);
    if (!mounted) return;
    if (profile?.displayName != null && profile!.displayName!.isNotEmpty) {
      _nameController.text = profile.displayName!;
    }
    if (profile?.acceptedTerms ?? false) {
      setState(() => _termsAlreadyAccepted = true);
    }
  }

  Future<void> _generateRoutine() async {
    final catalog = ref.read(exercisesProvider).valueOrNull ?? const [];
    if (catalog.isEmpty) return;
    setState(() => _generatingRoutine = true);
    try {
      final days = generateRoutine(
        RoutineRequest(
          goal: RoutineGoal.fromLabel(_goal),
          level: _rLevel,
          daysPerWeek: _rDays,
          minutesAvailable: _rMinutes,
          equipment: _rEquipment,
          catalog: catalog,
        ),
      );
      if (!mounted) return;
      setState(() => _generatedDays = days);
    } finally {
      if (mounted) setState(() => _generatingRoutine = false);
    }
  }


  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  int get _previewCalories {
    final w = double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 70;
    final h = double.tryParse(_heightController.text.replaceAll(',', '.')) ?? 170;
    final a = int.tryParse(_ageController.text) ?? 25;
    return UserProfile.calculateTMB(
      sex: _sex,
      weight: w,
      height: h,
      age: a,
      activityLevel: _activityLevel,
      goal: _goal,
    );
  }

  String get _previewWater {
    final w = double.tryParse(_weightController.text) ?? 70;
    return UserProfile.waterLabel(w);
  }

  ({int protein, int carbs, int fat}) get _previewMacros {
    final w = double.tryParse(_weightController.text) ?? 70;
    final h = double.tryParse(_heightController.text) ?? 170;
    return UserProfile.calculateMacros(
      weight: w,
      height: h,
      calories: _previewCalories,
      goal: _goal,
    );
  }

  /// Devuelve un username válido y lo reclama para el usuario actual.
  /// Prioriza el del registro por email; si no existe (p. ej. cuenta de Google)
  /// genera uno a partir del nombre/correo y garantiza que sea único.
  Future<String> _resolveUsername() async {
    final user = ref.read(authServiceProvider).currentUser!;
    final repo = ref.read(profileRepositoryProvider);

    var uname = (ref.read(pendingUsernameProvider) ?? '')
        .trim()
        .replaceAll('@', '')
        .toLowerCase();
    if (uname.isEmpty) {
      final existing = await repo.getProfile(user.uid);
      uname = (existing?.username ?? '').trim().replaceAll('@', '').toLowerCase();
    }
    if (uname.length < 3) {
      uname = await _generateUsername(
        user.displayName ?? user.email?.split('@').first ?? 'usuario',
      );
    }

    // Idempotente: si ya es suyo, la transacción lo re-escribe sin problema.
    await repo.claimUsername(
      username: uname,
      uid: user.uid,
    );
    return uname;
  }

  Future<String> _generateUsername(String raw) async {
    final repo = ref.read(profileRepositoryProvider);
    final cleaned = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._]'), '')
        .replaceAll(RegExp(r'^[._]+'), '')
        .replaceAll(RegExp(r'[._]+$'), '');
    final base = cleaned.length >= 3
        ? cleaned
        : 'user${DateTime.now().millisecondsSinceEpoch % 1000000}';

    var candidate = base;
    var i = 1;
    while (!await repo.isUsernameAvailable(candidate)) {
      candidate = '$base$i';
      i++;
      if (i > 999) {
        candidate = 'user${DateTime.now().microsecondsSinceEpoch % 1000000}';
        break;
      }
    }
    return candidate;
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Seguro que quieres salir? Podrás volver a entrar con tu cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authServiceProvider).signOut();
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_wantNotifs == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige Sí o No en recordatorios para continuar.')),
      );
      return;
    }
    if (!_termsAlreadyAccepted && !_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los Términos y Condiciones para continuar.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw const AuthException('No hay usuario autenticado');

      final weight = Validators.parseDouble(_weightController.text);
      final height = Validators.parseDouble(_heightController.text);
      final age = Validators.parseInt(_ageController.text);

      // Asegura un username: del registro por email (pending/perfil) o
      // generado para usuarios de Google, que no pasan por esa pantalla.
      final uname = await _resolveUsername();

      final calories = UserProfile.calculateTMB(
        sex: _sex,
        weight: weight,
        height: height,
        age: age,
        activityLevel: _activityLevel,
        goal: _goal,
      );
      final macros = UserProfile.calculateMacros(
        weight: weight,
        height: height,
        calories: calories,
        goal: _goal,
      );

      final existing = ref.read(userProfileProvider).value;
      final profile = UserProfile(
        uid: user.uid,
        email: user.email,
        displayName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        username: uname,
        sex: _sex,
        currentWeight: weight,
        height: height,
        age: age,
        activityLevel: _activityLevel,
        goal: _goal,
        targetCalories: calories,
        targetProtein: macros.protein,
        targetCarbs: macros.carbs,
        targetFat: macros.fat,
        targetWaterMl: UserProfile.calculateWaterMl(weightKg: weight),
        onboardingCompleted: true,
        acceptedTerms: true,
        acceptedMarketing: existing?.acceptedMarketing ?? false,
        termsAcceptedAt: existing?.termsAcceptedAt ?? DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Username ya reclamado en registro; solo actualizar perfil
      await ref.read(profileRepositoryProvider).saveProfile(profile);
      await ref.read(profileRepositoryProvider).addWeightEntry(
        user.uid,
        weight,
        DateTime.now(),
      );

      // Guarda la rutina dinámica generada (si el usuario la creó).
      if (_generatedDays != null && _generatedDays!.isNotEmpty) {
        await ref
            .read(profileRepositoryProvider)
            .saveAllRoutines(user.uid, _generatedDays!);
        ref.invalidate(routinesProvider);
      }

      ref.read(pendingUsernameProvider.notifier).state = null;
      ref.invalidate(userProfileProvider);

      await ref.read(notificationPreferencesProvider.notifier).update(
        NotificationPreferences(
          masterEnabled: _wantNotifs == true,
          workoutEnabled: _wantNotifs == true,
          mealEnabled: _wantNotifs == true,
          weightEnabled: _wantNotifs == true,
          progressEnabled: _wantNotifs == true,
          streakEnabled: _wantNotifs == true,
          workoutMinutes: _workoutMin,
          mealMinutes: _mealMin,
          weightMinutes: _weightMin,
          weightWeekday: _weightWeekday,
          streakIntervalHours: _streakInterval,
        ),
      );
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('onboarding: no se pudo guardar el perfil: $e');
      if (mounted) {
        final msg = e is FormatException
            ? e.message
            : 'No se pudieron guardar tus datos. Revisa tu conexión e inténtalo de nuevo.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _next() {
    if (_page == 0) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if (_page == 1) {
      if (!_formKey.currentState!.validate()) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if (_page < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _saveAndContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    if (_page > 0)
                      IconButton(
                        tooltip: 'Atrás',
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        ),
                        icon: const Icon(Icons.arrow_back),
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        'Configura tu perfil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: accentOf(context),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar sesión',
                      onPressed: _isLoading ? null : _confirmLogout,
                      icon: const Icon(Icons.logout),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: List.generate(5, (i) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                        decoration: BoxDecoration(
                          color: i <= _page
                              ? primary
                              : Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    IdentityPage(
                      nameController: _nameController,
                      sex: _sex,
                      primary: primary,
                      onSexChanged: (v) => setState(() => _sex = v),
                    ),
                    BodyPage(
                      ageController: _ageController,
                      weightController: _weightController,
                      heightController: _heightController,
                      activityLevel: _activityLevel,
                      primary: primary,
                      onActivityChanged: (v) =>
                          setState(() => _activityLevel = v),
                      onFieldChanged: () => setState(() {}),
                    ),
                    GoalPage(
                      goal: _goal,
                      primary: primary,
                      onGoalChanged: (v) => setState(() => _goal = v),
                      previewCalories: _previewCalories,
                      previewWater: _previewWater,
                      previewMacros: _previewMacros,
                    ),
                    RoutinePage(
                      goal: RoutineGoal.fromLabel(_goal),
                      level: _rLevel,
                      days: _rDays,
                      minutes: _rMinutes,
                      equipment: _rEquipment,
                      generated: _generatedDays,
                      generating: _generatingRoutine,
                      catalogReady: ref.watch(exercisesProvider).hasValue,
                      primary: primary,
                      onLevel: (v) => setState(() {
                        _rLevel = v;
                        _generatedDays = null;
                      }),
                      onDays: (v) => setState(() {
                        _rDays = v;
                        _generatedDays = null;
                      }),
                      onMinutes: (v) => setState(() {
                        _rMinutes = v;
                        _generatedDays = null;
                      }),
                      onEquipment: (name, selected) => setState(() {
                        if (selected) {
                          _rEquipment.add(name);
                        } else {
                          _rEquipment.remove(name);
                        }
                        _generatedDays = null;
                      }),
                      onGenerate: _generateRoutine,
                    ),
                    RemindersPage(
                      wantNotifs: _wantNotifs,
                      workoutMin: _workoutMin,
                      mealMin: _mealMin,
                      weightMin: _weightMin,
                      weightWeekday: _weightWeekday,
                      streakInterval: _streakInterval,
                      primary: primary,
                      onWantNotifs: (v) => setState(() => _wantNotifs = v),
                      onWorkoutMin: (v) => setState(() => _workoutMin = v),
                      onMealMin: (v) => setState(() => _mealMin = v),
                      onWeightMin: (v) => setState(() => _weightMin = v),
                      onWeightWeekday: (v) =>
                          setState(() => _weightWeekday = v),
                      onStreakInterval: (v) =>
                          setState(() => _streakInterval = v),
                      requestPermission: () =>
                          NotificationService.instance.requestPermission(),
                      showTerms: !_termsAlreadyAccepted,
                      acceptedTerms: _acceptedTerms,
                      onAcceptedTerms: (v) =>
                          setState(() => _acceptedTerms = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : Text(
                      _page < 4 ? 'Continuar' : 'Empezar en Balancore',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
