import 'package:aerotech_app/models/aeropuerto.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/utils/fechas.dart';

/// Texto en el que se busca un vuelo (sin tildes ni mayúsculas).
String _pajar(Vuelo v) {
  return Aeropuerto.normalizar([
    '#${v.id}',
    v.origen,
    v.destino,
    v.origenCodigo,
    v.destinoCodigo,
    v.origenPais,
    v.destinoPais,
    v.fecha,
    fechaLarga(v.fecha),
    v.horaSalida,
    v.horaLlegada,
    v.precio.toStringAsFixed(2),
  ].join(' '));
}

/// Todas las palabras de [consulta] deben aparecer (ciudad, código, país, fecha, hora, precio o #id).
bool coincideBusqueda(Vuelo v, String consulta) {
  final palabras = Aeropuerto.normalizar(consulta.trim()).split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (palabras.isEmpty) return true;
  final pajar = _pajar(v);
  return palabras.every(pajar.contains);
}
