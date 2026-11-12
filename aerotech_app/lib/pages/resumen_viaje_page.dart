import 'package:aerotech_app/models/clase.dart';
import 'package:aerotech_app/models/equipaje.dart';
import 'package:aerotech_app/models/pasajeros.dart';
import 'package:aerotech_app/models/tramo.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/pages/comprobante_page.dart';
import 'package:aerotech_app/pages/login_page.dart';
import 'package:aerotech_app/pages/seleccion_asientos_page.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:aerotech_app/services/reserva_service.dart';
import 'package:aerotech_app/utils/fechas.dart';
import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/widgets/boton_inicio.dart';
import 'package:aerotech_app/widgets/ruta_mundial.dart';
import 'package:flutter/material.dart';

class ResumenViajePage extends StatefulWidget {
  final TramoViaje ida;
  final TramoViaje? regreso;
  final Pasajeros pasajeros;

  const ResumenViajePage({
    super.key,
    required this.ida,
    required this.regreso,
    required this.pasajeros,
  });

  @override
  State<ResumenViajePage> createState() => _ResumenViajePageState();
}

class _ResumenViajePageState extends State<ResumenViajePage> {
  final ReservaService reservaService = ReservaService();

  bool _isSaving = false;
  TarifasEquipaje? _tarifas;

  /// Maletas de bodega adicionales: [tramo][pasajero].
  late final List<List<int>> _maletas;

  static const double _iva = 0.15;

  List<TramoViaje> get _tramos => [widget.ida, if (widget.regreso != null) widget.regreso!];

  @override
  void initState() {
    super.initState();
    _maletas = [for (final _ in _tramos) List<int>.filled(widget.pasajeros.conAsiento, 0)];
    _cargarTarifas();
  }

  Future<void> _cargarTarifas() async {
    try {
      final tarifas = await reservaService.getTarifasEquipaje();
      if (mounted) setState(() => _tarifas = tarifas);
    } on SessionExpiredException catch (e) {
      if (mounted) LoginPage.irAlLogin(context, e.message);
    } catch (_) {
      // Sin tarifas no se ofrece equipaje adicional; el resto del viaje sigue funcionando.
    }
  }

  String _nombreTramo(int i) => _tramos.length == 1 ? 'Vuelo' : (i == 0 ? 'Ida' : 'Regreso');

  String _pasajero(int k) {
    final p = widget.pasajeros;
    return k < p.adultos ? 'Adulto ${k + 1}' : 'Niño ${k - p.adultos + 1}';
  }

  double _costoEquipajeTramo(int i) {
    final t = _tarifas;
    if (t == null) return 0;
    return _maletas[i].fold<double>(0, (total, m) => total + t.costo(m));
  }

  double get _subtotalBase =>
      _tramos.fold<double>(0, (t, tramo) => t + tramo.tarifa * widget.pasajeros.conAsiento);

  double get _subtotalEquipaje {
    var total = 0.0;
    for (var i = 0; i < _tramos.length; i++) {
      total += _costoEquipajeTramo(i);
    }
    return total;
  }

