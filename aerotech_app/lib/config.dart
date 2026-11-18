import 'dart:async';

import 'package:aerotech_app/models/usuario.dart';

class Config {
  static const String baseUrl = 'https://aerotech-api-iqxa.onrender.com/api';
  static String token = '';
  static Usuario? usuario;

  static bool get sesionActiva => token.isNotEmpty;

  // ---------------------------------------------------------------- expiración automática

  static Timer? _temporizador;
  static DateTime? _vence;

  /// La registra la app (main.dart): lleva al login y avisa al usuario.
  static void Function()? alExpirar;

  /// Programa el cierre automático de la sesión cuando el token venza.
  static void programarExpiracion(Duration duracion) {
    _temporizador?.cancel();
    _vence = DateTime.now().add(duracion);
    if (duracion <= Duration.zero) {
      expirar();
      return;
    }
    _temporizador = Timer(duracion, expirar);
  }

  /// Vuelve a comprobar el vencimiento (por ejemplo al volver a la app tras estar en segundo plano,
  /// cuando el sistema pudo haber detenido el temporizador).
  static void verificarExpiracion() {
    final vence = _vence;
    if (sesionActiva && vence != null && !DateTime.now().isBefore(vence)) expirar();
  }

  static void expirar() {
    if (!sesionActiva) return;
    cerrarSesion();
    alExpirar?.call();
  }

  static void cerrarSesion() {
    _temporizador?.cancel();
    _temporizador = null;
    _vence = null;
    token = '';
    usuario = null;
  }
}
