/// Modelo de avión precargado. Define cuántas filas (de 6 asientos) tiene el vuelo
/// y cuántas de esas filas son de clase Ejecutiva.
class Avion {
  final int id;
  final String modelo;
  final int filas;
  final int filasEjecutiva;

  const Avion({
    required this.id,
    required this.modelo,
    required this.filas,
    required this.filasEjecutiva,
  });

  factory Avion.fromJson(Map<String, dynamic> json) {
    return Avion(
      id: (json['id'] as num).toInt(),
      modelo: json['modelo'] ?? '',
      filas: (json['filas'] as num).toInt(),
      filasEjecutiva: (json['filas_ejecutiva'] as num).toInt(),
    );
  }

  int get asientos => filas * 6;
  int get asientosEjecutiva => filasEjecutiva * 6;
  int get asientosEconomica => asientos - asientosEjecutiva;

  /// Ej.: "Airbus A320 · 150 asientos"
  String get resumen => '$modelo · $asientos asientos';

  String get detalle {
    final economica = 'Económica: filas ${filasEjecutiva + 1}-$filas ($asientosEconomica asientos)';
    if (filasEjecutiva == 0) return 'Sin clase Ejecutiva. $economica.';
    return 'Ejecutiva: filas 1-$filasEjecutiva ($asientosEjecutiva asientos) · $economica.';
  }

  @override
  bool operator ==(Object other) => other is Avion && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
