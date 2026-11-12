import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:aerotech_app/utils/mapa_mundi.dart';
import 'package:flutter/material.dart';

/// Mapa de puntos con un avión que recorre la ruta del origen al destino.
/// Se acerca automáticamente cuando el vuelo es corto.
class RutaMundial extends StatefulWidget {
  final double origenLat;
  final double origenLon;
  final double destinoLat;
  final double destinoLon;
  final String origenCodigo;
  final String destinoCodigo;
  final bool animar;

  const RutaMundial({
    super.key,
    required this.origenLat,
    required this.origenLon,
    required this.destinoLat,
    required this.destinoLon,
    required this.origenCodigo,
    required this.destinoCodigo,
    this.animar = true,
  });

  @override
  State<RutaMundial> createState() => _RutaMundialState();
}

class _RutaMundialState extends State<RutaMundial> with SingleTickerProviderStateMixin {
  static const double aspecto = 2.4;

  late final AnimationController _controller;
  late _Vista _vista;

  @override
  void initState() {
    super.initState();
    _vista = _Vista.para(widget);
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 7));
    if (widget.animar) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant RutaMundial oldWidget) {
    super.didUpdateWidget(oldWidget);
    _vista = _Vista.para(widget);
    if (widget.animar && !_controller.isAnimating) _controller.repeat();
    if (!widget.animar) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: aspecto,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: CustomPaint(painter: _MapaPainter(_vista))),
            CustomPaint(painter: _RutaPainter(widget, _vista, _controller)),
          ],
        ),
      ),
    );
  }
}

class _Vista {
  final double lonMin;
  final double lonMax;
  final double latMin;
  final double latMax;

  const _Vista(this.lonMin, this.lonMax, this.latMin, this.latMax);

  double get ancho => lonMax - lonMin;
  double get alto => latMax - latMin;

  factory _Vista.para(RutaMundial w) {
    const aspecto = _RutaMundialState.aspecto;
    final dLon = (w.destinoLon - w.origenLon).abs();
    final dLat = (w.destinoLat - w.origenLat).abs();

    var ancho = math.max(100.0, math.max(dLon * 1.7, dLat * 1.7 * aspecto));
    if (ancho > 200) ancho = 360;
    final alto = ancho / aspecto;

    var cLon = (w.origenLon + w.destinoLon) / 2;
    var cLat = (w.origenLat + w.destinoLat) / 2;
    if (ancho >= 360) {
      cLon = 0;
      cLat = 10;
    }

    var lonMin = cLon - ancho / 2;
    if (lonMin < -180) lonMin = -180;
    if (lonMin + ancho > 180) lonMin = 180 - ancho;
    var latMin = cLat - alto / 2;
    if (latMin < -85) latMin = -85;
    if (latMin + alto > 85) latMin = 85 - alto;

    return _Vista(lonMin, lonMin + ancho, latMin, latMin + alto);
  }

  Offset proyectar(double lat, double lon, Size s) {
    return Offset(
      (lon - lonMin) / ancho * s.width,
      (latMin + alto - lat) / alto * s.height,
    );
  }
}

class _MapaPainter extends CustomPainter {
  final _Vista vista;

  _MapaPainter(this.vista);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B2A5B), Color(0xFF123F85)],
        ).createShader(rect),
    );

    // Cuadrícula
    final rejilla = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    const divisiones = 18;
    for (var i = 1; i < divisiones; i++) {
      final x = size.width * i / divisiones;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), rejilla);
    }
    final filas = (divisiones / _RutaMundialState.aspecto).round();
    for (var i = 1; i < filas; i++) {
      final y = size.height * i / filas;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rejilla);
    }

    // Continentes como puntos
    const columnas = 90;
    final paso = vista.ancho / columnas;
    final puntos = <Offset>[];
    for (var lat = vista.latMin + vista.alto; lat >= vista.latMin; lat -= paso) {
      for (var lon = vista.lonMin; lon <= vista.lonMax; lon += paso) {
        if (esTierra(lat, lon)) puntos.add(vista.proyectar(lat, lon, size));
      }
    }
    canvas.drawPoints(
      PointMode.points,
      puntos,
      Paint()
        ..color = const Color(0xFF7FA8DC).withValues(alpha: 0.85)
        ..strokeWidth = size.width / columnas * 0.62
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MapaPainter old) =>
      old.vista.lonMin != vista.lonMin ||
      old.vista.latMin != vista.latMin ||
      old.vista.ancho != vista.ancho;
}

