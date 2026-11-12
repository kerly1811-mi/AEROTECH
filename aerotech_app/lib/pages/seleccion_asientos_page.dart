import 'package:aerotech_app/widgets/boton_inicio.dart';
import 'package:aerotech_app/models/asiento.dart';
import 'package:aerotech_app/models/clase.dart';
import 'package:aerotech_app/models/tramo.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';

/// Mapa de asientos de un vuelo. Solo se pueden elegir asientos de la clase
/// seleccionada y exactamente [cantidad] (los pasajeros que ocupan asiento).
/// Al confirmar devuelve un [SeleccionTramo]; la reserva se crea en el resumen.
class SeleccionAsientosPage extends StatefulWidget {
  final TramoViaje tramo;
  final int cantidad;
  final String titulo;

  const SeleccionAsientosPage({
    super.key,
    required this.tramo,
    required this.cantidad,
    this.titulo = 'Elige tus asientos',
  });

  @override
  State<SeleccionAsientosPage> createState() => _SeleccionAsientosPageState();
}

class _SeleccionAsientosPageState extends State<SeleccionAsientosPage> {
  final VueloService vueloService = VueloService();

  late Future<MapaAsientos> futureMapa;
  final List<String> _seleccionados = [];

  static const double _tamano = 38;

  Clase get _clase => widget.tramo.clase;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      futureMapa = vueloService.getAsientos(widget.tramo.vuelo.id).then((mapa) {
        _seleccionados.removeWhere((a) => mapa.ocupado(a) || mapa.clase(a) != _clase);
        return mapa;
      });
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _ordenar(MapaAsientos mapa) {
    _seleccionados.sort((a, b) {
      final fila = mapa.fila(a).compareTo(mapa.fila(b));
      return fila != 0 ? fila : a.compareTo(b);
    });
  }

  void _alternar(MapaAsientos mapa, String asiento) {
    if (mapa.ocupado(asiento)) return;
    if (mapa.clase(asiento) != _clase) {
      _showMessage('Ese asiento es de clase ${mapa.clase(asiento).nombre}. Usted eligió ${_clase.nombre}.', isError: true);
      return;
    }
    setState(() {
      if (_seleccionados.contains(asiento)) {
        _seleccionados.remove(asiento);
      } else if (_seleccionados.length >= widget.cantidad) {
        _showMessage(
          'Solo puede elegir ${widget.cantidad} ${widget.cantidad == 1 ? 'asiento' : 'asientos'} '
          '(uno por pasajero).',
          isError: true,
        );
      } else {
        _seleccionados.add(asiento);
        _ordenar(mapa);
      }
    });
  }

  double _subtotal(MapaAsientos mapa) {
    return _seleccionados.fold<double>(0, (total, asiento) => total + mapa.precio(asiento));
  }

  String _nombreTipo(String tipo) => tipo[0].toUpperCase() + tipo.substring(1);

  int _libresEnClase(MapaAsientos mapa) {
    var libres = 0;
    for (var fila = 1; fila <= mapa.filas; fila++) {
      if (mapa.vuelo.claseDeFila(fila) != _clase) continue;
      for (final c in mapa.columnas) {
        if (!mapa.ocupado('$fila$c')) libres++;
      }
    }
    return libres;
  }

  void _aceptar(MapaAsientos mapa) {
    Navigator.pop(
      context,
      SeleccionTramo(
        vuelo: mapa.vuelo,
        clase: _clase,
        asientos: List<String>.from(_seleccionados),
        subtotal: _subtotal(mapa),
      ),
    );
  }

