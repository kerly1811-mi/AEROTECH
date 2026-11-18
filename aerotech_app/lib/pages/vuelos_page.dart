import 'package:aerotech_app/models/aeropuerto.dart';
import 'package:aerotech_app/models/destino.dart';
import 'package:aerotech_app/models/pasajeros.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/pages/reservas_page.dart';
import 'package:aerotech_app/pages/resultados_vuelos_page.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
import 'package:aerotech_app/utils/fechas.dart';
import 'package:aerotech_app/widgets/aeropuerto_field.dart';
import 'package:aerotech_app/widgets/boton_inicio.dart';
import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:aerotech_app/widgets/logo_aerotech.dart';
import 'package:aerotech_app/widgets/selector_fechas.dart';
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
  Future<List<DestinoPromo>>? futureDestinos;
  Future<List<Vuelo>>? futureHoy;

  Aeropuerto? _origen;
  Aeropuerto? _destino;
  int _camposKey = 0;

  String? _fecha;

  bool _idaYVuelta = true;
  String? _fechaRegreso;
  int _adultos = 1;
  int _ninos = 0;
  int _infantes = 0;

  static const _colores = [
    [Color(0xFF0B2A8A), Color(0xFF1E6FD9)],
    [Color(0xFF00695C), Color(0xFF26A69A)],
    [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    [Color(0xFFBF360C), Color(0xFFFF7043)],
    [Color(0xFF283593), Color(0xFF5C6BC0)],
    [Color(0xFF00838F), Color(0xFF4DD0E1)],
  ];

  Pasajeros get _pasajeros => Pasajeros(adultos: _adultos, ninos: _ninos, infantes: _infantes);

  @override
  void initState() {
    super.initState();
    _cargarAeropuertos();
    if (widget.inicio) _cargarPortada();
  }

  void _cargarAeropuertos() {
    setState(() {
      futureAeropuertos = vueloService.getAeropuertos();
    });
  }

  void _cargarPortada() {
    futureDestinos = vueloService.getDestinos();
    futureHoy = vueloService.getVuelos(fecha: _iso(DateTime.now()));
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
          pasajeros: _pasajeros,
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
    final sel = await mostrarSelectorFechas(
      context,
      idaYVuelta: _idaYVuelta,
      ida: _fecha == null ? null : DateTime.parse(_fecha!),
      regreso: _fechaRegreso == null ? null : DateTime.parse(_fechaRegreso!),
    );
    if (sel == null) return;
    setState(() {
      _fecha = _iso(sel.ida);
      _fechaRegreso = sel.regreso == null ? null : _iso(sel.regreso!);
    });
  }

  String get _textoFechas {
    if (_fecha == null) return _idaYVuelta ? 'Escoger fechas de viaje' : 'Escoger fecha de ida';
    if (_idaYVuelta && _fechaRegreso != null) {
      return '${fechaConDia(_fecha!)}  →  ${fechaConDia(_fechaRegreso!)}';
    }
    return fechaLarga(_fecha!);
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

  // ---------------------------------------------------------------- formulario de búsqueda

  Widget _buildFiltros(List<Aeropuerto> opciones) {
    final grande = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 56),
      textStyle: const TextStyle(fontSize: 16),
      alignment: Alignment.centerLeft,
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(0, 52)),
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
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
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AeropuertoField(
                    key: ValueKey('origen$_camposKey'),
                    label: 'Origen',
                    icon: Icons.flight_takeoff,
                    opciones: opciones.where((a) => a != _destino).toList(),
                    valor: _origen,
                    onChanged: (a) => setState(() => _origen = a),
                    validator: (_) => null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton(
                    tooltip: 'Invertir origen y destino',
                    iconSize: 28,
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () => setState(() {
                      final tmp = _origen;
                      _origen = _destino;
                      _destino = tmp;
                      _camposKey++;
                    }),
                  ),
                ),
                Expanded(
                  child: AeropuertoField(
                    key: ValueKey('destino$_camposKey'),
                    label: 'Destino',
                    icon: Icons.flight_land,
                    opciones: opciones.where((a) => a != _origen).toList(),
                    valor: _destino,
                    onChanged: (a) => setState(() => _destino = a),
                    validator: (_) => null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: grande,
                onPressed: _seleccionarFechas,
                icon: const Icon(Icons.calendar_month),
                label: Text(_textoFechas, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: grande,
                onPressed: _elegirPasajeros,
                icon: const Icon(Icons.people),
                label: Text(_pasajeros.resumen),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 56), textStyle: const TextStyle(fontSize: 16)),
                  onPressed: _limpiar,
                  child: const Text('Limpiar'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _buscar,
                    icon: const Icon(Icons.search),
                    label: const Text('Buscar vuelos'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- portada: promociones y vuelos de hoy

  Widget _titulo(String texto, {String? subtitulo}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          if (subtitulo != null) Text(subtitulo, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  void _elegirDestino(DestinoPromo promo, List<Aeropuerto> aeropuertos) {
    final aeropuerto = aeropuertos.where((a) => a.id == promo.id).firstOrNull;
    if (aeropuerto == null) return;
    setState(() {
      _destino = aeropuerto;
      if (_origen == aeropuerto) _origen = null;
      _camposKey++;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Destino elegido: ${aeropuerto.etiqueta}. Ahora escoge tu origen y las fechas.'),
      ));
  }

  Widget _promociones(List<Aeropuerto> aeropuertos) {
    return FutureBuilder<List<DestinoPromo>>(
      future: futureDestinos,
      builder: (context, snapshot) {
        final destinos = snapshot.data;
        if (destinos == null || destinos.isEmpty) return const SizedBox.shrink();

        // Las tarjetas se reparten todo el ancho; si hay más, se desplaza hacia el lado.
        final disponible = MediaQuery.of(context).size.width - 24;
        final columnas = (disponible / 210).floor().clamp(2, 8);
        final visibles = destinos.length < columnas ? destinos.length : columnas;
        final anchoTarjeta = ((disponible - 12 * (visibles - 1)) / visibles).clamp(170.0, 320.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo('Destinos para tu próximo viaje', subtitulo: 'Toca uno para elegirlo como destino'),
            SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: destinos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final d = destinos[i];
                  final colores = _colores[i % _colores.length];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _elegirDestino(d, aeropuertos),
                    child: Container(
                      width: anchoTarjeta,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colores,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flight_takeoff, color: Colors.white70, size: 20),
                              const Spacer(),
                              Text(
                                d.codigo,
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            d.ciudad,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            d.pais,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Desde \$${d.desde.toStringAsFixed(0)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: colores[0], fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Vuelos de hoy que aún no han salido.
  List<Vuelo> _pendientesHoy(List<Vuelo> vuelos) {
    final ahora = DateTime.now();
    final hora = '${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}';
    return vuelos.where((v) => v.horaSalida.compareTo(hora) > 0 && v.asientosDisponibles > 0).toList();
  }

  void _verVueloHoy(Vuelo v, List<Aeropuerto> aeropuertos) {
    final origen = aeropuertos.where((a) => a.id == v.origenId).firstOrNull;
    final destino = aeropuertos.where((a) => a.id == v.destinoId).firstOrNull;
    if (origen == null || destino == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultadosVuelosPage(
          origen: origen,
          destino: destino,
          fecha: v.fecha,
          fechaRegreso: null,
          idaYVuelta: false,
          pasajeros: _pasajeros,
        ),
      ),
    );
  }

  Widget _tarjetaVueloHoy(Vuelo v, List<Aeropuerto> aeropuertos) {
    return Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _verVueloHoy(v, aeropuertos),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.horaSalida, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              Text(v.duracion, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${v.origenEtiqueta} → ${v.destinoEtiqueta}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Llega a las ${v.horaLlegada} · ${v.asientosDisponibles} asientos libres',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('desde', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              Text(
                                '\$${v.precio.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                );
  }

  Widget _vuelosDeHoy(List<Aeropuerto> aeropuertos) {
    return FutureBuilder<List<Vuelo>>(
      future: futureHoy,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) return const SizedBox.shrink();

        final vuelos = _pendientesHoy(snapshot.data ?? []);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo('Vuelos disponibles hoy', subtitulo: fechaLarga(_iso(DateTime.now()))),
            if (vuelos.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Text(
                  'Ya no quedan vuelos disponibles para hoy. Usa el buscador para ver otros días.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, c) {
                  final ancho = c.maxWidth - 24;
                  final columnas = ancho >= 1300 ? 3 : (ancho >= 800 ? 2 : 1);
                  final anchoItem = (ancho - 12 * (columnas - 1)) / columnas;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        for (final v in vuelos)
                          SizedBox(width: anchoItem, child: _tarjetaVueloHoy(v, aeropuertos)),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: widget.inicio ? const LogoAeroTech(tamano: 34) : const Text('Buscar vuelos'),
        actions: [
          if (!widget.inicio) const BotonInicio(),
          const BotonCerrarSesion(),
        ],
      ),
      body: FutureBuilder<List<Aeropuerto>>(
        future: futureAeropuertos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error, onRetry: _cargarAeropuertos);
          }
          final aeropuertos = snapshot.data ?? [];

          return ListView(
            children: [
              // Buscador: más angosto y centrado
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      if (widget.inicio)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.tonalIcon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ReservasPage()),
                              ),
                              icon: const Icon(Icons.event_note),
                              label: const Text('Mis reservas'),
                            ),
                          ),
                        ),
                      _buildFiltros(aeropuertos),
                    ],
                  ),
                ),
              ),
              // Destinos y vuelos de hoy: ocupan todo el ancho de la pantalla
              if (widget.inicio) ...[
                _promociones(aeropuertos),
                _vuelosDeHoy(aeropuertos),
              ],
            ],
          );
        },
      ),
    );
  }
}
