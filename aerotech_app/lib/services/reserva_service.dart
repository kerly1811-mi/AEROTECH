import 'dart:convert';

import 'package:aerotech_app/models/reserva.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:http/http.dart' as http;

class ReservaService extends ApiService {
  Future<Map<String, dynamic>> crearReserva(int vueloId, List<String> asientos, int version) =>
      guard(() async {
        final response = await http.post(
          Uri.parse('$baseUrl/reservas'),
          headers: headers,
          body: jsonEncode({
            'vuelo_id': vueloId,
            'asientos': asientos,
            'version': version,
          }),
        );

        if (response.statusCode == 201) {
          return Map<String, dynamic>.from(decode(response));
        }

        throwError(response, 'Error al crear la reserva.');
      });

  Future<List<Reserva>> getMisReservas() => _listar('$baseUrl/reservas/mis-reservas');

  Future<List<Reserva>> getTodasReservas() => _listar('$baseUrl/reservas');

  Future<List<Reserva>> _listar(String url) => guard(() async {
        final response = await http.get(Uri.parse(url), headers: headers);

        if (response.statusCode == 200) {
          final List datos = decode(response)['reservas'];
          return datos.map((item) => Reserva.fromJson(item)).toList();
        }

        throwError(response, 'Error al cargar las reservas.');
      });

  Future<void> cancelarReserva(Reserva reserva) => guard(() async {
        final response = await http.put(
          Uri.parse('$baseUrl/reservas/${reserva.id}/cancelar'),
          headers: headers,
          body: jsonEncode({'version': reserva.version}),
        );

        if (response.statusCode == 200) return;

        throwError(response, 'Error al cancelar la reserva.');
      });

  Future<String> getComprobante(int reservaId) => guard(() async {
        final response = await http.get(
          Uri.parse('$baseUrl/reservas/$reservaId/comprobante'),
          headers: headers,
        );

        if (response.statusCode == 200) {
          return utf8.decode(response.bodyBytes);
        }

        throwError(response, 'Error al generar el comprobante.');
      });
}