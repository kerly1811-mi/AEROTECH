import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/config.dart';
import 'package:aerotech_app/models/reserva.dart';
import 'package:aerotech_app/pages/comprobante_page.dart';
import 'package:aerotech_app/pages/login_page.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:aerotech_app/services/reserva_service.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';

class ReservasPage extends StatefulWidget {
  final bool todas;
  const ReservasPage({super.key, this.todas = false});

  @override
  State<ReservasPage> createState() => _ReservasPageState();
}

class _ReservasPageState extends State<ReservasPage> {
  final ReservaService reservaService = ReservaService();

  late Future<List<Reserva>> futureReservas;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      futureReservas = widget.todas
          ? reservaService.getTodasReservas()
          : reservaService.getMisReservas();
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

  bool _puedeCancelar(Reserva reserva) {
    final usuario = Config.usuario!;
    if (!reserva.confirmada) return false;
    if (reserva.usuarioId == usuario.id && usuario.puede('reservas.cancelar_propias')) {
      return true;
    }
    return usuario.puede('reservas.cancelar_todas');
  }

  Future<void> _confirmAndCancel(Reserva reserva) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Cancelar reserva'),
          content: Text(
            '¿Está seguro de cancelar la reserva #${reserva.id} '
            '(${reserva.origen} → ${reserva.destino})? '
            'Los asientos se liberarán.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, cancelar'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await reservaService.cancelarReserva(reserva);
      _showMessage('Reserva cancelada correctamente.');
      _reload();
    } on SessionExpiredException catch (e) {
      if (mounted) LoginPage.irAlLogin(context, e.message);
    } on ConflictException catch (e) {
      _showMessage('${e.message}. Se recargaron los datos.', isError: true);
      _reload();
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
      _reload();
    } catch (e) {
      _showMessage('Ocurrió un error inesperado: $e', isError: true);
    }
  }

  Widget _buildReserva(Reserva reserva) {
    return Card(
      key: ValueKey(reserva.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(
          reserva.confirmada ? Icons.check_circle : Icons.cancel,
          color: reserva.confirmada ? Colors.green : Colors.red,
        ),
        title: Text('${reserva.origen} → ${reserva.destino}'),
        subtitle: Text(
          'Reserva #${reserva.id} · ${reserva.fechaVuelo} ${reserva.horaSalida}\n'
          'Asientos: ${reserva.textoAsientos} · Total: \$${reserva.total.toStringAsFixed(2)}'
          '${widget.todas ? '\nCliente: ${reserva.cliente}' : ''}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Comprobante XML',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ComprobantePage(reservaId: reserva.id),
                ),
              ),
            ),
            if (_puedeCancelar(reserva))
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                tooltip: 'Cancelar reserva',
                onPressed: () => _confirmAndCancel(reserva),
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
        title: Text(widget.todas ? 'Todas las reservas' : 'Mis reservas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Recargar',
          ),
          const BotonCerrarSesion(),
        ],
      ),
      body: FutureBuilder<List<Reserva>>(
        future: futureReservas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error, onRetry: _reload);
          }

          final reservas = snapshot.data ?? [];
          if (reservas.isEmpty) {
            return const Center(child: Text('No hay reservas registradas.'));
          }

          return ListView.builder(
            itemCount: reservas.length,
            itemBuilder: (context, index) => _buildReserva(reservas[index]),
          );
        },
      ),
    );
  }
}