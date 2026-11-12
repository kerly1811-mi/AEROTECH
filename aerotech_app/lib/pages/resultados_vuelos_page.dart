import 'package:aerotech_app/widgets/boton_inicio.dart';
import 'package:aerotech_app/models/aeropuerto.dart';
import 'package:aerotech_app/models/clase.dart';
import 'package:aerotech_app/models/pasajeros.dart';
import 'package:aerotech_app/models/tramo.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/pages/resumen_viaje_page.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
import 'package:aerotech_app/utils/fechas.dart';
import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';

class ResultadosVuelosPage extends StatefulWidget {
  final Aeropuerto origen;
  final Aeropuerto destino;
  final String fecha;
  final String? fechaRegreso;
  final bool idaYVuelta;
  final Pasajeros pasajeros;

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
  final VueloService vueloService = VueloService();

  late Future<List<Vuelo>> futureVuelos;
  late String _fechaSel;
  bool _paso2 = false; // false: vuelo de ida, true: vuelo de regreso
  TramoViaje? _ida;
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

  String get _resumenFechas {
    if (widget.idaYVuelta && widget.fechaRegreso != null) {
      return '${fechaCorta(widget.fecha)} - ${fechaCorta(widget.fechaRegreso!)} · Ida y vuelta';
    }
    return '${fechaCorta(widget.fecha)} · Solo ida';
  }

  void _volverPaso1() {
    setState(() {
      _paso2 = false;
      _ida = null;
      _fechaSel = widget.fecha;
    });
    _cargar();
  }

  Future<void> _elegir(Vuelo vuelo, Clase clase) async {
    final tramo = TramoViaje(vuelo, clase);

    if (widget.idaYVuelta && !_paso2) {
      setState(() {
        _ida = tramo;
        _paso2 = true;
        _fechaSel = widget.fechaRegreso ?? widget.fecha;
      });
      _cargar();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResumenViajePage(
          ida: _paso2 ? _ida! : tramo,
          regreso: _paso2 ? tramo : null,
          pasajeros: widget.pasajeros,
        ),
      ),
    );
    // Al volver (atrás) se queda en esta pantalla; los cupos pueden haber cambiado.
    if (mounted) _cargar();
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
                  Text('$_resumenFechas · ${widget.pasajeros.resumen}', style: const TextStyle(fontSize: 12)),
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
    final t = _ida!;
    final v = t.vuelo;
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
                  Text('Vuelo de ida · ${t.clase.nombre}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${fechaLarga(v.fecha)}  ·  ${v.horaSalida} → ${v.horaLlegada}'),
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
                Text('${fechaLarga(_fechaSel)} · Hacia ${_destinoPaso.etiqueta}'),
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
    // En el regreso no se puede volar antes de la fecha de ida.
    final minimo = _paso2 && _ida != null ? DateTime.parse(_ida!.vuelo.fecha) : hoy;

    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: 7,
        itemBuilder: (context, i) {
          final dia = centro.add(Duration(days: i - 3));
          final iso = dia.toIso8601String().substring(0, 10);
          final delDia = vuelos
              .where((v) => v.fecha == iso && v.disponibles(Clase.economica) + v.disponibles(Clase.ejecutiva) > 0)
              .toList();
          final disponible = delDia.isNotEmpty && !dia.isBefore(minimo);
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
                    fechaConDia(iso),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    precio != null ? 'desde \$${precio.toStringAsFixed(2)}' : 'No disponible',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: precio != null ? 14 : 12,
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

  Widget _botonClase(Vuelo v, Clase clase, {required bool lateral}) {
    final necesarios = widget.pasajeros.conAsiento;
    final libres = v.disponibles(clase);
    final habil = libres >= necesarios;
    final ejecutiva = clase == Clase.ejecutiva;
    final colors = Theme.of(context).colorScheme;

    final String detalle;
    if (libres == 0) {
      detalle = 'Agotada';
    } else if (!habil) {
      detalle = 'Solo $libres libres (necesita $necesarios)';
    } else {
      detalle = '$libres asientos libres';
    }

    final boton = FilledButton(
        onPressed: habil ? () => _elegir(v, clase) : null,
        style: FilledButton.styleFrom(
          backgroundColor: ejecutiva ? Colors.grey.shade900 : colors.primary,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(clase.nombre, style: const TextStyle(fontSize: 12)),
            Text(
              '\$${v.precioClase(clase).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(detalle, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      );

    // A la derecha de la hora: ancho fijo. En pantallas angostas: reparten el ancho de la fila.
    return lateral ? SizedBox(width: 150, child: boton) : Expanded(child: boton);
  }

  Widget _infoVuelo(Vuelo v) {
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
                      child: Text(
                        v.duracion,
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
            Text(v.origenEtiqueta, style: TextStyle(color: Colors.grey[700])),
            Text(v.destinoEtiqueta, style: TextStyle(color: Colors.grey[700])),
          ],
        ),
        const SizedBox(height: 4),
        Text('Operado: AeroTech', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
      ],
    );
  }

  Widget _tarjetaVuelo(Vuelo v) {
    return Card(
      key: ValueKey(v.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth >= 680;

            if (ancho) {
              // Horario y ruta a la izquierda; las clases a la derecha, en la misma fila.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _infoVuelo(v)),
                  const SizedBox(width: 20),
                  _botonClase(v, Clase.economica, lateral: true),
                  if (v.tieneEjecutiva) ...[
                    const SizedBox(width: 10),
                    _botonClase(v, Clase.ejecutiva, lateral: true),
                  ],
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoVuelo(v),
                const Divider(height: 20),
                Row(
                  children: [
                    _botonClase(v, Clase.economica, lateral: false),
                    if (v.tieneEjecutiva) ...[
                      const SizedBox(width: 10),
                      _botonClase(v, Clase.ejecutiva, lateral: false),
                    ],
                  ],
                ),
              ],
            );
          },
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
            const BotonInicio(),
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
                      if (_paso2 && _ida != null) _barraIdaElegida(),
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
