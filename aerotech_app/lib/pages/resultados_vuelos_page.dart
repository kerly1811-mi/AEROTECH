import 'package:aerotech_app/models/aeropuerto.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/pages/seleccion_asientos_page.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';

class ResultadosVuelosPage extends StatefulWidget {
  final Aeropuerto origen;
  final Aeropuerto destino;
  final String fecha;
  final String? fechaRegreso;
  final bool idaYVuelta;
  final String pasajeros;

  const ResultadosVuelosPage({
    super.key,
    required this.origen,
    required this.destino,
    required this.fecha,
    required this.fechaRegreso,
    required this.idaYVuelta,
    required this.pasajeros,
  });

  @override
  State<ResultadosVuelosPage> createState() => _ResultadosVuelosPageState();
}

class _ResultadosVuelosPageState extends State<ResultadosVuelosPage> {
  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  final VueloService vueloService = VueloService();

  late Future<List<Vuelo>> futureVuelos;
  late String _fechaSel;
  bool _paso2 = false; // false: vuelo de ida, true: vuelo de regreso
  Vuelo? _idaElegida;
  bool _avisoVisible = true;

  Aeropuerto get _origenPaso => _paso2 ? widget.destino : widget.origen;
  Aeropuerto get _destinoPaso => _paso2 ? widget.origen : widget.destino;

  @override
  void initState() {
    super.initState();
    _fechaSel = widget.fecha;
    _cargar();
  }

  void _cargar() {
    setState(() {
      // Se trae la ruta completa para poder mostrar el precio de cada día.
      futureVuelos = vueloService.getVuelos(origenId: _origenPaso.id, destinoId: _destinoPaso.id);
    });
  }

  String _corta(String iso) {
    final f = DateTime.parse(iso);
    return '${f.day} ${_meses[f.month - 1]}';
  }

  String _larga(String iso) {
    final f = DateTime.parse(iso);
    return '${_dias[f.weekday - 1]}, ${_meses[f.month - 1]} ${f.day}, ${f.year}';
  }

