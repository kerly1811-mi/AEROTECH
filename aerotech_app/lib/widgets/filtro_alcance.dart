import 'package:aerotech_app/models/vuelo.dart';
import 'package:flutter/material.dart';

enum Alcance { todos, nacionales, internacionales }

bool coincideAlcance(Vuelo v, Alcance a) {
  switch (a) {
    case Alcance.todos:
      return true;
    case Alcance.nacionales:
      return v.esNacional;
    case Alcance.internacionales:
      return !v.esNacional;
  }
}

/// Filtro Todos / Nacionales / Internacionales, con la cantidad de vuelos de cada uno.
class FiltroAlcance extends StatelessWidget {
  final Alcance valor;
  final List<Vuelo> vuelos;
  final ValueChanged<Alcance> onChanged;

  const FiltroAlcance({super.key, required this.valor, required this.vuelos, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    int cuantos(Alcance a) => vuelos.where((v) => coincideAlcance(v, a)).length;

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<Alcance>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: Alcance.todos,
            icon: const Icon(Icons.public),
            label: Text('Todos (${cuantos(Alcance.todos)})'),
          ),
          ButtonSegment(
            value: Alcance.nacionales,
            icon: const Icon(Icons.flag),
            label: Text('Nacionales (${cuantos(Alcance.nacionales)})'),
          ),
          ButtonSegment(
            value: Alcance.internacionales,
            icon: const Icon(Icons.flight),
            label: Text('Internacionales (${cuantos(Alcance.internacionales)})'),
          ),
        ],
        selected: {valor},
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}