  Widget _asiento(MapaAsientos mapa, String asiento) {
    final colors = Theme.of(context).colorScheme;
    final ocupado = mapa.ocupado(asiento);
    final claseAsiento = mapa.clase(asiento);
    final deOtraClase = claseAsiento != _clase;
    final seleccionado = _seleccionados.contains(asiento);
    final ventana = mapa.esVentana(asiento);
    final ejecutiva = claseAsiento == Clase.ejecutiva;

    Color fondo = Colors.white;
    Color borde = Colors.grey.shade400;
    Color texto = Colors.grey.shade700;

    if (ocupado) {
      fondo = Colors.grey.shade300;
      borde = Colors.grey.shade300;
    } else if (deOtraClase) {
      fondo = Colors.grey.shade100;
      borde = Colors.grey.shade200;
      texto = Colors.grey.shade400;
    } else if (seleccionado) {
      fondo = colors.primary;
      borde = colors.primary;
      texto = Colors.white;
    } else if (ejecutiva) {
      fondo = ventana ? Colors.amber.shade100 : Colors.amber.shade50;
      borde = Colors.amber.shade700;
      texto = Colors.amber.shade900;
    } else if (ventana) {
      fondo = Colors.lightBlue.shade50;
      borde = Colors.lightBlue.shade300;
      texto = Colors.lightBlue.shade800;
    }

    final String mensaje;
    if (ocupado) {
      mensaje = 'Asiento $asiento ocupado';
    } else if (deOtraClase) {
      mensaje = 'Asiento $asiento · clase ${claseAsiento.nombre} (no es su clase)';
    } else {
      mensaje = 'Asiento $asiento · ${_nombreTipo(mapa.tipo(asiento))} · \$${mapa.precio(asiento).toStringAsFixed(2)}';
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Tooltip(
        message: mensaje,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: ocupado ? null : () => _alternar(mapa, asiento),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _tamano,
            height: _tamano,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fondo,
              border: Border.all(color: borde, width: 1.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: ocupado
                ? Icon(Icons.close, size: 18, color: Colors.grey.shade500)
                : Text(
                    asiento.substring(asiento.length - 1),
                    style: TextStyle(color: texto, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _pasillo(String texto) {
    return SizedBox(
      width: 30,
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
    );
  }

  Widget _encabezado(MapaAsientos mapa) {
    final izquierda = mapa.columnas.sublist(0, 3);
    final derecha = mapa.columnas.sublist(3);
    Widget letra(String l) => SizedBox(
          width: _tamano + 6,
          child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...izquierda.map(letra),
        _pasillo(''),
        ...derecha.map(letra),
      ],
    );
  }

  Widget _filaAsientos(MapaAsientos mapa, int fila) {
    final izquierda = mapa.columnas.sublist(0, 3);
    final derecha = mapa.columnas.sublist(3);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...izquierda.map((c) => _asiento(mapa, '$fila$c')),
        _pasillo('$fila'),
        ...derecha.map((c) => _asiento(mapa, '$fila$c')),
      ],
    );
  }

  Widget _etiquetaCabina(String texto, {bool resaltada = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: resaltada ? Theme.of(context).colorScheme.primary : Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _leyenda(MapaAsientos mapa) {
    Widget item(Color fondo, Color borde, String texto, {IconData? icono}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: fondo,
              border: Border.all(color: borde, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: icono != null ? Icon(icono, size: 12, color: Colors.grey.shade500) : null,
          ),
          const SizedBox(width: 6),
          Text(texto, style: const TextStyle(fontSize: 12)),
        ],
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    final ejecutiva = _clase == Clase.ejecutiva;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        ejecutiva
            ? item(Colors.amber.shade50, Colors.amber.shade700, 'Ejecutiva')
            : item(Colors.white, Colors.grey.shade400, 'Económica'),
        item(
          ejecutiva ? Colors.amber.shade100 : Colors.lightBlue.shade50,
          ejecutiva ? Colors.amber.shade700 : Colors.lightBlue.shade300,
          'Ventana (+\$${mapa.recargoVentana.toStringAsFixed(2)})',
        ),
        item(primary, primary, 'Seleccionado'),
        item(Colors.grey.shade100, Colors.grey.shade200, 'Otra clase'),
        item(Colors.grey.shade300, Colors.grey.shade300, 'Ocupado', icono: Icons.close),
      ],
    );
  }

  Widget _avion(MapaAsientos mapa) {
    final borde = Colors.grey.shade300;
    final filasEjecutiva = mapa.vuelo.filasEjecutiva;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borde, width: 2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(160),
          topRight: Radius.circular(160),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.airline_seat_recline_extra, color: Colors.grey.shade400),
          Text('Cabina', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 8),
          _encabezado(mapa),
          const SizedBox(height: 4),
          for (int fila = 1; fila <= mapa.filas; fila++) ...[
            if (fila == 1 && filasEjecutiva > 0)
              _etiquetaCabina('CLASE EJECUTIVA', resaltada: _clase == Clase.ejecutiva),
            if (fila == filasEjecutiva + 1)
              _etiquetaCabina('CLASE ECONÓMICA', resaltada: _clase == Clase.economica),
            _filaAsientos(mapa, fila),
          ],
        ],
      ),
    );
  }

  Widget _aviso(MapaAsientos mapa) {
    final libres = _libresEnClase(mapa);
    if (libres >= widget.cantidad) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.all(10),
      child: Text(
        'Solo quedan $libres asientos libres en clase ${_clase.nombre} y necesita ${widget.cantidad}. '
        'Vuelva y elija otro vuelo o clase.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.orange.shade900),
      ),
    );
  }

  Widget _resumen(MapaAsientos mapa) {
    final subtotal = _subtotal(mapa);
    final faltan = widget.cantidad - _seleccionados.length;
    final completo = faltan == 0;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                    'Asientos ${_seleccionados.length} de ${widget.cantidad}'
                    '${_seleccionados.isEmpty ? '' : ': ${_seleccionados.join(', ')}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!completo)
                    Text(
                      'Falta${faltan == 1 ? '' : 'n'} $faltan por elegir',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    )
                  else
                    Text(
                      'Subtotal: \$${subtotal.toStringAsFixed(2)} (sin IVA)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: completo ? () => _aceptar(mapa) : null,
              child: const Text('Confirmar asientos'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vuelo = widget.tramo.vuelo;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.titulo} · ${vuelo.origen} → ${vuelo.destino}'),
            Text(
              '${vuelo.fecha}   ${vuelo.horaSalida} - ${vuelo.horaLlegada} · ${_clase.nombre}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
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
      body: FutureBuilder<MapaAsientos>(
        future: futureMapa,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error, onRetry: _reload);
          }

          final mapa = snapshot.data!;

          return Column(
            children: [
              _aviso(mapa),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _leyenda(mapa),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _avion(mapa),
                    ),
                  ),
                ),
              ),
              _resumen(mapa),
            ],
          );
        },
      ),
    );
  }
}