  void _mensaje(String texto, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), backgroundColor: error ? Colors.red : Colors.green));
  }

  String _dinero(double valor) => '\$${valor.toStringAsFixed(2)}';

  // ---------------------------------------------------------------- flujo de reserva

  Future<void> _continuar() async {
    final elegidos = await Navigator.push<List<SeleccionTramo>>(
      context,
      MaterialPageRoute(
        builder: (context) => SeleccionAsientosPage(tramos: _tramos, pasajeros: widget.pasajeros),
      ),
    );
    if (elegidos == null || !mounted) return; // volvió atrás

    final selecciones = <SeleccionTramo>[];
    for (var i = 0; i < elegidos.length; i++) {
      final sel = elegidos[i];
      // El pasajero k viaja en el k-ésimo asiento (ordenados), con sus maletas.
      final equipaje = <String, int>{};
      for (var k = 0; k < sel.asientos.length; k++) {
        if (_maletas[i][k] > 0) equipaje[sel.asientos[k]] = _maletas[i][k];
      }
      selecciones.add(SeleccionTramo(
        vuelo: sel.vuelo,
        clase: sel.clase,
        asientos: sel.asientos,
        subtotal: sel.subtotal,
        equipaje: equipaje,
        costoEquipaje: _costoEquipajeTramo(i),
      ));
    }
    await _confirmar(selecciones);
  }

  Widget _filaDinero(String texto, double valor, {bool negrita = false}) {
    final estilo = TextStyle(fontWeight: negrita ? FontWeight.bold : FontWeight.normal);
    return Row(
      children: [
        Expanded(child: Text(texto, style: estilo)),
        Text(_dinero(valor), style: estilo),
      ],
    );
  }

  Future<void> _confirmar(List<SeleccionTramo> selecciones) async {
    final subtotal = selecciones.fold<double>(0, (t, s) => t + s.total);
    final iva = subtotal * _iva;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Confirmar reserva'),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < selecciones.length; i++) ...[
                    Text(
                      '${_nombreTramo(i)} · '
                      '${selecciones[i].vuelo.origenEtiqueta} → ${selecciones[i].vuelo.destinoEtiqueta}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${fechaLarga(selecciones[i].vuelo.fecha)}  ${selecciones[i].vuelo.horaSalida} - '
                      '${selecciones[i].vuelo.horaLlegada}',
                    ),
                    Text('Clase ${selecciones[i].clase.nombre} · Asientos: ${selecciones[i].asientos.join(', ')}'),
                    const SizedBox(height: 4),
                    _filaDinero('Asientos', selecciones[i].subtotal),
                    if (selecciones[i].costoEquipaje > 0)
                      _filaDinero(
                        'Equipaje adicional (${selecciones[i].equipaje.values.fold<int>(0, (a, b) => a + b)})',
                        selecciones[i].costoEquipaje,
                      ),
                    const Divider(),
                  ],
                  _filaDinero('Subtotal', subtotal),
                  _filaDinero('IVA (15%)', iva),
                  _filaDinero('Total', subtotal + iva, negrita: true),
                ],
              ),
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

    if (confirm != true || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final resultado = await reservaService.crearReservas(selecciones);
      if (mounted) setState(() => _isSaving = false);
      await _mostrarExito(resultado);
    } on SessionExpiredException catch (e) {
      if (mounted) LoginPage.irAlLogin(context, e.message);
    } on ConflictException catch (e) {
      if (mounted) setState(() => _isSaving = false);
      await _conflicto(e);
    } on ApiException catch (e) {
      _mensaje(e.message, error: true);
    } catch (e) {
      _mensaje('Ocurrió un error inesperado: $e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _conflicto(ConflictException e) async {
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
            'No se guardó ninguna reserva. Elija sus asientos nuevamente.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Elegir de nuevo'),
            ),
          ],
        ),
      ),
    );
    if (mounted) await _continuar();
  }

  Future<void> _mostrarExito(Map<String, dynamic> resultado) async {
    if (!mounted) return;
    final reservas = (resultado['reservas'] as List).cast<Map<String, dynamic>>();
    final total = (resultado['total'] as num).toDouble();
    final varias = reservas.length > 1;

    final verComprobante = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Reserva confirmada'),
        content: Text(
          [
            'Viaje #${reservas.first['viaje_id']}',
            for (var i = 0; i < reservas.length; i++)
              '${varias ? (i == 0 ? 'Ida' : 'Regreso') : 'Asientos'}: ${(reservas[i]['asientos'] as List).join(', ')}',
            'Total: ${_dinero(total)}',
          ].join('\n'),
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
    final navigator = Navigator.of(context);
    navigator.popUntil((ruta) => ruta.isFirst);
    if (verComprobante == true) {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => ComprobantePage(reservaId: (reservas.first['reserva_id'] as num).toInt()),
        ),
      );
    }
  }

  // ---------------------------------------------------------------- interfaz

  Widget _mapa(TramoViaje tramo) {
    final v = tramo.vuelo;
    return RutaMundial(
      origenLat: v.origenLat!,
      origenLon: v.origenLon!,
      destinoLat: v.destinoLat!,
      destinoLon: v.destinoLon!,
      origenCodigo: v.origenCodigo,
      destinoCodigo: v.destinoCodigo,
    );
  }

  Widget _tarjetaTramo(TramoViaje tramo, String titulo) {
    final v = tramo.vuelo;
    final colors = Theme.of(context).colorScheme;
    final ejecutiva = tramo.clase == Clase.ejecutiva;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  avatar: Icon(
                    titulo == 'Vuelo de regreso' ? Icons.flight_land : Icons.flight_takeoff,
                    size: 18,
                  ),
                  label: Text(titulo),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(fechaLarga(v.fecha), overflow: TextOverflow.ellipsis)),
                Chip(
                  label: Text(tramo.clase.nombre),
                  backgroundColor: ejecutiva ? Colors.grey.shade900 : colors.primaryContainer,
                  labelStyle: TextStyle(
                    color: ejecutiva ? Colors.white : colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, c) {
                final info = _infoTramo(v);
                if (!v.tieneCoordenadas) return info;
                // Mapa pequeño a la izquierda de la información del vuelo.
                if (c.maxWidth >= 520) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 200, child: _mapa(tramo)),
                      const SizedBox(width: 16),
                      Expanded(child: info),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: SizedBox(width: 220, child: _mapa(tramo))),
                    const SizedBox(height: 10),
                    info,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTramo(Vuelo v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            Row(
              children: [
                Text(v.horaSalida, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(v.duracion, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                ),
                Text(v.horaLlegada, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(v.origenEtiqueta, style: TextStyle(color: Colors.grey[700])),
                Text(v.destinoEtiqueta, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text('Operado: AeroTech', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cambiar vuelo'),
                ),
              ],
            ),
      ],
    );
  }

  Widget _stepper(int tramo, int pasajero, TarifasEquipaje t) {
    final valor = _maletas[tramo][pasajero];
    return Row(
      children: [
        Expanded(
          child: Text(_pasajero(pasajero)),
        ),
        if (valor > 0)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(_dinero(t.costo(valor)), style: TextStyle(color: Colors.grey[700])),
          ),
        IconButton.outlined(
          visualDensity: VisualDensity.compact,
          onPressed: valor > 0 ? () => setState(() => _maletas[tramo][pasajero] = valor - 1) : null,
          icon: const Icon(Icons.remove),
          tooltip: 'Quitar maleta',
        ),
        SizedBox(width: 28, child: Text('$valor', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))),
        IconButton.outlined(
          visualDensity: VisualDensity.compact,
          onPressed: valor < t.maximoExtra ? () => setState(() => _maletas[tramo][pasajero] = valor + 1) : null,
          icon: const Icon(Icons.add),
          tooltip: 'Agregar maleta',
        ),
      ],
    );
  }

  Widget _tarjetaEquipaje(int i) {
    final t = _tarifas;
    if (t == null) return const SizedBox.shrink();
    final clase = _tramos[i].clase;
    final incluidas = t.incluidas(clase);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.luggage),
                const SizedBox(width: 8),
                Text(
                  'Equipaje · ${_nombreTramo(i)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Incluido por pasajero: 1 equipaje de mano (${t.manoKg} kg) + 1 artículo personal'
              '${incluidas > 0 ? ' + $incluidas equipajes de bodega (${t.bodegaKg} kg)' : ''}.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            Text(
              'Equipaje de bodega adicional por pasajero: 1.º ${_dinero(t.primerExtra)} · '
              '2.º ${_dinero(t.segundoExtra)}.',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const Divider(height: 20),
            for (var k = 0; k < widget.pasajeros.conAsiento; k++) _stepper(i, k, t),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaCosto() {
    final p = widget.pasajeros;
    final subtotal = _subtotalBase + _subtotalEquipaje;
    final iva = subtotal * _iva;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Costo de la reserva', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('TARIFA AÉREA', style: TextStyle(fontSize: 12, color: Colors.grey[700], letterSpacing: 1)),
            const SizedBox(height: 4),
            for (var i = 0; i < _tramos.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _filaDinero(
                  '${_nombreTramo(i)} · ${_tramos[i].clase.nombre} '
                  '(${p.conAsiento} × ${_dinero(_tramos[i].tarifa)})',
                  _tramos[i].tarifa * p.conAsiento,
                ),
              ),
            if (_subtotalEquipaje > 0) ...[
              const SizedBox(height: 8),
              Text('EQUIPAJE ADICIONAL', style: TextStyle(fontSize: 12, color: Colors.grey[700], letterSpacing: 1)),
              const SizedBox(height: 4),
              for (var i = 0; i < _tramos.length; i++)
                if (_costoEquipajeTramo(i) > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: _filaDinero(
                      '${_nombreTramo(i)} · ${_maletas[i].fold<int>(0, (a, b) => a + b)} maletas',
                      _costoEquipajeTramo(i),
                    ),
                  ),
            ],
            const Divider(height: 20),
            _filaDinero('Subtotal', subtotal),
            _filaDinero('IVA (15%)', iva),
            const SizedBox(height: 4),
            _filaDinero('Total estimado', subtotal + iva, negrita: true),
            const SizedBox(height: 8),
            Text(
              'Los asientos de ventana tienen un recargo que se suma al elegirlos. '
              'El total final se confirma después de escoger los asientos.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pasajeros;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resumen del viaje'),
        actions: const [BotonInicio(), BotonCerrarSesion()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Tu itinerario de viaje',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Revisa con detenimiento tu itinerario antes de continuar.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _tramos.length; i++) ...[
                _tarjetaTramo(_tramos[i], i == 1 ? 'Vuelo de regreso' : 'Vuelo de ida'),
                _tarjetaEquipaje(i),
              ],
              Card(
                child: ListTile(
                  leading: const Icon(Icons.people),
                  title: Text(p.resumen),
                  subtitle: Text(
                    'Elegirás ${p.conAsiento} ${p.conAsiento == 1 ? 'asiento' : 'asientos'} por vuelo.'
                    '${p.infantes > 0 ? ' Los infantes viajan en brazos de un adulto, sin asiento ni costo.' : ''}',
                  ),
                ),
              ),
              _tarjetaCosto(),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _isSaving ? null : _continuar,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Continuar y elegir asientos'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