class _RutaPainter extends CustomPainter {
  final RutaMundial datos;
  final _Vista vista;
  final Animation<double> animacion;

  _RutaPainter(this.datos, this.vista, this.animacion) : super(repaint: animacion);

  Offset _bezier(Offset a, Offset c, Offset b, double t) {
    final u = 1 - t;
    return a * (u * u) + c * (2 * u * t) + b * (t * t);
  }

  Offset _tangente(Offset a, Offset c, Offset b, double t) {
    return (c - a) * (2 * (1 - t)) + (b - c) * (2 * t);
  }

  void _marcador(Canvas canvas, Size size, Offset p, String codigo) {
    canvas.drawCircle(p, 9, Paint()..color = Colors.white.withValues(alpha: 0.25));
    canvas.drawCircle(p, 5, Paint()..color = Colors.white);
    canvas.drawCircle(p, 2.5, Paint()..color = const Color(0xFF123F85));

    final texto = TextPainter(
      text: TextSpan(
        text: codigo,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    var x = p.dx - texto.width / 2;
    x = x.clamp(2.0, size.width - texto.width - 2);
    var y = p.dy - 12 - texto.height;
    if (y < 2) y = p.dy + 12;
    texto.paint(canvas, Offset(x, y));
  }

  void _avion(Canvas canvas, Offset centro, double angulo, double tamano) {
    // Silueta vista desde arriba, apuntando hacia arriba (y negativa).
    final mitad = <Offset>[
      const Offset(0, -1),
      const Offset(0.09, -0.7),
      const Offset(0.09, -0.15),
      const Offset(0.95, 0.2),
      const Offset(0.95, 0.34),
      const Offset(0.09, 0.14),
      const Offset(0.09, 0.62),
      const Offset(0.38, 0.86),
      const Offset(0.38, 0.97),
      const Offset(0, 0.86),
    ];
    final path = Path()..moveTo(mitad.first.dx, mitad.first.dy);
    for (final p in mitad.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in mitad.skip(1).toList().reversed) {
      path.lineTo(-p.dx, p.dy);
    }
    path.close();

    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.rotate(angulo);
    canvas.scale(tamano);
    canvas.drawShadow(path, Colors.black, 2, true);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final a = vista.proyectar(datos.origenLat, datos.origenLon, size);
    final b = vista.proyectar(datos.destinoLat, datos.destinoLon, size);
    final dir = b - a;
    final largo = dir.distance;

    if (largo < 4) {
      _marcador(canvas, size, a, datos.origenCodigo);
      return;
    }

    final mitad = (a + b) / 2;
    var normal = Offset(-dir.dy, dir.dx) / largo;
    if (normal.dy > 0) normal = -normal; // el arco se curva hacia arriba
    final altura = math.min(largo * 0.28, size.height * 0.45);
    final control = mitad + normal * altura * 2; // el punto de control queda al doble de la flecha del arco

    final v = animacion.value;
    final t = Curves.easeInOutCubic.transform((v / 0.85).clamp(0.0, 1.0));

    final segmentos = math.max(12, (largo / 9).round());
    final tenue = Paint()..color = Colors.white.withValues(alpha: 0.35);
    final fuerte = Paint()..color = Colors.white.withValues(alpha: 0.95);
    for (var i = 0; i <= segmentos; i++) {
      final u = i / segmentos;
      final p = _bezier(a, control, b, u);
      canvas.drawCircle(p, u <= t ? 2.1 : 1.6, u <= t ? fuerte : tenue);
    }

    _marcador(canvas, size, a, datos.origenCodigo);
    _marcador(canvas, size, b, datos.destinoCodigo);

    final pos = _bezier(a, control, b, t);
    final tg = _tangente(a, control, b, t);
    final angulo = math.atan2(tg.dy, tg.dx) + math.pi / 2;
    _avion(canvas, pos, angulo, math.max(7.0, math.min(size.width * 0.03, largo * 0.45)));
  }

  @override
  bool shouldRepaint(covariant _RutaPainter old) =>
      old.datos != datos || old.vista.lonMin != vista.lonMin || old.vista.latMin != vista.latMin;
}
