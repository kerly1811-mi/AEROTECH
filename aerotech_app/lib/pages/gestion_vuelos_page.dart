import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/config.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/pages/login_page.dart';
import 'package:aerotech_app/pages/vuelo_form_page.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';

class GestionVuelosPage extends StatefulWidget {
  const GestionVuelosPage({super.key});

  @override
  State<GestionVuelosPage> createState() => _GestionVuelosPageState();
}

class _GestionVuelosPageState extends State<GestionVuelosPage> {
  final VueloService vueloService = VueloService();

  late Future<List<Vuelo>> futureVuelos;

  @override
  void initState() {
    super.initState();
    _reload();
  }

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

          final vuelos = snapshot.data ?? [];
          if (vuelos.isEmpty) {
            return const Center(child: Text('No hay vuelos registrados.'));
          }

          return ListView.builder(
            itemCount: vuelos.length,
            itemBuilder: (context, index) {
              final vuelo = vuelos[index];
              return Card(
                key: ValueKey(vuelo.id),
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.flight)),
                  title: Text('${vuelo.origen} → ${vuelo.destino}'),
                  subtitle: Text(
                    '${vuelo.fecha}   ${vuelo.horaSalida} - ${vuelo.horaLlegada}\n'
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
                          onPressed: () => _abrirFormulario(vuelo),
                        ),
                      if (usuario.puede('vuelos.eliminar'))
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _confirmAndDelete(vuelo),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}