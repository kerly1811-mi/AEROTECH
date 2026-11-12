import 'dart:convert';

import 'package:aerotech_app/models/aeropuerto.dart';
import 'package:aerotech_app/models/asiento.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:http/http.dart' as http;

class VueloService extends ApiService {
  Future<List<Aeropuerto>> getAeropuertos() => guard(() async {
        final response = await http.get(
          Uri.parse('$baseUrl/aeropuertos'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          final List datos = decode(response)['aeropuertos'];
          return datos.map((item) => Aeropuerto.fromJson(item)).toList();
        }

        throwError(response, 'Error al cargar los aeropuertos.');
      });

  Future<List<Vuelo>> getVuelos({int? origenId, int? destinoId, String? fecha}) =>
      guard(() async {
        final params = <String, String>{
          if (origenId != null) 'origen_id': '$origenId',
          if (destinoId != null) 'destino_id': '$destinoId',
          if (fecha != null && fecha.isNotEmpty) 'fecha': fecha,
        };
        final uri = Uri.parse('$baseUrl/vuelos')
            .replace(queryParameters: params.isEmpty ? null : params);
        final response = await http.get(uri, headers: headers);

        if (response.statusCode == 200) {
          final List datos = decode(response)['vuelos'];
          return datos.map((item) => Vuelo.fromJson(item)).toList();
        }

        throwError(response, 'Error al cargar los vuelos.');
      });

  Future<MapaAsientos> getAsientos(int vueloId) => guard(() async {
        final response = await http.get(
          Uri.parse('$baseUrl/vuelos/$vueloId/asientos'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          return MapaAsientos.fromJson(decode(response));
        }

        throwError(response, 'Error al cargar el mapa de asientos.');
      });

  Future<Vuelo> createVuelo(Vuelo vuelo) => guard(() async {
        final response = await http.post(
          Uri.parse('$baseUrl/vuelos'),
          headers: headers,
          body: jsonEncode(vuelo.toJson()),
        );

        if (response.statusCode == 201) {
          return Vuelo.fromJson(decode(response)['vuelo']);
        }

        throwError(response, 'Error al crear el vuelo.');
      });

  Future<Vuelo> updateVuelo(Vuelo vuelo) => guard(() async {
        final response = await http.put(
          Uri.parse('$baseUrl/vuelos/${vuelo.id}'),
          headers: headers,
          body: jsonEncode(vuelo.toJson()),
        );

        if (response.statusCode == 200) {
          return Vuelo.fromJson(decode(response)['vuelo']);
        }

        throwError(response, 'Error al actualizar el vuelo.');
      });

  Future<void> deleteVuelo(int id) => guard(() async {
        final response = await http.delete(
          Uri.parse('$baseUrl/vuelos/$id'),
          headers: headers,
        );

        if (response.statusCode == 200) return;

        throwError(response, 'Error al eliminar el vuelo.');
      });
}