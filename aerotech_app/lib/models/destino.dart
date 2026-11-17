/// Destino promocional: aeropuerto con vuelos próximos y su precio más bajo.
class DestinoPromo {
  final int id;
  final String codigo;
  final String ciudad;
  final String pais;
  final double desde;
  final int vuelos;

  const DestinoPromo({
    required this.id,
    required this.codigo,
    required this.ciudad,
    required this.pais,
    required this.desde,
    required this.vuelos,
  });

  factory DestinoPromo.fromJson(Map<String, dynamic> json) {
    return DestinoPromo(
      id: (json['id'] as num).toInt(),
      codigo: json['codigo'] ?? '',
      ciudad: json['ciudad'] ?? '',
      pais: json['pais'] ?? '',
      desde: (json['desde'] as num).toDouble(),
      vuelos: (json['vuelos'] as num?)?.toInt() ?? 0,
    );
  }
}
