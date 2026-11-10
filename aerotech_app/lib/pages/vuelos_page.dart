import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/pages/seleccion_asientos_page.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';

class VuelosPage extends StatefulWidget {
  const VuelosPage({super.key});

  @override
  State<VuelosPage> createState() => _VuelosPageState();
}

class _VuelosPageState extends State<VuelosPage> {
  final VueloService vueloService = VueloService();
  final origenController = TextEditingController();
  final destinoController = TextEditingController();

  late Future<List<Vuelo>> futureVuelos;
  String? _fecha;

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
    _reload();
  }

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: hoy,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 2),
    );
    if (fecha == null) return;
    _fecha = fecha.toIso8601String().substring(0, 10);
    _reload();
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
              OutlinedButton.icon(
                onPressed: _seleccionarFecha,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_fecha ?? 'Fecha'),
              ),
              const Spacer(),
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
        title: const Text('Buscar vuelos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Column(
        children: [
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
