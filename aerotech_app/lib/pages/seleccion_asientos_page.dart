import 'package:aerotech_app/models/asiento.dart';
import 'package:aerotech_app/models/clase.dart';
import 'package:aerotech_app/models/pasajeros.dart';
import 'package:aerotech_app/models/tramo.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/widgets/boton_inicio.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';

/// Selección de asientos de todos los tramos del viaje (una pestaña por vuelo).
/// Se elige exactamente un asiento por pasajero, solo de la clase elegida.
/// Al continuar devuelve un [SeleccionTramo] por cada tramo; la reserva se crea en el resumen.
class SeleccionAsientosPage extends StatefulWidget {
  final List<TramoViaje> tramos;
  final Pasajeros pasajeros;

  const SeleccionAsientosPage({super.key, required this.tramos, required this.pasajeros});

  @override
  State<SeleccionAsientosPage> createState() => _SeleccionAsientosPageState();
}

class _SeleccionAsientosPageState extends State<SeleccionAsientosPage> {
  final VueloService vueloService = VueloService();

  late Future<List<MapaAsientos>> futureMapas;
  late final List<List<String>> _sel = [for (final _ in widget.tramos) <String>[]];
  int _tab = 0;

  static const double _tamano = 46;
  static const Color _azul = Color(0xFF0B2A8A);
  static const Color _dorado = Color(0xFFA47551);

