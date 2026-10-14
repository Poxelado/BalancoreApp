import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';

/// Franja fina que avisa del estado offline y de los cambios sin subir.
///
/// No ocupa espacio cuando hay conexión y no hay nada pendiente.
class OfflineStatusBanner extends ConsumerWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(isOnlineProvider).value ?? true;
    final pending = ref.watch(pendingUploadsProvider).value ?? 0;
    if (online && pending == 0) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final offline = !online;
    final bg = offline ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = offline ? scheme.onErrorContainer : scheme.onSecondaryContainer;

    final text = offline
        ? (pending > 0
            ? 'Sin conexión · $pending sin subir'
            : 'Sin conexión · se guardará en el dispositivo')
        : (pending == 1
            ? 'Subiendo 1 cambio…'
            : 'Subiendo $pending cambios…');

    return Material(
      color: bg,
      child: InkWell(
        onTap: offline ? null : () => ref.read(offlineSyncProvider).flush(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(
                offline ? Icons.cloud_off_outlined : Icons.cloud_upload_outlined,
                size: 16,
                color: fg,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!offline)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
