import 'package:aerotech_app/models/destino.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/pages/login_page.dart';
import 'package:aerotech_app/pages/registro_page.dart';
import 'package:aerotech_app/services/publico_service.dart';
import 'package:aerotech_app/utils/fechas.dart';
import 'package:aerotech_app/widgets/logo_aerotech.dart';
import 'package:aerotech_app/widgets/ruta_mundial.dart';
import 'package:flutter/material.dart';

/// Página de bienvenida (antes del login): destinos y vuelos de hoy, sin necesidad de cuenta.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final PublicoService publicoService = PublicoService();

  late Future<List<DestinoPromo>> futureDestinos;
  late Future<List<Vuelo>> futureHoy;

  static const _colores = [
    [Color(0xFF0B2A8A), Color(0xFF1E6FD9)],
    [Color(0xFF00695C), Color(0xFF26A69A)],
    [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
    [Color(0xFFBF360C), Color(0xFFFF7043)],
    [Color(0xFF283593), Color(0xFF5C6BC0)],
    [Color(0xFF00838F), Color(0xFF4DD0E1)],
  ];

  static const _fondo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF061A47), Color(0xFF0B3B9E), Color(0xFF1565C0)],
  );

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    futureDestinos = publicoService.getDestinos();
    futureHoy = publicoService.getVuelosHoy();
  }

  void _irALogin() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  void _irARegistro() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistroPage()));
  }

  String get _hoy => DateTime.now().toIso8601String().substring(0, 10);

  // ---------------------------------------------------------------- secciones

  Widget _barra(bool ancho) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ancho ? 40 : 16, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: LogoAeroTech(tamano: ancho ? 44 : 36, claro: true),
              ),
            ),
          ),
          if (ancho)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                minimumSize: const Size(0, 44),
              ),
              onPressed: _irARegistro,
              child: const Text('Crear cuenta'),
            ),
          const SizedBox(width: 10),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0B2A8A),
              minimumSize: const Size(0, 44),
            ),
            onPressed: _irALogin,
            child: const Text('Iniciar sesión', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _hero(bool ancho) {
    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vuela por Ecuador\ny el mundo.',
          style: TextStyle(
            color: Colors.white,
            fontSize: ancho ? 46 : 32,
            fontWeight: FontWeight.w300,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Mira los destinos y los vuelos de hoy. Para reservar, crea tu cuenta o inicia sesión.',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00C2D1),
                foregroundColor: const Color(0xFF04223F),
                minimumSize: const Size(0, 52),
                textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              onPressed: _irALogin,
              icon: const Icon(Icons.flight_takeoff),
              label: const Text('Reservar un vuelo'),
            ),
            if (!ancho)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  minimumSize: const Size(0, 52),
                ),
                onPressed: _irARegistro,
                child: const Text('Crear cuenta'),
              ),
          ],
        ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(ancho ? 40 : 20, 12, ancho ? 40 : 20, 48),
      child: ancho
          ? Row(
              children: [
                Expanded(flex: 5, child: texto),
                const SizedBox(width: 48),
                const Expanded(
                  flex: 5,
                  child: RutaMundial(
                    origenLat: -0.1292,
                    origenLon: -78.3575,
                    destinoLat: 25.7959,
                    destinoLon: -80.287,
                    origenCodigo: 'UIO',
                    destinoCodigo: 'MIA',
                  ),
                ),
              ],
            )
          : texto,
    );
  }

  Widget _titulo(String texto, String subtitulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text(subtitulo, style: TextStyle(color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _destinos() {
    return FutureBuilder<List<DestinoPromo>>(
      future: futureDestinos,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
        }
        final destinos = snapshot.data;
        if (destinos == null || destinos.isEmpty) return const SizedBox.shrink();

        final disponible = MediaQuery.of(context).size.width - 24;
        final columnas = (disponible / 210).floor().clamp(2, 8);
        final visibles = destinos.length < columnas ? destinos.length : columnas;
        final anchoTarjeta = ((disponible - 12 * (visibles - 1)) / visibles).clamp(170.0, 320.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo('Destinos destacados', 'Con vuelos próximos y el mejor precio'),
            SizedBox(
              height: 170,
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
                    onTap: _irALogin,
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
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
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

  Widget _tarjetaVuelo(Vuelo v) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _irALogin,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _vuelosHoy() {
    return FutureBuilder<List<Vuelo>>(
      future: futureHoy,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  const Text('No se pudo cargar la información de vuelos.'),
                  TextButton.icon(
                    onPressed: () => setState(_cargar),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        final vuelos = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _titulo('Vuelos disponibles hoy', fechaLarga(_hoy)),
            if (vuelos.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Ya no quedan vuelos para hoy. Inicia sesión para buscar otros días.',
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
                        for (final v in vuelos) SizedBox(width: anchoItem, child: _tarjetaVuelo(v)),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _ventajas() {
    Widget item(IconData icono, String titulo, String texto) {
      return SizedBox(
        width: 260,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(icono, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(texto, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _titulo('¿Por qué AeroTech?', 'Todo lo que necesitas para tu viaje'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              item(Icons.event_seat, 'Elige tu asiento', 'Mapa del avión en Económica y Ejecutiva.'),
              item(Icons.luggage, 'Equipaje a tu medida', 'Agrega maletas de bodega solo si las necesitas.'),
              item(Icons.receipt_long, 'Un solo comprobante', 'Ida y vuelta en una sola factura.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pie() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 36),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(gradient: _fondo),
      child: Column(
        children: [
          const LogoAeroTech(tamano: 30, claro: true),
          const SizedBox(height: 8),
          const Text(
            'Aplicaciones Distribuidas · UTA – FISEI · 2026',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final ancho = c.maxWidth >= 900;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(gradient: _fondo),
                  child: SafeArea(
                    bottom: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(children: [_barra(ancho), _hero(ancho)]),
                      ),
                    ),
                  ),
                ),
                _destinos(),
                _vuelosHoy(),
                _ventajas(),
                _pie(),
              ],
            ),
          );
        },
      ),
    );
  }
}
