import 'package:aerotech_app/config.dart';
import 'package:aerotech_app/models/usuario.dart';
import 'package:aerotech_app/pages/login_page.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:aerotech_app/services/usuario_service.dart';
import 'package:aerotech_app/widgets/error_view.dart';
import 'package:flutter/material.dart';

enum _EstadoFilter { todos, activos, inactivos }

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  final UsuarioService usuarioService = UsuarioService();

  late Future<List<Usuario>> futureUsuarios;
  _EstadoFilter _estadoFilter = _EstadoFilter.todos;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      futureUsuarios = usuarioService.getUsuarios();
    });
  }

  List<Usuario> _applyFilter(List<Usuario> usuarios) {
    switch (_estadoFilter) {
      case _EstadoFilter.activos:
        return usuarios.where((u) => u.activo).toList();
      case _EstadoFilter.inactivos:
        return usuarios.where((u) => !u.activo).toList();
      case _EstadoFilter.todos:
        return usuarios;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _confirmAndCambiarEstado(Usuario usuario) async {
    final activar = !usuario.activo;

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(activar ? 'Activar usuario' : 'Desactivar usuario'),
          content: Text(
            activar
                ? '¿Desea activar a "${usuario.nombre}"? Podrá iniciar sesión nuevamente.'
                : '¿Desea desactivar a "${usuario.nombre}"? '
                    'Se cerrará su sesión y no podrá ingresar al sistema.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: activar ? Colors.green : Colors.red,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(activar ? 'Sí, activar' : 'Sí, desactivar'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final mensaje = await usuarioService.cambiarEstado(usuario.id, activar);
      _showMessage(mensaje);
      _reload();
    } on SessionExpiredException catch (e) {
      if (mounted) LoginPage.irAlLogin(context, e.message);
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
      _reload();
    } catch (e) {
      _showMessage('Ocurrió un error inesperado: $e', isError: true);
    }
  }

  Widget _buildUsuario(Usuario usuario) {
    final esYo = usuario.id == Config.usuario!.id;
    final color = usuario.esAdmin ? Colors.purple : Colors.blue;

    return Card(
      key: ValueKey(usuario.id),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            usuario.esAdmin ? Icons.admin_panel_settings : Icons.person,
            color: color,
          ),
        ),
        title: Text(esYo ? '${usuario.nombre} (tú)' : usuario.nombre),
        subtitle: Text(
          '${usuario.correo}\n'
          '${usuario.esAdmin ? 'Administrador' : 'Cliente · ${usuario.reservasActivas} reserva(s) activa(s)'}',
        ),
        isThreeLine: true,
        trailing: esYo
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    usuario.activo ? 'Activo' : 'Inactivo',
                    style: TextStyle(
                      color: usuario.activo ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                  Switch(
                    value: usuario.activo,
                    onChanged: Config.usuario!.puede('usuarios.gestionar')
                        ? (_) => _confirmAndCambiarEstado(usuario)
                        : null,
                  ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          PopupMenuButton<_EstadoFilter>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar',
            initialValue: _estadoFilter,
            onSelected: (value) => setState(() => _estadoFilter = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _EstadoFilter.todos, child: Text('Todos')),
              PopupMenuItem(value: _EstadoFilter.activos, child: Text('Activos')),
              PopupMenuItem(value: _EstadoFilter.inactivos, child: Text('Inactivos')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: FutureBuilder<List<Usuario>>(
        future: futureUsuarios,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error, onRetry: _reload);
          }

          final todos = snapshot.data ?? [];
          final usuarios = _applyFilter(todos);

          if (todos.isEmpty) {
            return const Center(child: Text('No hay usuarios registrados.'));
          }
          if (usuarios.isEmpty) {
            return const Center(child: Text('No hay usuarios que coincidan con el filtro.'));
          }

          return ListView.builder(
            itemCount: usuarios.length,
            itemBuilder: (context, index) => _buildUsuario(usuarios[index]),
          );
        },
      ),
    );
  }
}
