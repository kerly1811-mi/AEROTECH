import 'package:aerotech_app/models/clase.dart';

/// Tarifas del equipaje de bodega adicional (las define el servidor).
class TarifasEquipaje {
  final double primerExtra;
  final double segundoExtra;
  final int maximoExtra;
  final int incluidasEconomica;
  final int incluidasEjecutiva;
  final int manoKg;
  final int bodegaKg;

  const TarifasEquipaje({
    required this.primerExtra,
    required this.segundoExtra,
    required this.maximoExtra,
    required this.incluidasEconomica,
    required this.incluidasEjecutiva,
    this.manoKg = 10,
    this.bodegaKg = 23,
  });

  factory TarifasEquipaje.fromJson(Map<String, dynamic> json) {
    final incluidas = Map<String, dynamic>.from(json['incluidas'] ?? {});
    return TarifasEquipaje(
      primerExtra: (json['primer_extra'] as num).toDouble(),
      segundoExtra: (json['segundo_extra'] as num).toDouble(),
      maximoExtra: (json['maximo_extra'] as num?)?.toInt() ?? 2,
      incluidasEconomica: (incluidas['economica'] as num?)?.toInt() ?? 0,
      incluidasEjecutiva: (incluidas['ejecutiva'] as num?)?.toInt() ?? 2,
      manoKg: (json['mano_kg'] as num?)?.toInt() ?? 10,
      bodegaKg: (json['bodega_kg'] as num?)?.toInt() ?? 23,
    );
  }

  int incluidas(Clase clase) => clase == Clase.ejecutiva ? incluidasEjecutiva : incluidasEconomica;

  /// Costo de [maletas] maletas de bodega adicionales de un pasajero.
  double costo(int maletas) {
    if (maletas <= 0) return 0;
    if (maletas == 1) return primerExtra;
    return primerExtra + segundoExtra;
  }
}
