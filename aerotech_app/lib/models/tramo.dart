import 'package:aerotech_app/models/clase.dart';
import 'package:aerotech_app/models/vuelo.dart';

/// Un vuelo con la clase elegida (un tramo del viaje).
class TramoViaje {
  final Vuelo vuelo;
  final Clase clase;

  const TramoViaje(this.vuelo, this.clase);

  double get tarifa => vuelo.precioClase(clase);
}

/// Asientos elegidos para un tramo, ya con la versión del vuelo leída del mapa.
class SeleccionTramo {
  final Vuelo vuelo;
  final Clase clase;
  final List<String> asientos;
  final double subtotal;

  /// Maletas extra por asiento (solo los asientos con al menos una).
  final Map<String, int> equipaje;
  final double costoEquipaje;

  const SeleccionTramo({
    required this.vuelo,
    required this.clase,
    required this.asientos,
    required this.subtotal,
    this.equipaje = const {},
    this.costoEquipaje = 0,
  });

  double get total => subtotal + costoEquipaje;
}
