import 'dart:convert';

import 'package:aerotech_app/models/reserva.dart';
import 'package:aerotech_app/models/equipaje.dart';
import 'package:aerotech_app/models/tramo.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:http/http.dart' as http;

class ReservaService extends ApiService {
  /// Crea una reserva por tramo (1 solo ida, 2 ida y vuelta) en una sola transacción.
  Future<Map<String, dynamic>> crearReservas(List<SeleccionTramo> tramos) => guard(() async {
        final response = await http.post(
          Uri.parse('$baseUrl/reservas'),
          headers: headers,
          body: jsonEncode({
            'tramos': [
              for (final t in tramos)
                {
                  'vuelo_id': t.vuelo.id,
                  'asientos': t.asientos,
                  'version': t.vuelo.version,
                  if (t.equipaje.isNotEmpty) 'equipaje': t.equipaje,
                },
            ],
          }),
        );

        if (response.statusCode == 201) {
          return Map<String, dynamic>.from(decode(response));
        }

        throwError(response, 'Error al crear la reserva.');
      });

  Future<TarifasEquipaje> getTarifasEquipaje() => guard(() async {
        final response = await http.get(Uri.parse('$baseUrl/equipaje'), headers: headers);

        if (response.statusCode == 200) {
          return TarifasEquipaje.fromJson(Map<String, dynamic>.from(decode(response)));
        }

        throwError(response, 'Error al cargar las tarifas de equipaje.');
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