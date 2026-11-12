import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/services/reserva_service.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ComprobantePage extends StatefulWidget {
  final int reservaId;
  const ComprobantePage({super.key, required this.reservaId});

  @override
  State<ComprobantePage> createState() => _ComprobantePageState();
}

class _ComprobantePageState extends State<ComprobantePage> {
  final ReservaService reservaService = ReservaService();

  late Future<String> futureXml;
  String? _xml;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      futureXml = reservaService.getComprobante(widget.reservaId);
    });
  }

  Future<void> _copiar() async {
    if (_xml == null) return;
    await Clipboard.setData(ClipboardData(text: _xml!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('XML copiado al portapapeles.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comprobante #${widget.reservaId}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copiar XML',
            onPressed: _copiar,
          ),
          const BotonCerrarSesion(),
        ],
      ),
      body: FutureBuilder<String>(
        future: futureXml,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error, onRetry: _reload);
          }

          _xml = snapshot.data ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  _xml!,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFFA6E3A1),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}