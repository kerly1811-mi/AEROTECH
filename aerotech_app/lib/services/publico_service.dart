import 'package:aerotech_app/models/destino.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:http/http.dart' as http;

/// Información de la portada: no requiere iniciar sesión.
class PublicoService extends ApiService {
  Future<List<DestinoPromo>> getDestinos() => guard(() async {
        final response = await http.get(Uri.parse('$baseUrl/publico/destinos'), headers: headers);

        if (response.statusCode == 200) {
          final List datos = decode(response)['destinos'];
          return datos.map((item) => DestinoPromo.fromJson(item)).toList();
        }

        throwError(response, 'Error al cargar los destinos.');
      });

  Future<List<Vuelo>> getVuelosHoy() => guard(() async {
        final response = await http.get(Uri.parse('$baseUrl/publico/vuelos-hoy'), headers: headers);

        if (response.statusCode == 200) {
          final List datos = decode(response)['vuelos'];
          return datos.map((item) => Vuelo.fromJson(item)).toList();
        }

        throwError(response, 'Error al cargar los vuelos de hoy.');
      });
}
