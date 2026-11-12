import 'package:aerotech_app/models/clase.dart';
import 'package:aerotech_app/models/vuelo.dart';

class AsientoReservado {
  final String asiento;
  final String tipo;
  final String clase;
  final double precio;
  final int equipajeExtra;
  final double precioEquipaje;

  AsientoReservado({
    required this.asiento,
    required this.tipo,
    this.clase = '',
    required this.precio,
    this.equipajeExtra = 0,
    this.precioEquipaje = 0,
  });

  factory AsientoReservado.fromJson(Map<String, dynamic> json) {
    return AsientoReservado(
      asiento: json['asiento'] ?? '',
      tipo: json['tipo'] ?? '',
      clase: json['clase'] ?? '',
      precio: (json['precio'] as num).toDouble(),
      equipajeExtra: (json['equipaje_extra'] as num?)?.toInt() ?? 0,
      precioEquipaje: (json['precio_equipaje'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MapaAsientos {
  final Vuelo vuelo;
  final int filas;
  final List<String> columnas;
  final Map<String, String> tipos;
  final double recargoVentana;
  final Set<String> ocupados;

  MapaAsientos({
    required this.vuelo,
    required this.filas,
    required this.columnas,
    required this.tipos,
    required this.recargoVentana,
    required this.ocupados,
  });

  factory MapaAsientos.fromJson(Map<String, dynamic> json) {
    return MapaAsientos(
      vuelo: Vuelo.fromJson(json['vuelo']),
      filas: (json['filas'] as num).toInt(),
      columnas: List<String>.from(json['columnas'] ?? const ['A', 'B', 'C', 'D', 'E', 'F']),
      tipos: Map<String, String>.from(json['tipos'] ?? {}),
      recargoVentana: (json['recargo_ventana'] as num? ?? 0).toDouble(),
      ocupados: Set<String>.from(json['ocupados'] ?? []),
    );
  }

  String tipo(String asiento) => tipos[asiento.substring(asiento.length - 1)] ?? 'pasillo';

  bool esVentana(String asiento) => tipo(asiento) == 'ventana';

  bool ocupado(String asiento) => ocupados.contains(asiento);

  int fila(String asiento) => int.parse(asiento.substring(0, asiento.length - 1));

  Clase clase(String asiento) => vuelo.claseDeFila(fila(asiento));

  double precio(String asiento) {
    final base = vuelo.precioClase(clase(asiento));
    return esVentana(asiento) ? base + recargoVentana : base;
  }
}
