import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Marca de AeroTech: avión sobre una órbita, dentro de un cuadrado redondeado con degradado.
class MarcaAeroTech extends StatelessWidget {
  final double tamano;

  const MarcaAeroTech({super.key, this.tamano = 64});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: CustomPaint(painter: _MarcaPainter()),
    );
  }
}

/// Marca + nombre "AeroTech". Con [claro] el texto es blanco (para fondos oscuros).
class LogoAeroTech extends StatelessWidget {
  final double tamano;
  final bool claro;
  final bool vertical;

  const LogoAeroTech({super.key, this.tamano = 48, this.claro = false, this.vertical = false});

  @override
  Widget build(BuildContext context) {
    final base = claro ? Colors.white : const Color(0xFF0B2A8A);
    final acento = claro ? const Color(0xFF7FE9F2) : const Color(0xFF009DAE);
    final estilo = TextStyle(fontSize: tamano * 0.62, letterSpacing: -0.5, height: 1);

    final nombre = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Aero', style: estilo.copyWith(color: base, fontWeight: FontWeight.w300)),
          TextSpan(text: 'Tech', style: estilo.copyWith(color: acento, fontWeight: FontWeight.w800)),
        ],
      ),
    );

    final marca = MarcaAeroTech(tamano: tamano);
    if (vertical) {
      return Column(mainAxisSize: MainAxisSize.min, children: [marca, SizedBox(height: tamano * 0.25), nombre]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [marca, SizedBox(width: tamano * 0.25), nombre]);
  }
}

class _MarcaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Fondo
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w * 0.28)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B2A8A), Color(0xFF1E6FD9), Color(0xFF00C2D1)],
        ).createShader(rect),
    );

    // Órbita punteada bajo el avión
    final a = Offset(w * 0.16, h * 0.74);
    final c = Offset(w * 0.5, h * 1.0);
    final b = Offset(w * 0.84, h * 0.58);
    final punto = Paint()..color = Colors.white.withValues(alpha: 0.75);
    const n = 9;
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final u = 1 - t;
      final p = a * (u * u) + c * (2 * u * t) + b * (t * t);
      canvas.drawCircle(p, w * (0.012 + 0.018 * t), punto);
    }

    // Avión (apunta arriba a la derecha)
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
    canvas.translate(w * 0.52, h * 0.40);
    canvas.rotate(math.pi / 4);
    canvas.scale(w * 0.27);
    canvas.drawShadow(path, Colors.black, 1.5, true);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
