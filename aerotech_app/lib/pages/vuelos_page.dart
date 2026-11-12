import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/pages/reservas_page.dart';
import 'package:aerotech_app/pages/seleccion_asientos_page.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
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
  final origenController = TextEditingController();
  final destinoController = TextEditingController();

  late Future<List<Vuelo>> futureVuelos;
  String? _fecha;

  // Solo visual por ahora: aún no se envían al servidor.
  bool _idaYVuelta = true;
  String? _fechaRegreso;
  int _adultos = 1;
  int _ninos = 0;
  int _infantes = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    origenController.dispose();
    destinoController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      futureVuelos = vueloService.getVuelos(
        origen: origenController.text.trim(),
        destino: destinoController.text.trim(),
        fecha: _fecha,
      );
    });
  }

  void _limpiar() {
    origenController.clear();
    destinoController.clear();
    _fecha = null;
    _fechaRegreso = null;
    _reload();
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
      _fecha = _iso(rango.start);
      _fechaRegreso = _iso(rango.end);
    } else {
      final fecha = await showDatePicker(
        context: context,
        initialDate: _fecha != null ? DateTime.parse(_fecha!) : hoy,
        firstDate: hoy,
        lastDate: ultimo,
        helpText: 'Escoger fecha de ida',
      );
      if (fecha == null) return;
      _fecha = _iso(fecha);
      _fechaRegreso = null;
    }
    _reload();
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

  Future<void> _elegirAsientos(Vuelo vuelo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SeleccionAsientosPage(vuelo: vuelo)),
    );
    if (result == true) _reload();
  }

  Widget _buildFiltros() {
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
              onSelectionChanged: (valor) {
                _idaYVuelta = valor.first;
                _fecha = null;
                _fechaRegreso = null;
                _reload();
              },
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
            children: [
              Expanded(
                child: TextField(
                  controller: origenController,
                  decoration: const InputDecoration(
                    labelText: 'Origen',
                    prefixIcon: Icon(Icons.flight_takeoff),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _reload(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: destinoController,
                  decoration: const InputDecoration(
                    labelText: 'Destino',
                    prefixIcon: Icon(Icons.flight_land),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _reload(),
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
                onPressed: _reload,
                icon: const Icon(Icons.search),
                label: const Text('Buscar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVuelo(Vuelo vuelo) {
    final sinAsientos = vuelo.asientosDisponibles == 0;
    return Card(
      key: ValueKey(vuelo.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.flight)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vuelo.origen} → ${vuelo.destino}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text('${vuelo.fecha}   ${vuelo.horaSalida} - ${vuelo.horaLlegada}'),
                  Text(
                    sinAsientos
                        ? 'Agotado'
                        : '${vuelo.asientosDisponibles} de ${vuelo.capacidad} asientos libres',
                    style: TextStyle(color: sinAsientos ? Colors.red : Colors.grey[700]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('desde', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(
                  '\$${vuelo.precio.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: sinAsientos ? null : () => _elegirAsientos(vuelo),
                  icon: const Icon(Icons.event_seat, size: 18),
                  label: const Text('Asientos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.inicio ? 'AeroTech' : 'Buscar vuelos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Recargar',
          ),
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
          _buildFiltros(),
          Expanded(
            child: FutureBuilder<List<Vuelo>>(
              future: futureVuelos,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorView(error: snapshot.error, onRetry: _reload);
                }

                final vuelos = snapshot.data ?? [];
                if (vuelos.isEmpty) {
                  return const Center(child: Text('No hay vuelos que coincidan con la búsqueda.'));
                }

                return ListView.builder(
                  itemCount: vuelos.length,
                  itemBuilder: (context, index) => _buildVuelo(vuelos[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
