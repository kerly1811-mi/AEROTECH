class Usuario {
  final int id;
  final String nombre;
  final String correo;
  final String rol;
  final bool activo;
  final int reservasActivas;
  final List<String> permisos;

  Usuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    this.activo = true,
    this.reservasActivas = 0,
    this.permisos = const [],
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] ?? '',
      correo: json['correo'] ?? '',
      rol: json['rol'] ?? 'cliente',
      activo: json['activo'] as bool? ?? true,
      reservasActivas: (json['reservas_activas'] as num? ?? 0).toInt(),
      permisos: List<String>.from(json['permisos'] ?? []),
    );
  }

  bool get esAdmin => rol == 'admin';

  bool puede(String permiso) => permisos.contains(permiso);
}
