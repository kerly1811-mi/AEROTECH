import 'package:aerotech_app/models/vuelo.dart';

class AsientoReservado {
  final String asiento;
  final String tipo;
  final double precio;

  AsientoReservado({
    required this.asiento,
    required this.tipo,
    required this.precio,
  });

  factory AsientoReservado.fromJson(Map<String, dynamic> json) {
    return AsientoReservado(
      asiento: json['asiento'] ?? '',
      tipo: json['tipo'] ?? '',
      precio: (json['precio'] as num).toDouble(),
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

  double precio(String asiento) {
    return esVentana(asiento) ? vuelo.precio + recargoVentana : vuelo.precio;
  }
}
