import 'package:aerotech_app/models/clase.dart';

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
  final int filasEjecutiva;
  final double precioEjecutiva;
  final int ocupadosEjecutiva;
  final double? origenLat;
  final double? origenLon;
  final double? destinoLat;
  final double? destinoLon;
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
    this.filasEjecutiva = 0,
    this.precioEjecutiva = 0,
    this.ocupadosEjecutiva = 0,
    this.origenLat,
    this.origenLon,
    this.destinoLat,
    this.destinoLon,
    this.version = 1,
  });

  int get capacidad => filas * 6;

  bool get tieneEjecutiva => filasEjecutiva > 0;

  bool get tieneCoordenadas =>
      origenLat != null && origenLon != null && destinoLat != null && destinoLon != null;

  int get disponiblesEjecutiva {
    final libres = filasEjecutiva * 6 - ocupadosEjecutiva;
    return libres < 0 ? 0 : libres;
  }

  int get disponiblesEconomica {
    final libres = asientosDisponibles - disponiblesEjecutiva;
    return libres < 0 ? 0 : libres;
  }

  int disponibles(Clase clase) =>
      clase == Clase.ejecutiva ? disponiblesEjecutiva : disponiblesEconomica;

  double precioClase(Clase clase) => clase == Clase.ejecutiva ? precioEjecutiva : precio;

  Clase claseDeFila(int fila) => fila <= filasEjecutiva ? Clase.ejecutiva : Clase.economica;

  /// Duración del vuelo, ej. "1h 05m".
  String get duracion {
    int minutos(String hora) {
      final p = hora.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    var total = minutos(horaLlegada) - minutos(horaSalida);
    if (total <= 0) total += 24 * 60;
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  /// Ej.: "Quito (UIO)"
  String get origenEtiqueta => origenCodigo.isEmpty ? origen : '$origen ($origenCodigo)';
  String get destinoEtiqueta => destinoCodigo.isEmpty ? destino : '$destino ($destinoCodigo)';

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
      filasEjecutiva: (json['filas_ejecutiva'] as num?)?.toInt() ?? 0,
      precioEjecutiva: (json['precio_ejecutiva'] as num?)?.toDouble() ?? 0,
      ocupadosEjecutiva: (json['ocupados_ejecutiva'] as num?)?.toInt() ?? 0,
      origenLat: (json['origen_latitud'] as num?)?.toDouble(),
      origenLon: (json['origen_longitud'] as num?)?.toDouble(),
      destinoLat: (json['destino_latitud'] as num?)?.toDouble(),
      destinoLon: (json['destino_longitud'] as num?)?.toDouble(),
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
      'filas_ejecutiva': filasEjecutiva,
      'precio_ejecutiva': precioEjecutiva,
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
    int? filasEjecutiva,
    double? precioEjecutiva,
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
      filasEjecutiva: filasEjecutiva ?? this.filasEjecutiva,
      precioEjecutiva: precioEjecutiva ?? this.precioEjecutiva,
      ocupadosEjecutiva: ocupadosEjecutiva,
      version: version ?? this.version,
    );
  }
}
