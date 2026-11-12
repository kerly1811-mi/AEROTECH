import 'package:aerotech_app/widgets/boton_inicio.dart';
import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/config.dart';
import 'package:aerotech_app/models/reserva.dart';
import 'package:aerotech_app/pages/comprobante_page.dart';
import 'package:aerotech_app/pages/login_page.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:aerotech_app/services/reserva_service.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';

/// Reservas de un mismo viaje (solo ida: una; ida y vuelta: dos). Comparten comprobante.
class _Viaje {
  final int id;
  final List<Reserva> tramos;

  _Viaje(this.id, this.tramos);

  Reserva get primera => tramos.first;
  bool get confirmado => tramos.any((r) => r.confirmada);
  double get total => tramos.fold<double>(0, (t, r) => t + r.total);

  /// Reserva con la que se cancela el viaje completo.
  Reserva get paraCancelar => tramos.firstWhere((r) => r.confirmada, orElse: () => primera);
}

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

  List<_Viaje> _agrupar(List<Reserva> reservas) {
    final porViaje = <int, List<Reserva>>{};
    for (final r in reservas) {
      porViaje.putIfAbsent(r.viajeId, () => []).add(r);
    }
    return porViaje.entries.map((e) {
      final tramos = [...e.value]
        ..sort((a, b) => '${a.fechaVuelo} ${a.horaSalida}'.compareTo('${b.fechaVuelo} ${b.horaSalida}'));
      return _Viaje(e.key, tramos);
    }).toList();
  }

  bool _puedeCancelar(_Viaje viaje) {
    final usuario = Config.usuario!;
    if (!viaje.confirmado) return false;
    if (viaje.primera.usuarioId == usuario.id && usuario.puede('reservas.cancelar_propias')) {
      return true;
    }
    return usuario.puede('reservas.cancelar_todas');
  }

  Future<void> _confirmAndCancel(_Viaje viaje) async {
    final ruta = viaje.tramos.map((r) => '${r.origen} → ${r.destino}').join(' / ');
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(viaje.tramos.length > 1 ? 'Cancelar viaje' : 'Cancelar reserva'),
          content: Text(
            '¿Está seguro de cancelar el viaje #${viaje.id} ($ruta)? '
            '${viaje.tramos.length > 1 ? 'Se cancelarán la ida y el regreso. ' : ''}'
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
      await reservaService.cancelarReserva(viaje.paraCancelar);
      _showMessage(viaje.tramos.length > 1 ? 'Viaje cancelado correctamente.' : 'Reserva cancelada correctamente.');
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

  String _lineaTramo(Reserva r, String etiqueta) {
    final clase = r.asientos.isNotEmpty && r.asientos.first.clase == 'ejecutiva' ? 'Ejecutiva' : 'Económica';
    final maletas = r.maletasExtra;
    return '$etiqueta · ${r.fechaVuelo} ${r.horaSalida} · ${r.origen} → ${r.destino}\n'
        '    $clase · Asientos: ${r.textoAsientos}'
        '${maletas > 0 ? ' · $maletas maleta(s) extra' : ''}';
  }

  Widget _buildViaje(_Viaje viaje) {
    final varios = viaje.tramos.length > 1;
    final primera = viaje.primera;
    final titulo = varios
        ? '${primera.origen} ⇄ ${primera.destino} · Ida y vuelta'
        : '${primera.origen} → ${primera.destino}';

    return Card(
      key: ValueKey(viaje.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(
          viaje.confirmado ? Icons.check_circle : Icons.cancel,
          color: viaje.confirmado ? Colors.green : Colors.red,
        ),
        title: Text(titulo),
        subtitle: Text(
          'Viaje #${viaje.id}\n'
          '${[
            for (var i = 0; i < viaje.tramos.length; i++)
              _lineaTramo(viaje.tramos[i], varios ? (i == 0 ? 'Ida' : 'Regreso') : 'Vuelo'),
          ].join('\n')}\n'
          'Total: \$${viaje.total.toStringAsFixed(2)}'
          '${widget.todas ? '\nCliente: ${primera.cliente}' : ''}',
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
                  builder: (context) => ComprobantePage(reservaId: primera.id),
                ),
              ),
            ),
            if (_puedeCancelar(viaje))
              IconButton(
                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                tooltip: varios ? 'Cancelar viaje' : 'Cancelar reserva',
                onPressed: () => _confirmAndCancel(viaje),
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
          const BotonInicio(),
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

          final viajes = _agrupar(snapshot.data ?? []);
          if (viajes.isEmpty) {
            return const Center(child: Text('No hay reservas registradas.'));
          }

          return ListView.builder(
            itemCount: viajes.length,
            itemBuilder: (context, index) => _buildViaje(viajes[index]),
          );
        },
      ),
    );
  }
}
