import 'dart:convert';

import 'package:aerotech_app/config.dart';
import 'package:aerotech_app/models/usuario.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:http/http.dart' as http;

class AuthService extends ApiService {
  Future<Usuario> login(String correo, String password) => guard(() async {
        Config.cerrarSesion();
        final response = await http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: headers,
          body: jsonEncode({'correo': correo, 'password': password}),
        );

        if (response.statusCode == 200) {
          final body = decode(response);
          Config.token = body['token'];
          Config.usuario = Usuario.fromJson(body['usuario']);
          return Config.usuario!;
        }

        throwError(response, 'Error al iniciar sesión.');
      });

  Future<String> registrar(String nombre, String correo, String password) =>
      guard(() async {
        final response = await http.post(
          Uri.parse('$baseUrl/usuarios/registro'),
          headers: headers,
          body: jsonEncode({
            'nombre': nombre,
            'correo': correo,
            'password': password,
          }),
        );

        if (response.statusCode == 201) {
          return decode(response)['mensaje'].toString();
        }

        throwError(response, 'Error al registrar el usuario.');
      });

  Future<void> logout() async {
    try {
      await guard(() => http.post(Uri.parse('$baseUrl/auth/logout'), headers: headers));
    } catch (_) {
    } finally {
      Config.cerrarSesion();
    }
  }
}