import 'package:aerotech_app/models/aeropuerto.dart';
import 'package:flutter/material.dart';

/// Campo con buscador que solo permite elegir un aeropuerto de la lista.
/// Si el usuario edita el texto después de elegir, la selección se descarta.
class AeropuertoField extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Aeropuerto> opciones;
  final Aeropuerto? valor;
  final ValueChanged<Aeropuerto?> onChanged;
  final String? Function(Aeropuerto?)? validator;
  final bool dense;

  const AeropuertoField({
    super.key,
    required this.label,
    required this.icon,
    required this.opciones,
    required this.valor,
    required this.onChanged,
    this.validator,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<Aeropuerto>(
          initialValue: TextEditingValue(text: valor?.etiqueta ?? ''),
          displayStringForOption: (a) => a.etiqueta,
          optionsBuilder: (texto) {
            final consulta = Aeropuerto.normalizar(texto.text.trim());
            if (consulta.isEmpty) return opciones;
            return opciones.where((a) => a.busqueda.contains(consulta));
          },
          onSelected: onChanged,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                suffixIcon: const Icon(Icons.arrow_drop_down),
                border: const OutlineInputBorder(),
                isDense: dense,
              ),
              onChanged: (texto) {
                if (valor != null && texto != valor!.etiqueta) onChanged(null);
              },
              validator: (_) => validator != null
                  ? validator!(valor)
                  : (valor == null ? 'Seleccione un aeropuerto de la lista.' : null),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 280,
                    maxWidth: constraints.maxWidth < 280 ? 280 : constraints.maxWidth,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final a = options.elementAt(i);
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.local_airport),
                        title: Text(
                          a.etiqueta,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${a.nombre} · ${a.pais}'),
                        onTap: () => onSelected(a),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
