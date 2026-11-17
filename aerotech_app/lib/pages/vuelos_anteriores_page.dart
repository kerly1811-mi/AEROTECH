import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/utils/busqueda_vuelos.dart';
import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/widgets/boton_inicio.dart';
import 'package:aerotech_app/widgets/buscador_vuelos.dart';
import 'package:flutter/material.dart';

/// Vuelos de días anteriores (solo consulta), dentro de la gestión de vuelos.
class VuelosAnterioresPage extends StatefulWidget {
  final List<Vuelo> vuelos;

  const VuelosAnterioresPage({super.key, required this.vuelos});

  @override
  State<VuelosAnterioresPage> createState() => _VuelosAnterioresPageState();
}

class _VuelosAnterioresPageState extends State<VuelosAnterioresPage> {
  final _busqueda = TextEditingController();
  String _consulta = '';

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Los más recientes primero.
    final ordenados = [...widget.vuelos]
      ..sort((a, b) => '${b.fecha} ${b.horaSalida}'.compareTo('${a.fecha} ${a.horaSalida}'));
    final vuelos = ordenados.where((v) => coincideBusqueda(v, _consulta)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vuelos anteriores'),
        actions: const [BotonInicio(), BotonCerrarSesion()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: BuscadorVuelos(
                  controller: _busqueda,
                  onChanged: (v) => setState(() => _consulta = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${vuelos.length} de ${widget.vuelos.length} vuelos · solo consulta',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ),
              ),
              Expanded(
                child: vuelos.isEmpty
                    ? Center(
                        child: Text(
                          widget.vuelos.isEmpty
                              ? 'Todavía no hay vuelos de días anteriores.'
                              : 'Ningún vuelo coincide con la búsqueda.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: vuelos.length,
                        itemBuilder: (context, i) {
                          final v = vuelos[i];
                          return Card(
                            key: ValueKey(v.id),
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey.shade300,
                                child: const Icon(Icons.history),
                              ),
                              title: Text('${v.origenEtiqueta} → ${v.destinoEtiqueta}'),
                              subtitle: Text(
                                '${v.fecha}   ${v.horaSalida} - ${v.horaLlegada}\n'
                                'Precio: \$${v.precio.toStringAsFixed(2)} · '
                                'Ocupados: ${v.capacidad - v.asientosDisponibles} de ${v.capacidad}',
                              ),
                              isThreeLine: true,
                              trailing: Text('#${v.id}', style: TextStyle(color: Colors.grey[600])),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
