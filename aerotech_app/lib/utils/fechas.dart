const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _meses = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// "13 nov"
String fechaCorta(String iso) {
  final f = DateTime.parse(iso);
  return '${f.day} ${_meses[f.month - 1]}';
}

/// "Vie, nov 13, 2026"
String fechaLarga(String iso) {
  final f = DateTime.parse(iso);
  return '${_dias[f.weekday - 1]}, ${_meses[f.month - 1]} ${f.day}, ${f.year}';
}

/// "Vie, 13 nov"
String fechaConDia(String iso) {
  final f = DateTime.parse(iso);
  return '${_dias[f.weekday - 1]}, ${f.day} ${_meses[f.month - 1]}';
}
