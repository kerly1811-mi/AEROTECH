import 'package:flutter/material.dart';

/// Campo de búsqueda con botón para borrar.
class BuscadorVuelos extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  const BuscadorVuelos({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Buscar por ciudad, código, país, fecha, hora o precio',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Borrar búsqueda',
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
