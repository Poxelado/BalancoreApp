/// Tipos de escritura que puede quedar pendiente de subir (cola de salida).
enum OfflineOpType {
  /// Guardar/actualizar una sesión de entrenamiento completa (doc id = session.id).
  workoutSession,

  /// Borrado de una sesión de entrenamiento.
  workoutDelete,

  /// Alta o edición de una comida de un día (idempotente por id de comida).
  mealUpsert,

  /// Borrado de una comida de un día.
  mealRemove,
}

/// Una escritura que se quedó pendiente de subir (cola de salida offline).
///
/// Se guarda serializada en disco y se reenvía cuando vuelve la conexión.
/// [dedupeKey] permite agrupar: al encolar una operación con la misma clave se
/// reemplaza la anterior (p. ej. varias series de la misma sesión o el mismo
/// alimento editado), de modo que la cola no crece sin control.
class OfflineOp {
  const OfflineOp({
    required this.type,
    required this.uid,
    required this.dedupeKey,
    required this.payload,
    required this.createdAt,
  });

  final OfflineOpType type;
  final String uid;
  final String dedupeKey;
  final Map<String, dynamic> payload;
  final String createdAt;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'uid': uid,
        'dedupeKey': dedupeKey,
        'payload': payload,
        'createdAt': createdAt,
      };

  factory OfflineOp.fromJson(Map<String, dynamic> json) {
    return OfflineOp(
      type: OfflineOpType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => OfflineOpType.workoutSession,
      ),
      uid: json['uid']?.toString() ?? '',
      dedupeKey: json['dedupeKey']?.toString() ?? '',
      payload: Map<String, dynamic>.from(
        (json['payload'] as Map?) ?? const <String, dynamic>{},
      ),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}
