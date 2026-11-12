import 'package:aerotech_app/models/aeropuerto.dart';
import 'package:aerotech_app/pages/reservas_page.dart';
import 'package:aerotech_app/pages/resultados_vuelos_page.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
import 'package:aerotech_app/widgets/aeropuerto_field.dart';
import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';

class VuelosPage extends StatefulWidget {
  final bool inicio;

  const VuelosPage({super.key, this.inicio = false});

  @override
  State<VuelosPage> createState() => _VuelosPageState();
}

class _VuelosPageState extends State<VuelosPage> {
  final VueloService vueloService = VueloService();

  late Future<List<Aeropuerto>> futureAeropuertos;
  Aeropuerto? _origen;
  Aeropuerto? _destino;
  int _camposKey = 0;

  String? _fecha;

  bool _idaYVuelta = true;
  String? _fechaRegreso;
  int _adultos = 1;
  int _ninos = 0;
  int _infantes = 0;

  @override
  void initState() {
    super.initState();
    _cargarAeropuertos();
  }

  void _cargarAeropuertos() {
    setState(() => futureAeropuertos = vueloService.getAeropuertos());
  }

  void _buscar() {
    final origen = _origen;
    final destino = _destino;

    String? falta;
    if (origen == null || destino == null) {
      falta = 'Seleccione el origen y el destino de la lista.';
    } else if (_fecha == null || (_idaYVuelta && _fechaRegreso == null)) {
      falta = _idaYVuelta ? 'Escoja las fechas de ida y vuelta.' : 'Escoja la fecha de ida.';
    }
    if (falta != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(falta)));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultadosVuelosPage(
          origen: origen!,
          destino: destino!,
          fecha: _fecha!,
          fechaRegreso: _idaYVuelta ? _fechaRegreso : null,
          idaYVuelta: _idaYVuelta,
          pasajeros: _resumenPasajeros,
        ),
      ),
    );
  }

  void _limpiar() {
    setState(() {
      _origen = null;
      _destino = null;
      _camposKey++;
      _fecha = null;
      _fechaRegreso = null;
    });
  }

  String _iso(DateTime fecha) => fecha.toIso8601String().substring(0, 10);

  Future<void> _seleccionarFechas() async {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final ultimo = DateTime(hoy.year + 2, hoy.month, hoy.day);

    if (_idaYVuelta) {
      DateTimeRange? inicial;
      if (_fecha != null && _fechaRegreso != null) {
        inicial = DateTimeRange(
          start: DateTime.parse(_fecha!),
          end: DateTime.parse(_fechaRegreso!),
        );
      }
      final rango = await showDateRangePicker(
        context: context,
        firstDate: hoy,
        lastDate: ultimo,
        initialDateRange: inicial,
        helpText: 'Escoger fechas de ida y vuelta',
        saveText: 'Aceptar',
      );
      if (rango == null) return;
      setState(() {
        _fecha = _iso(rango.start);
        _fechaRegreso = _iso(rango.end);
      });
    } else {
      final fecha = await showDatePicker(
        context: context,
        initialDate: _fecha != null ? DateTime.parse(_fecha!) : hoy,
        firstDate: hoy,
        lastDate: ultimo,
        helpText: 'Escoger fecha de ida',
      );
      if (fecha == null) return;
      setState(() {
        _fecha = _iso(fecha);
        _fechaRegreso = null;
      });
    }
  }

  String get _textoFechas {
    if (_fecha == null) return _idaYVuelta ? 'Escoger fechas' : 'Escoger fecha';
    if (_idaYVuelta && _fechaRegreso != null) return '$_fecha  →  $_fechaRegreso';
    return _fecha!;
  }

  String get _resumenPasajeros {
    final partes = <String>[
      '$_adultos ${_adultos == 1 ? 'Adulto' : 'Adultos'}',
      if (_ninos > 0) '$_ninos ${_ninos == 1 ? 'Niño' : 'Niños'}',
      if (_infantes > 0) '$_infantes ${_infantes == 1 ? 'Infante' : 'Infantes'}',
    ];
    return partes.join(', ');
  }

  Future<void> _elegirPasajeros() async {
    const maximo = 9;
    var adultos = _adultos;
    var ninos = _ninos;
    var infantes = _infantes;

    final aceptar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          Widget fila(
            String titulo,
            String detalle,
            int valor,
            int min,
            int max,
            void Function(int) alCambiar,
          ) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(titulo),
              subtitle: Text(detalle),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.outlined(
                    onPressed: valor > min ? () => setLocal(() => alCambiar(valor - 1)) : null,
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text('$valor', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                  ),
                  IconButton.outlined(
                    onPressed: valor < max ? () => setLocal(() => alCambiar(valor + 1)) : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            title: const Text('Pasajeros'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                fila('Adultos', '12 años en adelante', adultos, 1, maximo - ninos, (v) {
                  adultos = v;
                  if (infantes > adultos) infantes = adultos;
                }),
                fila('Niños', '2 a 11 años', ninos, 0, maximo - adultos, (v) => ninos = v),
                fila('Infantes', 'Menores de 2 años (uno por adulto)', infantes, 0, adultos, (v) => infantes = v),
                const SizedBox(height: 4),
                Text(
                  'Máximo $maximo pasajeros con asiento por reserva.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Aceptar')),
            ],
          );
        },
      ),
    );

    if (aceptar == true) {
      setState(() {
        _adultos = adultos;
        _ninos = ninos;
        _infantes = infantes;
      });
    }
  }

  Widget _buildFiltros(List<Aeropuerto> opciones) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, icon: Icon(Icons.swap_horiz), label: Text('Ida y vuelta')),
                ButtonSegment(value: false, icon: Icon(Icons.arrow_right_alt), label: Text('Solo ida')),
              ],
              selected: {_idaYVuelta},
              onSelectionChanged: (valor) => setState(() {
                _idaYVuelta = valor.first;
                _fecha = null;
                _fechaRegreso = null;
              }),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _elegirPasajeros,
              icon: const Icon(Icons.person, size: 18),
              label: Text(_resumenPasajeros),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AeropuertoField(
                  key: ValueKey('origen$_camposKey'),
                  label: 'Origen',
                  icon: Icons.flight_takeoff,
                  dense: true,
                  opciones: opciones.where((a) => a != _destino).toList(),
                  valor: _origen,
                  onChanged: (a) => setState(() => _origen = a),
                  validator: (_) => null,
                ),
              ),
              IconButton(
                tooltip: 'Invertir origen y destino',
                icon: const Icon(Icons.swap_horiz),
                onPressed: () => setState(() {
                  final tmp = _origen;
                  _origen = _destino;
                  _destino = tmp;
                  _camposKey++;
                }),
              ),
              Expanded(
                child: AeropuertoField(
                  key: ValueKey('destino$_camposKey'),
                  label: 'Destino',
                  icon: Icons.flight_land,
                  dense: true,
                  opciones: opciones.where((a) => a != _origen).toList(),
                  valor: _destino,
                  onChanged: (a) => setState(() => _destino = a),
                  validator: (_) => null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _seleccionarFechas,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_textoFechas, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
              TextButton(onPressed: _limpiar, child: const Text('Limpiar')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _buscar,
                icon: const Icon(Icons.search),
                label: const Text('Buscar Vuelos'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.inicio ? 'AeroTech' : 'Buscar vuelos'),
        actions: [
          const BotonCerrarSesion(),
        ],
      ),
      body: Column(
        children: [
          if (widget.inicio)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReservasPage()),
                  ),
                  icon: const Icon(Icons.event_note),
                  label: const Text('Mis reservas'),
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Aeropuerto>>(
              future: futureAeropuertos,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorView(error: snapshot.error, onRetry: _cargarAeropuertos);
                }
                return Column(
                  children: [
                    _buildFiltros(snapshot.data ?? []),
                    const Expanded(child: _MensajeInicial()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MensajeInicial extends StatelessWidget {
  const _MensajeInicial();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Elige origen, destino y fechas para ver los vuelos disponibles.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
