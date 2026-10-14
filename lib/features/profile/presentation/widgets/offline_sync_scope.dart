import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';

/// Arranca la cola offline y la sincroniza al recuperar la conexión.
///
/// Envuelve la app entera; no pinta nada, solo escucha la red y reenvía lo
/// pendiente (además de un reintento periódico por si la red "miente").
class OfflineSyncScope extends ConsumerStatefulWidget {
  const OfflineSyncScope({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OfflineSyncScope> createState() => _OfflineSyncScopeState();
}

class _OfflineSyncScopeState extends ConsumerState<OfflineSyncScope> {
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    _retry = Timer.periodic(const Duration(seconds: 30), (_) {
      if (ref.read(offlineStoreProvider).length > 0) {
        ref.read(offlineSyncProvider).flush();
      }
    });
  }

  void _start() async {
    if (!mounted) return;
    final store = ref.read(offlineStoreProvider);
    await store.load();
    if (!mounted) return;
    // Refresca la UI con lo que hubiera quedado pendiente en la cola.
    invalidateProgressData(ref);
    if (ref.read(isOnlineProvider).value != false) {
      ref.read(offlineSyncProvider).flush();
    }
    ref.listenManual(isOnlineProvider, (prev, next) {
      if (next.value == true) ref.read(offlineSyncProvider).flush();
    });
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
