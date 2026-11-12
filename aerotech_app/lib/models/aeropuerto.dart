class Aeropuerto {
  final int id;
  final String codigo;
  final String ciudad;
  final String nombre;
  final String pais;

  const Aeropuerto({
    required this.id,
    required this.codigo,
    required this.ciudad,
    required this.nombre,
    required this.pais,
  });

  factory Aeropuerto.fromJson(Map<String, dynamic> json) {
    return Aeropuerto(
      id: (json['id'] as num).toInt(),
      codigo: json['codigo'] ?? '',
      ciudad: json['ciudad'] ?? '',
      nombre: json['nombre'] ?? '',
      pais: json['pais'] ?? '',
    );
  }

  /// Ej.: "Quito (UIO)"
  String get etiqueta => '$ciudad ($codigo)';

  /// Texto en minúsculas y sin tildes para buscar por ciudad, código, país o nombre.
  String get busqueda => normalizar('$ciudad $codigo $pais $nombre');

  static String normalizar(String texto) {
    const con = 'áàäâéèëêíìïîóòöôúùüûñ';
    const sin = 'aaaaeeeeiiiioooouuuun';
    var resultado = texto.toLowerCase();
    for (var i = 0; i < con.length; i++) {
      resultado = resultado.replaceAll(con[i], sin[i]);
    }
    return resultado;
  }

  @override
  bool operator ==(Object other) => other is Aeropuerto && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
