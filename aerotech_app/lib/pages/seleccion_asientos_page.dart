import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/models/asiento.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/pages/comprobante_page.dart';
import 'package:aerotech_app/pages/login_page.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:aerotech_app/services/reserva_service.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';

class SeleccionAsientosPage extends StatefulWidget {
  final Vuelo vuelo;
  const SeleccionAsientosPage({super.key, required this.vuelo});

  @override
  State<SeleccionAsientosPage> createState() => _SeleccionAsientosPageState();
}

class _SeleccionAsientosPageState extends State<SeleccionAsientosPage> {
  final VueloService vueloService = VueloService();
  final ReservaService reservaService = ReservaService();

  late Future<MapaAsientos> futureMapa;
  final List<String> _seleccionados = [];
  bool _isSaving = false;

  static const int _maximo = 9;
  static const double _iva = 0.15;
  static const double _tamano = 38;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      futureMapa = vueloService.getAsientos(widget.vuelo.id).then((mapa) {
        _seleccionados.removeWhere(mapa.ocupado);
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

  int _numeroFila(String asiento) => int.parse(asiento.substring(0, asiento.length - 1));

  void _ordenar() {
    _seleccionados.sort((a, b) {
      final fila = _numeroFila(a).compareTo(_numeroFila(b));
      return fila != 0 ? fila : a.compareTo(b);
    });
  }

  void _alternar(MapaAsientos mapa, String asiento) {
    if (mapa.ocupado(asiento)) return;
    setState(() {
      if (_seleccionados.contains(asiento)) {
        _seleccionados.remove(asiento);
      } else if (_seleccionados.length >= _maximo) {
        _showMessage('Puede seleccionar máximo $_maximo asientos por reserva.', isError: true);
      } else {
        _seleccionados.add(asiento);
        _ordenar();
      }
    });
  }

  double _subtotal(MapaAsientos mapa) {
    return _seleccionados.fold<double>(0, (total, asiento) => total + mapa.precio(asiento));
  }

  String _nombreTipo(String tipo) => tipo[0].toUpperCase() + tipo.substring(1);

  Widget _fila(String texto, double valor, {bool negrita = false}) {
    final estilo = TextStyle(fontWeight: negrita ? FontWeight.bold : FontWeight.normal);
    return Row(
      children: [
        Text(texto, style: estilo),
        const Spacer(),
        Text('\$${valor.toStringAsFixed(2)}', style: estilo),
      ],
    );
  }

  Future<void> _confirmar(MapaAsientos mapa) async {
    final subtotal = _subtotal(mapa);
    final iva = subtotal * _iva;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Confirmar reserva'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${mapa.vuelo.origen} → ${mapa.vuelo.destino}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${mapa.vuelo.fecha}   ${mapa.vuelo.horaSalida} - ${mapa.vuelo.horaLlegada}'),
                const Divider(),
                ..._seleccionados.map(
                  (a) => _fila('Asiento $a (${_nombreTipo(mapa.tipo(a))})', mapa.precio(a)),
                ),
                const Divider(),
                _fila('Subtotal', subtotal),
                _fila('IVA (15%)', iva),
                _fila('Total', subtotal + iva, negrita: true),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Volver'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);

    try {
      final resultado = await reservaService.crearReserva(
        mapa.vuelo.id,
        List<String>.from(_seleccionados),
        mapa.vuelo.version,
      );
      await _mostrarExito(resultado);
    } on SessionExpiredException catch (e) {
      if (mounted) LoginPage.irAlLogin(context, e.message);
    } on ConflictException catch (e) {
      await _handleConflict(e);
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
    } catch (e) {
      _showMessage('Ocurrió un error inesperado: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _mostrarExito(Map<String, dynamic> resultado) async {
    if (!mounted) return;
    final reservaId = (resultado['reserva_id'] as num).toInt();
    final total = (resultado['total'] as num).toDouble();
    final asientos = List<String>.from(resultado['asientos'] ?? _seleccionados);

    final verComprobante = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Reserva confirmada'),
        content: Text(
          'Reserva #$reservaId\n'
          'Asientos: ${asientos.join(', ')}\n'
          'Total: \$${total.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Ver comprobante'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (verComprobante == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ComprobantePage(reservaId: reservaId)),
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  Future<void> _handleConflict(ConflictException e) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          icon: const Icon(Icons.warning_amber, color: Colors.orange, size: 48),
          title: const Text('Asientos no disponibles'),
          content: Text(
            '${e.message}\n\n'
            'El mapa se actualizará con los asientos ocupados. '
            'Revise su selección e intente nuevamente.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ver mapa actualizado'),
            ),
          ],
        ),
      ),
    );
    _reload();
  }

  Widget _asiento(MapaAsientos mapa, String asiento) {
    final colors = Theme.of(context).colorScheme;
    final ocupado = mapa.ocupado(asiento);
    final seleccionado = _seleccionados.contains(asiento);
    final ventana = mapa.esVentana(asiento);

    Color fondo = Colors.white;
    Color borde = Colors.grey.shade400;
    Color texto = Colors.grey.shade700;

    if (ocupado) {
      fondo = Colors.grey.shade300;
      borde = Colors.grey.shade300;
    } else if (seleccionado) {
      fondo = colors.primary;
      borde = colors.primary;
      texto = Colors.white;
    } else if (ventana) {
      fondo = Colors.lightBlue.shade50;
      borde = Colors.lightBlue.shade300;
      texto = Colors.lightBlue.shade800;
    }

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Tooltip(
        message: ocupado
            ? 'Asiento $asiento ocupado'
            : 'Asiento $asiento · ${_nombreTipo(mapa.tipo(asiento))} · \$${mapa.precio(asiento).toStringAsFixed(2)}',
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
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        item(Colors.white, Colors.grey.shade400, 'Disponible'),
        item(Colors.lightBlue.shade50, Colors.lightBlue.shade300,
            'Ventana (+\$${mapa.recargoVentana.toStringAsFixed(2)})'),
        item(primary, primary, 'Seleccionado'),
        item(Colors.grey.shade300, Colors.grey.shade300, 'Ocupado', icono: Icons.close),
      ],
    );
  }

  Widget _avion(MapaAsientos mapa) {
    final borde = Colors.grey.shade300;
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
          const SizedBox(height: 16),
          _encabezado(mapa),
          const SizedBox(height: 4),
          for (int fila = 1; fila <= mapa.filas; fila++) _filaAsientos(mapa, fila),
        ],
      ),
    );
  }

  Widget _resumen(MapaAsientos mapa) {
    final subtotal = _subtotal(mapa);
    final total = subtotal * (1 + _iva);
    final vacio = _seleccionados.isEmpty;

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
                    vacio ? 'Seleccione sus asientos' : 'Asientos: ${_seleccionados.join(', ')}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!vacio)
                    Text(
                      'Total con IVA: \$${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: vacio || _isSaving ? null : () => _confirmar(mapa),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(vacio ? 'Reservar' : 'Reservar (${_seleccionados.length})'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vuelo = widget.vuelo;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${vuelo.origen} → ${vuelo.destino}'),
            Text(
              '${vuelo.fecha}   ${vuelo.horaSalida} - ${vuelo.horaLlegada}',
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
