import 'package:aerotech_app/widgets/boton_inicio.dart';
import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/config.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/pages/login_page.dart';
import 'package:aerotech_app/pages/vuelo_form_page.dart';
import 'package:aerotech_app/pages/vuelos_anteriores_page.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
import 'package:aerotech_app/utils/busqueda_vuelos.dart';
import 'package:aerotech_app/widgets/buscador_vuelos.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:aerotech_app/widgets/filtro_alcance.dart';
import 'package:flutter/material.dart';

class GestionVuelosPage extends StatefulWidget {
  const GestionVuelosPage({super.key});

  @override
  State<GestionVuelosPage> createState() => _GestionVuelosPageState();
}

class _GestionVuelosPageState extends State<GestionVuelosPage> {
  final VueloService vueloService = VueloService();

  late Future<List<Vuelo>> futureVuelos;
  final _busqueda = TextEditingController();
  String _consulta = '';
  Alcance _alcance = Alcance.todos;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  String get _hoy => DateTime.now().toIso8601String().substring(0, 10);

  void _reload() {
    setState(() {
      futureVuelos = vueloService.getVuelos();
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _abrirFormulario([Vuelo? vuelo]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VueloFormPage(vuelo: vuelo)),
    );
    if (result == true) _reload();
  }

  Future<void> _confirmAndDelete(Vuelo vuelo) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Eliminar vuelo'),
          content: Text(
            '¿Está seguro de que desea eliminar el vuelo '
            '${vuelo.origen} → ${vuelo.destino} del ${vuelo.fecha}? '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await vueloService.deleteVuelo(vuelo.id);
      _showMessage('Vuelo eliminado correctamente.');
      _reload();
    } on SessionExpiredException catch (e) {
      if (mounted) LoginPage.irAlLogin(context, e.message);
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
      _reload();
    } catch (e) {
      _showMessage('Ocurrió un error inesperado: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Config.usuario!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de vuelos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Recargar',
          ),
          const BotonInicio(),
          const BotonCerrarSesion(),
        ],
      ),
      floatingActionButton: usuario.puede('vuelos.crear')
          ? FloatingActionButton(
              onPressed: () => _abrirFormulario(),
              child: const Icon(Icons.add),
            )
          : null,
      body: FutureBuilder<List<Vuelo>>(
        future: futureVuelos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error, onRetry: _reload);
          }

          final todos = snapshot.data ?? [];
          if (todos.isEmpty) {
            return const Center(child: Text('No hay vuelos registrados.'));
          }

          // Los vuelos de días anteriores van en su propia página.
          final proximos = todos
              .where((v) => v.fecha.compareTo(_hoy) >= 0)
              .toList();
          final anteriores = todos
              .where((v) => v.fecha.compareTo(_hoy) < 0)
              .toList();
          final vuelos = proximos
              .where((v) => coincideAlcance(v, _alcance) && coincideBusqueda(v, _consulta))
              .toList();

          return Center(
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
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: FiltroAlcance(
                      valor: _alcance,
                      vuelos: proximos,
                      onChanged: (a) => setState(() => _alcance = a),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${vuelos.length} de ${proximos.length} vuelos desde hoy',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  VuelosAnterioresPage(vuelos: anteriores),
                            ),
                          ),
                          icon: const Icon(Icons.history),
                          label: Text(
                            'Vuelos anteriores (${anteriores.length})',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: vuelos.isEmpty
                        ? Center(
                            child: Text(
                              proximos.isEmpty
                                  ? 'No hay vuelos próximos. Revisa los vuelos anteriores.'
                                  : 'Ningún vuelo coincide con la búsqueda.',
                            ),
                          )
                        : ListView.builder(
                            itemCount: vuelos.length,
                            itemBuilder: (context, index) {
                              final vuelo = vuelos[index];
                              return Card(
                                key: ValueKey(vuelo.id),
                                margin: const EdgeInsets.all(8.0),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.flight),
                                  ),
                                  title: Text(
                                    '${vuelo.origen} → ${vuelo.destino}',
                                  ),
                                  subtitle: Text(
                                    '${vuelo.fecha}   ${vuelo.horaSalida} - ${vuelo.horaLlegada}\n'
                                    '${vuelo.esNacional ? 'Nacional' : 'Internacional'}'
                                    '${vuelo.avion.isEmpty ? '' : ' · ${vuelo.avion}'}\n'
                                    'Precio: \$${vuelo.precio.toStringAsFixed(2)} · '
                                    'Libres: ${vuelo.asientosDisponibles} de ${vuelo.capacidad} (${vuelo.filas} filas)',
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (usuario.puede('vuelos.editar'))
                                        IconButton(
                                          icon: const Icon(Icons.edit),
                                          onPressed: () =>
                                              _abrirFormulario(vuelo),
                                        ),
                                      if (usuario.puede('vuelos.eliminar'))
                                        IconButton(
                                          icon: const Icon(Icons.delete),
                                          onPressed: () =>
                                              _confirmAndDelete(vuelo),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
}
