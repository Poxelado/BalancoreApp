import 'package:flutter/foundation.dart';

import 'offline_op.dart';
import 'offline_store.dart';

typedef OfflineApplier = Future<void> Function(OfflineOp op);

/// Reenvía las escrituras pendientes cuando vuelve la conexión.
///
/// No conoce Firestore: recibe un [OfflineApplier] que sabe aplicar cada
/// operación, lo que lo hace fácil de testear.
class OfflineSync {
  OfflineSync({
    required OfflineStore store,
    required OfflineApplier apply,
    void Function()? onSynced,
  })  : _store = store,
        _apply = apply,
        _onSynced = onSynced;

  final OfflineStore _store;
  final OfflineApplier _apply;
  final void Function()? _onSynced;
  bool _flushing = false;

  int get pending => _store.length;

  /// Intenta subir toda la cola. Si algo falla (sigue sin red) se detiene y
  /// deja el resto para el próximo intento.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    var synced = 0;
    try {
      await _store.load();
      for (final op in List<OfflineOp>.from(_store.ops)) {
        try {
          await _apply(op);
          await _store.remove(op.dedupeKey);
          synced++;
        } catch (e) {
          debugPrint(
            'OfflineSync: queda pendiente (${op.type.name}): $e',
          );
          break;
        }
      }
    } finally {
      _flushing = false;
    }
    if (synced > 0) _onSynced?.call();
  }
}
