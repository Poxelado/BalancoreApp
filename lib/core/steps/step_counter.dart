import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';

const _kEnabledKey = 'balancore_steps_enabled';
const _kDateKey = 'balancore_steps_date';
const _kBaselineKey = 'balancore_steps_baseline';
const _kTotalKey = 'balancore_steps_total';

/// ~0,04 kcal por paso para una persona de 70 kg, escalado lineal por peso.
const double _kcalPerStepAt70Kg = 0.04;

/// Kcal estimadas por los pasos del día.
int stepCalories(int steps, double weightKg) {
  if (steps <= 0 || weightKg <= 0) return 0;
  return (steps * _kcalPerStepAt70Kg * (weightKg / 70.0)).round();
}

String _todayKey([DateTime? d]) {
  final n = d ?? DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

class StepCounterState {
  /// El usuario activó el contador.
  final bool enabled;

  /// Pasos registrados hoy.
  final int steps;

  /// Ya se leyeron las preferencias.
  final bool ready;

  /// Se pidió permiso y fue rechazado.
  final bool permissionDenied;

  /// Error del sensor (si lo hubo).
  final String? error;

  const StepCounterState({
    this.enabled = false,
    this.steps = 0,
    this.ready = false,
    this.permissionDenied = false,
    this.error,
  });

  StepCounterState copyWith({
    bool? enabled,
    int? steps,
    bool? ready,
    bool? permissionDenied,
    String? error,
    bool clearError = false,
  }) {
    return StepCounterState(
      enabled: enabled ?? this.enabled,
      steps: steps ?? this.steps,
      ready: ready ?? this.ready,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Cuenta los pasos del día con el sensor del teléfono (paquete `pedometer`).
///
/// El sensor entrega un valor acumulado desde el arranque del teléfono; aquí
/// guardamos una "base" al empezar el día y restamos para obtener los pasos de
/// hoy. Mientras la app está cerrada el sensor sigue contando a nivel de
/// hardware, así que al reabrir se recuperan los pasos del 2do plano (salvo
/// reinicio del teléfono o el primer arranque de cada día).
class StepCounterNotifier extends StateNotifier<StepCounterState> {
  StepCounterNotifier(this._ref) : super(const StepCounterState()) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<StepCount>? _sub;
  Timer? _persistTimer;
  int _lastPersisted = -1;

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_kEnabledKey) ?? false;
    final steps = await _loadTodaySteps(prefs);
    state = state.copyWith(enabled: enabled, steps: steps, ready: true);
    if (enabled) await _start();
  }

  Future<int> _loadTodaySteps(SharedPreferences prefs) async {
    if (prefs.getString(_kDateKey) != _todayKey()) return 0;
    return prefs.getInt(_kTotalKey) ?? 0;
  }

  /// Pide permiso y activa el contador. Devuelve true si quedó activo.
  Future<bool> enable() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      state = state.copyWith(permissionDenied: true);
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, true);
    state = state.copyWith(enabled: true, permissionDenied: false, error: null);
    await _start();
    return true;
  }

  Future<void> disable() async {
    await _persistNow();
    await _sub?.cancel();
    _sub = null;
    _persistTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, false);
    state = state.copyWith(enabled: false);
  }

  Future<void> _start() async {
    await _sub?.cancel();
    state = state.copyWith(clearError: true);
    try {
      _sub = Pedometer.stepCountStream.listen(
        _onStep,
        onError: (Object e) => state = state.copyWith(error: '$e'),
        cancelOnError: false,
      );
    } catch (e) {
      state = state.copyWith(error: '$e');
    }
  }

  Future<void> _onStep(StepCount event) async {
    final prefs = await SharedPreferences.getInstance();
    await _applyCumulative(prefs, event.steps);
  }

  Future<void> _applyCumulative(
      SharedPreferences prefs, int cumulative) async {
    final today = _todayKey();
    final storedDate = prefs.getString(_kDateKey);
    if (storedDate != today) {
      // Nuevo día (o primer arranque): reinicia la base de conteo.
      await prefs.setString(_kDateKey, today);
      await prefs.setInt(_kBaselineKey, cumulative);
      await prefs.setInt(_kTotalKey, 0);
      if (state.steps != 0) state = state.copyWith(steps: 0);
      return;
    }
    final baseline = prefs.getInt(_kBaselineKey) ?? cumulative;
    final total = cumulative - baseline;
    final safe = total < 0 ? 0 : total;
    if (safe == state.steps) return;
    state = state.copyWith(steps: safe);
    await prefs.setInt(_kTotalKey, safe);
    _schedulePersist();
  }

  /// Fuerza una lectura del sensor y guarda los pasos de hoy. Funciona también
  /// con el contador apagado (lectura puntual del día). Devuelve los pasos del
  /// día, o null si el sensor no está disponible.
  Future<int?> recollect() async {
    final wasEnabled = state.enabled;
    await _start();
    // Da tiempo a que el sensor emita el valor acumulado actual.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!wasEnabled) {
      await _sub?.cancel();
      _sub = null;
    }
    if (state.error != null) return null;
    await _persistNow(force: true);
    return state.steps;
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(minutes: 2), _persistNow);
  }

  Future<void> _persistNow({bool force = false}) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    if (!force && state.steps == _lastPersisted) return;
    _lastPersisted = state.steps;
    try {
      await _ref
          .read(profileRepositoryProvider)
          .setTodaySteps(user.uid, state.steps);
      invalidateProgressData(_ref);
    } catch (_) {
      // Silencioso: los pasos se reintentan en el próximo guardado.
    }
  }

  /// Al volver del 2do plano: reengancha el stream y guarda lo pendiente.
  Future<void> onResume() async {
    if (!state.enabled) return;
    await _start();
  }

  /// Al pasar a 2do plano: guarda los pasos acumulados.
  Future<void> onPause() async {
    if (!state.enabled) return;
    await _persistNow();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _persistTimer?.cancel();
    super.dispose();
  }
}

final stepCounterProvider =
    StateNotifierProvider<StepCounterNotifier, StepCounterState>(
  (ref) => StepCounterNotifier(ref),
);
