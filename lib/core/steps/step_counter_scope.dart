import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'step_counter.dart';

/// Mantiene vivo el podómetro: reengancha el sensor al volver a primer plano
/// y guarda los pasos acumulados al pasar a 2do plano.
class StepCounterScope extends ConsumerStatefulWidget {
  final Widget child;

  const StepCounterScope({super.key, required this.child});

  @override
  ConsumerState<StepCounterScope> createState() => _StepCounterScopeState();
}

class _StepCounterScopeState extends ConsumerState<StepCounterScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fuerza la inicialización del contador (lee preferencias y, si está
    // activo, arranca el sensor) aunque el usuario no abra Ajustes.
    ref.read(stepCounterProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(stepCounterProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      notifier.onResume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      notifier.onPause();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