  int get _cantidad => widget.pasajeros.conAsiento;
  Clase _clase(int i) => widget.tramos[i].clase;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      futureMapas = Future.wait(
        widget.tramos.map((t) => vueloService.getAsientos(t.vuelo.id)),
      ).then((mapas) {
        for (var i = 0; i < mapas.length; i++) {
          _sel[i].removeWhere((a) => mapas[i].ocupado(a) || mapas[i].clase(a) != _clase(i));
        }
        return mapas;
      });
    });
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), backgroundColor: Colors.red));
  }

  void _alternar(MapaAsientos mapa, int i, String asiento) {
    if (mapa.ocupado(asiento)) return;
    if (mapa.clase(asiento) != _clase(i)) {
      _mensaje('Ese asiento es de clase ${mapa.clase(asiento).nombre}. Usted eligió ${_clase(i).nombre}.');
      return;
    }
    setState(() {
      final lista = _sel[i];
      if (lista.contains(asiento)) {
        lista.remove(asiento);
      } else if (lista.length >= _cantidad) {
        _mensaje('Solo puede elegir $_cantidad ${_cantidad == 1 ? 'asiento' : 'asientos'} (uno por pasajero).');
      } else {
        lista.add(asiento);
        lista.sort((a, b) {
          final fila = mapa.fila(a).compareTo(mapa.fila(b));
          return fila != 0 ? fila : a.compareTo(b);
        });
      }
    });
  }

  double _subtotal(List<MapaAsientos> mapas, int i) =>
      _sel[i].fold<double>(0, (t, a) => t + mapas[i].precio(a));

  bool get _completo => _sel.every((s) => s.length == _cantidad);

  String _pasajero(int k) {
    final p = widget.pasajeros;
    return k < p.adultos ? 'Adulto ${k + 1}' : 'Niño ${k - p.adultos + 1}';
  }

  int _libresEnClase(MapaAsientos mapa, int i) {
    var libres = 0;
    for (var fila = 1; fila <= mapa.filas; fila++) {
      if (mapa.vuelo.claseDeFila(fila) != _clase(i)) continue;
      for (final c in mapa.columnas) {
        if (!mapa.ocupado('$fila$c')) libres++;
      }
    }
    return libres;
  }

  void _continuar(List<MapaAsientos> mapas) {
    Navigator.pop(context, [
      for (var i = 0; i < mapas.length; i++)
        SeleccionTramo(
          vuelo: mapas[i].vuelo,
          clase: _clase(i),
          asientos: List<String>.from(_sel[i]),
          subtotal: _subtotal(mapas, i),
        ),
    ]);
  }

  // ---------------------------------------------------------------- mapa de asientos

  Widget _asiento(MapaAsientos mapa, int i, String asiento) {
    final colors = Theme.of(context).colorScheme;
    final ocupado = mapa.ocupado(asiento);
    final otraClase = mapa.clase(asiento) != _clase(i);
    final seleccionado = _sel[i].contains(asiento);
    final ventana = mapa.esVentana(asiento);
    final deshabilitado = ocupado || otraClase;

    final String mensaje;
    if (ocupado) {
      mensaje = 'Asiento $asiento no disponible';
    } else if (otraClase) {
      mensaje = 'Asiento $asiento · clase ${mapa.clase(asiento).nombre} (no es su clase)';
    } else {
      mensaje = 'Asiento $asiento · ${_nombreTipo(mapa.tipo(asiento))} · \$${mapa.precio(asiento).toStringAsFixed(2)}';
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Tooltip(
        message: mensaje,
        child: Material(
          color: deshabilitado
              ? Colors.grey.shade300
              : (seleccionado ? colors.primary : Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: deshabilitado ? BorderSide.none : BorderSide(color: seleccionado ? colors.primary : _azul, width: 1.6),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: ocupado ? null : () => _alternar(mapa, i, asiento),
            child: SizedBox(
              width: _tamano,
              height: _tamano,
              child: Stack(
                children: [
                  if (seleccionado)
                    Center(
                      child: Text(
                        asiento,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  if (ventana && !deshabilitado && !seleccionado)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: CustomPaint(size: const Size(14, 14), painter: _Esquina(_azul)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _nombreTipo(String tipo) => tipo[0].toUpperCase() + tipo.substring(1);

  Widget _letras(MapaAsientos mapa) {
    Widget letra(String l) => SizedBox(
          width: _tamano + 8,
          child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...mapa.columnas.sublist(0, 3).map(letra),
        const SizedBox(width: 40),
        ...mapa.columnas.sublist(3).map(letra),
      ],
    );
  }

  Widget _fila(MapaAsientos mapa, int i, int fila) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...mapa.columnas.sublist(0, 3).map((c) => _asiento(mapa, i, '$fila$c')),
        SizedBox(
          width: 40,
          child: Text(
            fila.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
        ...mapa.columnas.sublist(3).map((c) => _asiento(mapa, i, '$fila$c')),
      ],
    );
  }

  Widget _titulo(String texto, Color color) {
    final ancho = 6 * (_tamano + 8) + 40;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: SizedBox(
        width: ancho,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texto, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Divider(height: 1, color: Colors.grey.shade300),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _cabina(MapaAsientos mapa, int i, {bool compacto = false}) {
    final fe = mapa.vuelo.filasEjecutiva;
    final hijos = <Widget>[];

    void seccion(String titulo, Color color, int desde, int hasta) {
      hijos.add(_titulo(titulo, color));
      hijos.add(_letras(mapa));
      hijos.add(const SizedBox(height: 6));
      for (var fila = desde; fila <= hasta; fila++) {
        hijos.add(_fila(mapa, i, fila));
      }
    }

    if (fe > 0) seccion('Cabina Ejecutiva', _dorado, 1, fe);
    if (fe < mapa.filas) seccion('Cabina Económica', _azul, fe + 1, mapa.filas);

    // Perfil del avión: fuselaje con la nariz arriba, alas y cola alrededor de la cabina.
    final ala = compacto ? 56.0 : 150.0;
    return CustomPaint(
      painter: _PerfilAvion(ala: ala, nariz: compacto ? 90 : 120),
      child: Padding(
        padding: EdgeInsets.fromLTRB(ala, compacto ? 96 : 130, ala, compacto ? 80 : 100),
        child: Column(mainAxisSize: MainAxisSize.min, children: hijos),
      ),
    );
  }

  // ---------------------------------------------------------------- panel lateral

  Widget _pestanas() {
    if (widget.tramos.length == 1) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (var i = 0; i < widget.tramos.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: i == _tab ? colors.primary : Colors.grey.shade300,
                        width: i == _tab ? 3 : 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_sel[i].length == _cantidad)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(Icons.check_circle, size: 16, color: Colors.green),
                        ),
                      Text(
                        '${widget.tramos[i].vuelo.origenCodigo}-${widget.tramos[i].vuelo.destinoCodigo}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: i == _tab ? FontWeight.bold : FontWeight.normal,
                          color: i == _tab ? colors.primary : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _leyenda(int i) {
    Widget item(Widget muestra, String texto) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [muestra, const SizedBox(width: 6), Text(texto, style: const TextStyle(fontSize: 12))],
        );

    Widget cuadro(Color fondo, {Color? borde, Widget? hijo}) => Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(5),
            border: borde == null ? null : Border.all(color: borde, width: 1.5),
          ),
          child: hijo,
        );

    final primary = Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(cuadro(Colors.white, borde: _azul), 'Disponible'),
        item(
          cuadro(
            Colors.white,
            borde: _azul,
            hijo: Align(alignment: Alignment.bottomRight, child: CustomPaint(size: const Size(8, 8), painter: _Esquina(_azul))),
          ),
          'Ventana (+\$${_recargo.toStringAsFixed(2)})',
        ),
        item(cuadro(primary), 'Seleccionado'),
        item(cuadro(Colors.grey.shade300), 'No disponible'),
      ],
    );
  }

  double _recargo = 0;

  Widget _panel(List<MapaAsientos> mapas) {
    final i = _tab;
    final mapa = mapas[i];
    final tramo = widget.tramos[i];
    final v = tramo.vuelo;
    final total = List.generate(mapas.length, (k) => _subtotal(mapas, k)).fold<double>(0, (a, b) => a + b);
    final libres = _libresEnClase(mapa, i);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hacia ${v.destino} · ${v.duracion}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _azul),
        ),
        const SizedBox(height: 2),
        Text('${v.origenEtiqueta} → ${v.destinoEtiqueta}'),
        Text(
          '${v.fecha}  ${v.horaSalida} - ${v.horaLlegada} · Clase ${tramo.clase.nombre}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        if (libres < _cantidad)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            color: Colors.orange.shade100,
            child: Text(
              'Solo quedan $libres asientos libres en clase ${tramo.clase.nombre} y necesita $_cantidad. '
              'Vuelva y elija otro vuelo o clase.',
              style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
            ),
          ),
        const Divider(height: 28),
        _leyenda(i),
        const Divider(height: 28),
        for (var k = 0; k < _cantidad; k++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(child: Text(_pasajero(k))),
                if (k < _sel[i].length) ...[
                  Text(_sel[i][k], style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Text('\$${mapa.precio(_sel[i][k]).toStringAsFixed(2)}'),
                ] else
                  Text('Sin asiento', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
        const Divider(height: 24),
        Row(
          children: [
            const Expanded(child: Text('Asientos de este vuelo')),
            Text('\$${_subtotal(mapas, i).toStringAsFixed(2)}'),
          ],
        ),
        if (mapas.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                const Expanded(child: Text('Total asientos', style: TextStyle(fontWeight: FontWeight.bold))),
                Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        const SizedBox(height: 2),
        Text('Sin IVA ni equipaje.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _barraInferior(List<MapaAsientos> mapas) {
    final total = List.generate(mapas.length, (k) => _subtotal(mapas, k)).fold<double>(0, (a, b) => a + b);
    final faltan = [
      for (var k = 0; k < _sel.length; k++) _cantidad - _sel[k].length,
    ].fold<int>(0, (a, b) => a + b);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asientos ${_sel[_tab].length} de $_cantidad'
                    '${_sel[_tab].isEmpty ? '' : ': ${_sel[_tab].join(', ')}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    faltan == 0
                        ? 'Total asientos: \$${total.toStringAsFixed(2)} (sin IVA)'
                        : 'Faltan $faltan por elegir${mapas.length > 1 ? ' en total' : ''}',
                    style: TextStyle(
                      fontWeight: faltan == 0 ? FontWeight.bold : FontWeight.normal,
                      color: faltan == 0 ? null : Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _completo ? () => _continuar(mapas) : null,
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MapaAsientos>>(
      future: futureMapas,
      builder: (context, snapshot) {
        final mapas = snapshot.data;
        if (mapas != null) _recargo = mapas.first.recargoVentana;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Selecciona asientos'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _reload,
                tooltip: 'Actualizar mapa',
              ),
              const BotonInicio(),
              const BotonCerrarSesion(),
            ],
          ),
          body: Builder(
            builder: (context) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ErrorView(error: snapshot.error, onRetry: _reload);
              }

              final ancho = MediaQuery.of(context).size.width;
              final mapa = SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _cabina(mapas![_tab], _tab, compacto: ancho < 860),
                  ),
                ),
              );

              if (ancho >= 860) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: mapa),
                    Container(
                      width: 400,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _pestanas(),
                            _panel(mapas),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed: _completo ? () => _continuar(mapas) : null,
                                child: const Text('Continuar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        _pestanas(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _leyenda(_tab),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: mapa),
                  _barraInferior(mapas),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Esquina extends CustomPainter {
  final Color color;

  _Esquina(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _Esquina old) => old.color != color;
}

/// Silueta del avión (vista desde arriba): fuselaje con nariz redondeada, alas y cola.
class _PerfilAvion extends CustomPainter {
  final double ala;
  final double nariz;

  _PerfilAvion({required this.ala, required this.nariz});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final x0 = ala - 24;
    final x1 = w - ala + 24;
    final cx = w / 2;
    final fw = x1 - x0;
    final colaInicio = h - 70;

    final relleno = Paint()..color = const Color(0xFFE9EBF1);
    final borde = Paint()
      ..color = const Color(0xFFD0D4DD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Alas y plano de cola (detrás del fuselaje)
    Path poligono(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        p.lineTo(o.dx, o.dy);
      }
      return p..close();
    }

    final alas = [
      [Offset(x0, h * 0.32), Offset(6, h * 0.5), Offset(6, h * 0.56), Offset(x0, h * 0.5)],
      [Offset(x0, h - 105), Offset(ala * 0.45, h - 52), Offset(ala * 0.45, h - 36), Offset(x0, h - 66)],
    ];
    for (final pts in alas) {
      final izq = poligono(pts);
      final der = poligono([for (final o in pts) Offset(w - o.dx, o.dy)]);
      for (final p in [izq, der]) {
        canvas.drawPath(p, relleno);
        canvas.drawPath(p, borde);
      }
    }

    // Fuselaje
    final cuerpo = Path()
      ..moveTo(x0, colaInicio)
      ..lineTo(x0, nariz)
      ..cubicTo(x0, nariz * 0.3, cx - fw * 0.28, 0, cx, 0)
      ..cubicTo(cx + fw * 0.28, 0, x1, nariz * 0.3, x1, nariz)
      ..lineTo(x1, colaInicio)
      ..cubicTo(x1, h - 8, cx + fw * 0.3, h, cx, h)
      ..cubicTo(cx - fw * 0.3, h, x0, h - 8, x0, colaInicio)
      ..close();
    canvas.drawPath(cuerpo, Paint()..color = Colors.white);
    canvas.drawPath(cuerpo, borde);
  }

  @override
  bool shouldRepaint(covariant _PerfilAvion old) => old.ala != ala || old.nariz != nariz;
}
