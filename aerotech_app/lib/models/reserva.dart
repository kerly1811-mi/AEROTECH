import 'package:aerotech_app/models/asiento.dart';

class Reserva {
  final int id;
  final int usuarioId;
  final String cliente;
  final int vueloId;
  final String origen;
  final String destino;
  final String fechaVuelo;
  final String horaSalida;
  final int cantidadAsientos;
  final double total;
  final String estado;
  final String fechaReserva;
  final int version;
  final List<AsientoReservado> asientos;

  Reserva({
    required this.id,
    required this.usuarioId,
    required this.cliente,
    required this.vueloId,
    required this.origen,
    required this.destino,
    required this.fechaVuelo,
    required this.horaSalida,
    required this.cantidadAsientos,
    required this.total,
    required this.estado,
    required this.fechaReserva,
    this.version = 1,
    this.asientos = const [],
  });

  factory Reserva.fromJson(Map<String, dynamic> json) {
    return Reserva(
      id: (json['id'] as num).toInt(),
      usuarioId: (json['usuario_id'] as num).toInt(),
      cliente: json['cliente'] ?? '',
      vueloId: (json['vuelo_id'] as num).toInt(),
      origen: json['origen'] ?? '',
      destino: json['destino'] ?? '',
      fechaVuelo: json['fecha_vuelo'] ?? '',
      horaSalida: json['hora_salida'].toString().substring(0, 5),
      cantidadAsientos: (json['cantidad_asientos'] as num).toInt(),
      total: (json['total'] as num).toDouble(),
      estado: json['estado'] ?? '',
      fechaReserva: json['fecha_reserva'].toString().substring(0, 10),
      version: json['version'] != null ? (json['version'] as num).toInt() : 1,
      asientos: (json['asientos'] as List? ?? [])
          .map((item) => AsientoReservado.fromJson(item))
          .toList(),
    );
  }

  bool get confirmada => estado == 'confirmada';

  String get textoAsientos {
    if (asientos.isEmpty) return '$cantidadAsientos pasajero(s)';
    return asientos.map((a) => a.asiento).join(', ');
  }
}
