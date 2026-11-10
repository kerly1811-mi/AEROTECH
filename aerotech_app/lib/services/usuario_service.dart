import 'dart:convert';

import 'package:aerotech_app/models/usuario.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:http/http.dart' as http;

class UsuarioService extends ApiService {
  Future<List<Usuario>> getUsuarios() => guard(() async {
        final response = await http.get(Uri.parse('$baseUrl/usuarios'), headers: headers);

        if (response.statusCode == 200) {
          final List datos = decode(response)['usuarios'];
          return datos.map((item) => Usuario.fromJson(item)).toList();
        }

        throwError(response, 'Error al cargar los usuarios.');
      });

  Future<String> cambiarEstado(int usuarioId, bool activo) => guard(() async {
        final response = await http.put(
          Uri.parse('$baseUrl/usuarios/$usuarioId/estado'),
          headers: headers,
          body: jsonEncode({'activo': activo}),
        );

        if (response.statusCode == 200) {
          return decode(response)['mensaje'].toString();
        }

        throwError(response, 'Error al cambiar el estado del usuario.');
      });
}
