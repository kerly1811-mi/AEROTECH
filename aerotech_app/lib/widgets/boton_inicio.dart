import 'package:flutter/material.dart';

/// Casita para volver a la pantalla de inicio desde cualquier página.
class BotonInicio extends StatelessWidget {
  const BotonInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home),
      tooltip: 'Ir al inicio',
      onPressed: () => Navigator.popUntil(context, (ruta) => ruta.isFirst),
    );
  }
}
