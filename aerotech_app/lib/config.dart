import 'package:aerotech_app/models/usuario.dart';

class Config {
  static const String baseUrl = 'https://aerotech-api-iqxa.onrender.com/api';
  static String token = '';
  static Usuario? usuario;

  static bool get sesionActiva => token.isNotEmpty;

  static void cerrarSesion() {
    token = '';
    usuario = null;
  }
}