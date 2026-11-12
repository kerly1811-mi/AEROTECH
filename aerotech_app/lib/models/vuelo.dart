class Vuelo {
  final int id;
  final String origen;
  final String destino;
  final int origenId;
  final int destinoId;
  final String origenCodigo;
  final String destinoCodigo;
  final String fecha;
  final String horaSalida;
  final String horaLlegada;
  final double precio;
  final int filas;
  final int asientosDisponibles;
  final int version;

  Vuelo({
    required this.id,
    required this.origen,
    required this.destino,
    this.origenId = 0,
    this.destinoId = 0,
    this.origenCodigo = '',
    this.destinoCodigo = '',
    required this.fecha,
    required this.horaSalida,
    required this.horaLlegada,
    required this.precio,
    required this.filas,
    required this.asientosDisponibles,
    this.version = 1,
  });

  int get capacidad => filas * 6;

  factory Vuelo.fromJson(Map<String, dynamic> json) {
    return Vuelo(
      id: (json['id'] as num).toInt(),
      origen: json['origen'] ?? '',
      destino: json['destino'] ?? '',
      origenId: (json['origen_id'] as num?)?.toInt() ?? 0,
      destinoId: (json['destino_id'] as num?)?.toInt() ?? 0,
      origenCodigo: json['origen_codigo'] ?? '',
      destinoCodigo: json['destino_codigo'] ?? '',
      fecha: json['fecha'] ?? '',
      horaSalida: json['hora_salida'].toString().substring(0, 5),
      horaLlegada: json['hora_llegada'].toString().substring(0, 5),
      precio: (json['precio'] as num).toDouble(),
      filas: json['filas'] != null ? (json['filas'] as num).toInt() : 20,
      asientosDisponibles: (json['asientos_disponibles'] as num).toInt(),
      version: json['version'] != null ? (json['version'] as num).toInt() : 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'origen_id': origenId,
      'destino_id': destinoId,
      'fecha': fecha,
      'hora_salida': horaSalida,
      'hora_llegada': horaLlegada,
      'precio': precio,
      'filas': filas,
      'version': version,
    };
  }

  Vuelo copyWith({
    int? id,
    String? origen,
    String? destino,
    String? fecha,
    String? horaSalida,
    String? horaLlegada,
    double? precio,
    int? filas,
    int? asientosDisponibles,
    int? version,
  }) {
    return Vuelo(
      id: id ?? this.id,
      origen: origen ?? this.origen,
      destino: destino ?? this.destino,
      fecha: fecha ?? this.fecha,
      horaSalida: horaSalida ?? this.horaSalida,
      horaLlegada: horaLlegada ?? this.horaLlegada,
      precio: precio ?? this.precio,
      filas: filas ?? this.filas,
      asientosDisponibles: asientosDisponibles ?? this.asientosDisponibles,
      version: version ?? this.version,
    );
  }
}