  String _duracion(Vuelo v) {
    int minutos(String hora) {
      final p = hora.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    var total = minutos(v.horaLlegada) - minutos(v.horaSalida);
    if (total <= 0) total += 24 * 60;
    final h = total ~/ 60;
    final m = total % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
  }

  String get _resumenFechas {
    if (widget.idaYVuelta && widget.fechaRegreso != null) {
      return '${_corta(widget.fecha)} - ${_corta(widget.fechaRegreso!)} · Ida y vuelta';
    }
    return '${_corta(widget.fecha)} · Solo ida';
  }

  void _volverPaso1() {
    setState(() {
      _paso2 = false;
      _idaElegida = null;
      _fechaSel = widget.fecha;
    });
    _cargar();
  }

  Future<void> _elegir(Vuelo vuelo) async {
    if (widget.idaYVuelta && !_paso2) {
      setState(() {
        _idaElegida = vuelo;
        _paso2 = true;
        _fechaSel = widget.fechaRegreso ?? widget.fecha;
      });
      _cargar();
      return;
    }

    final aReservar = _paso2 ? _idaElegida! : vuelo;
    if (_paso2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por ahora solo se reserva el vuelo de ida.')),
      );
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SeleccionAsientosPage(vuelo: aReservar)),
    );
    if (result == true && mounted) {
      if (_paso2) {
        _volverPaso1();
      } else {
        _cargar();
      }
    }
  }

  Widget _barraResumen() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: colors.primary,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle(
              style: TextStyle(color: colors.onPrimary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.origen.etiqueta} → ${widget.destino.etiqueta}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text('$_resumenFechas · ${widget.pasajeros}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: colors.onPrimary),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Nueva búsqueda'),
          ),
        ],
      ),
    );
  }

  Widget _barraIdaElegida() {
    final v = _idaElegida!;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.flight_takeoff),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vuelo de ida', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('${_larga(v.fecha)}  ·  ${v.horaSalida} → ${v.horaLlegada}'),
                ],
              ),
            ),
            TextButton(onPressed: _volverPaso1, child: const Text('Cambiar vuelo')),
          ],
        ),
      ),
    );
  }

  Widget _titulo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              _paso2 ? Icons.flight_land : Icons.flight_takeoff,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _paso2 ? 'Seleccionar vuelo de regreso' : 'Seleccionar vuelo de ida',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text('${_larga(_fechaSel)} · Hacia ${_destinoPaso.etiqueta}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avisoSoloIda() {
    if (widget.idaYVuelta || !_avisoVisible) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Importante! Estás reservando un vuelo de solo ida',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Si no eres ciudadano o residente del país de destino, las autoridades '
                    'de inmigración pueden pedirte una prueba de retorno o de continuidad.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _avisoVisible = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tiraDeFechas(List<Vuelo> vuelos) {
    final centro = DateTime.parse(_fechaSel);
    final colors = Theme.of(context).colorScheme;
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: 7,
        itemBuilder: (context, i) {
          final dia = centro.add(Duration(days: i - 3));
          final iso = dia.toIso8601String().substring(0, 10);
          final delDia = vuelos.where((v) => v.fecha == iso && v.asientosDisponibles > 0).toList();
          final disponible = delDia.isNotEmpty && !dia.isBefore(hoy);
          final precio = disponible
              ? delDia.map((v) => v.precio).reduce((a, b) => a < b ? a : b)
              : null;
          final seleccionado = iso == _fechaSel;

          return InkWell(
            onTap: disponible && !seleccionado ? () => setState(() => _fechaSel = iso) : null,
            child: Container(
              width: 112,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: seleccionado ? colors.primary : Colors.grey.shade300,
                    width: seleccionado ? 3 : 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_dias[dia.weekday - 1]}, ${_corta(iso)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    precio != null ? '\$${precio.toStringAsFixed(2)}' : 'No disponible',
                    style: TextStyle(
                      fontSize: precio != null ? 16 : 12,
                      fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                      color: precio != null ? null : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tarjetaVuelo(Vuelo v) {
    final colors = Theme.of(context).colorScheme;
    final sinAsientos = v.asientosDisponibles == 0;
    final etiqueta = _paso2 ? 'Vuelo de regreso' : 'Vuelo de ida';

    return Card(
      key: ValueKey(v.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
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
                          child: Text(
                            _duracion(v),
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                  ),
                ),
                Text(v.horaLlegada, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(v.origen, style: TextStyle(color: Colors.grey[700])),
                Text(v.destino, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Operado: AeroTech', style: TextStyle(color: Colors.grey[700])),
                      Text(
                        sinAsientos
                            ? 'Agotado'
                            : '${v.asientosDisponibles} de ${v.capacidad} asientos libres',
                        style: TextStyle(
                          fontSize: 12,
                          color: sinAsientos ? Colors.red : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$etiqueta · desde', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    Text(
                      '\$${v.precio.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                    const SizedBox(height: 6),
                    FilledButton.icon(
                      onPressed: sinAsientos ? null : () => _elegir(v),
                      icon: Icon(widget.idaYVuelta ? Icons.check : Icons.event_seat, size: 18),
                      label: Text(widget.idaYVuelta ? 'Seleccionar' : 'Asientos'),
                    ),
                  ],
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
    return PopScope(
      canPop: !_paso2,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _volverPaso1();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Resultados'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _cargar,
              tooltip: 'Recargar',
            ),
            const BotonCerrarSesion(),
          ],
        ),
        body: Column(
          children: [
            _barraResumen(),
            Expanded(
              child: FutureBuilder<List<Vuelo>>(
                future: futureVuelos,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ErrorView(error: snapshot.error, onRetry: _cargar);
                  }

                  final todos = snapshot.data ?? [];
                  final delDia = todos.where((v) => v.fecha == _fechaSel).toList();

                  return ListView(
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      if (_paso2 && _idaElegida != null) _barraIdaElegida(),
                      _titulo(),
                      _avisoSoloIda(),
                      const SizedBox(height: 8),
                      _tiraDeFechas(todos),
                      const SizedBox(height: 8),
                      if (delDia.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              'No hay vuelos disponibles para esta fecha.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else
                        ...delDia.map(_tarjetaVuelo),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
