import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_op.dart';

/// Cola de escrituras pendientes de subir, persistida con `shared_preferences`.
///
/// Mantiene una copia en memoria para consultarla de forma síncrona (para el
/// overlay optimista y el indicador) y la guarda en disco en cada cambio para
/// que sobreviva al cierre de la app.
class OfflineStore extends ChangeNotifier {
  OfflineStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const _prefsKey = 'offline_queue_v1';

  SharedPreferences? _prefs;
  final List<OfflineOp> _ops = [];
  final StreamController<void> _changes =
      StreamController<void>.broadcast();
  bool _loaded = false;

  List<OfflineOp> get ops => List.unmodifiable(_ops);
  int get length => _ops.length;
  bool get isLoaded => _loaded;

  /// Emite cada vez que cambia la cola (alta, baja o reemplazo).
  Stream<void> get changes => _changes.stream;

  Future<SharedPreferences> _instance() async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Carga la cola guardada. Idempotente.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final prefs = await _instance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _ops
          ..clear()
          ..addAll(
            list.map(
              (e) => OfflineOp.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            ),
          );
      }
    } catch (e) {
      debugPrint('OfflineStore: no se pudo cargar la cola: $e');
    }
    _loaded = true;
    _notify();
  }

  /// Encola [op]; si ya había una con la misma [OfflineOp.dedupeKey], la
  /// reemplaza (la escritura más reciente gana).
  Future<void> put(OfflineOp op) async {
    await load();
    _ops.removeWhere((o) => o.dedupeKey == op.dedupeKey);
    _ops.add(op);
    await _persist();
    _notify();
  }

  /// Quita de la cola la operación con esa clave (ya se subió).
  Future<void> remove(String dedupeKey) async {
    await load();
    final before = _ops.length;
    _ops.removeWhere((o) => o.dedupeKey == dedupeKey);
    if (_ops.length == before) return;
    await _persist();
    _notify();
  }

  Future<void> clear() async {
    await load();
    if (_ops.isEmpty) return;
    _ops.clear();
    await _persist();
    _notify();
  }

  Future<void> _persist() async {
    try {
      final prefs = await _instance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_ops.map((o) => o.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('OfflineStore: no se pudo guardar la cola: $e');
    }
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
    notifyListeners();
  }

  @override
  void dispose() {
    _changes.close();
    super.dispose();
  }
}
