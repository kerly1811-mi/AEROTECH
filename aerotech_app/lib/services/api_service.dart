import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aerotech_app/config.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ServerUnavailableException extends ApiException {
  ServerUnavailableException([
    super.message = 'No se pudo conectar con el servidor. '
        'Verifique su conexión a internet.',
  ]);
}

class SessionExpiredException extends ApiException {
  SessionExpiredException([
    super.message = 'Su sesión expiró. Inicie sesión nuevamente.',
  ]);
}

class ForbiddenException extends ApiException {
  ForbiddenException([
    super.message = 'No tiene permiso para realizar esta acción.',
  ]);
}

class ConflictException extends ApiException {
  final Map<String, dynamic>? current;
  ConflictException(super.message, this.current);
}

class ApiService {
  final String baseUrl = Config.baseUrl;

  static const _timeout = Duration(seconds: 60);

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (Config.sesionActiva) 'Authorization': 'Bearer ${Config.token}',
      };

  Future<T> guard<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw ServerUnavailableException(
        'El servidor tardó demasiado en responder. '
        'Por favor, inténtelo de nuevo.',
      );
    } on SocketException {
      throw ServerUnavailableException();
    } on http.ClientException {
      throw ServerUnavailableException();
    } on HandshakeException {
      throw ServerUnavailableException(
        'No se pudo establecer una conexión segura con el servidor.',
      );
    }
  }

  dynamic decode(http.Response response) {
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Never throwError(http.Response response, String fallback) {
    final message = extractMessage(response, fallback);

    switch (response.statusCode) {
      case 401:
        if (Config.sesionActiva) {
          Config.cerrarSesion();
          throw SessionExpiredException();
        }
        throw ApiException(message);
      case 403:
        throw ForbiddenException(message);
      case 409:
        Map<String, dynamic>? current;
        try {
          final body = decode(response);
          current = body['vuelo_actual'] ?? body['reserva_actual'];
        } catch (_) {}
        throw ConflictException(message, current);
      default:
        throw ApiException(message);
    }
  }

  String extractMessage(http.Response response, String fallback) {
    try {
      final body = decode(response);
      if (body is Map) {
        if (body['errores'] is List) {
          return (body['errores'] as List)
              .map((e) => '${e['campo']}: ${e['error']}')
              .join('\n');
        }
        if (body['mensaje'] != null) return body['mensaje'].toString();
        if (body['error'] != null) return body['error'].toString();
      }
    } catch (_) {}
    return fallback;
  }
}