class Pasajeros {
  final int adultos;
  final int ninos;
  final int infantes;

  const Pasajeros({this.adultos = 1, this.ninos = 0, this.infantes = 0});

  /// Los infantes viajan en brazos de un adulto: no ocupan asiento.
  int get conAsiento => adultos + ninos;

  String get resumen {
    final partes = <String>[
      '$adultos ${adultos == 1 ? 'Adulto' : 'Adultos'}',
      if (ninos > 0) '$ninos ${ninos == 1 ? 'Niño' : 'Niños'}',
      if (infantes > 0) '$infantes ${infantes == 1 ? 'Infante' : 'Infantes'}',
    ];
    return partes.join(', ');
  }
}
