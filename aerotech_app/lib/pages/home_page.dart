import 'package:aerotech_app/config.dart';
import 'package:aerotech_app/pages/gestion_vuelos_page.dart';
import 'package:aerotech_app/pages/login_page.dart';
import 'package:aerotech_app/pages/reservas_page.dart';
import 'package:aerotech_app/pages/usuarios_page.dart';
import 'package:aerotech_app/pages/vuelos_page.dart';
import 'package:aerotech_app/services/auth_service.dart';
import 'package:flutter/material.dart';

class _Opcion {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final String permiso;

  const _Opcion(this.titulo, this.descripcion, this.icono, this.permiso);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService authService = AuthService();

  static const _opciones = [
    _Opcion('Buscar vuelos', 'Elige tu vuelo y tus asientos', Icons.flight, 'reservas.crear'),
    _Opcion('Mis reservas', 'Consulta, cancela y descarga tu comprobante', Icons.event_note, 'reservas.ver_propias'),
    _Opcion('Gestión de vuelos', 'Crea y edita vuelos, horarios y precios', Icons.edit_calendar, 'vuelos.crear'),
    _Opcion('Reservas', 'Todas las reservas del sistema', Icons.list_alt, 'reservas.ver_todas'),
    _Opcion('Usuarios', 'Activa o desactiva cuentas', Icons.group, 'usuarios.ver'),
  ];

  Future<void> _confirmAndLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Está seguro de que desea cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, salir'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    await authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void _abrir(_Opcion opcion) {
    final Widget pagina;
    switch (opcion.permiso) {
      case 'reservas.crear':
        pagina = const VuelosPage();
      case 'reservas.ver_propias':
        pagina = const ReservasPage();
      case 'vuelos.crear':
        pagina = const GestionVuelosPage();
      case 'reservas.ver_todas':
        pagina = const ReservasPage(todas: true);
      case 'usuarios.ver':
        pagina = const UsuariosPage();
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (context) => pagina));
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Config.usuario!;
    final opciones = _opciones.where((o) => usuario.puede(o.permiso)).toList();
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AeroTech'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _confirmAndLogout,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Hola, ${usuario.nombre}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Chip(
                avatar: Icon(
                  usuario.esAdmin ? Icons.admin_panel_settings : Icons.person,
                  size: 18,
                ),
                label: Text(usuario.esAdmin ? 'Administrador' : 'Cliente'),
              ),
              const SizedBox(height: 16),
              ...opciones.map(
                (opcion) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: colors.primaryContainer,
                      child: Icon(opcion.icono, color: colors.primary),
                    ),
                    title: Text(opcion.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(opcion.descripcion),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _abrir(opcion),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
