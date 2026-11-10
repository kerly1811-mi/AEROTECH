import 'package:aerotech_app/services/api_service.dart';
import 'package:aerotech_app/services/auth_service.dart';
import 'package:flutter/material.dart';

class RegistroPage extends StatefulWidget {
  const RegistroPage({super.key});

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final _formKey = GlobalKey<FormState>();
  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmarController = TextEditingController();
  final AuthService authService = AuthService();

  bool _isSaving = false;

  static final RegExp _correoValido = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
  static final RegExp _nombreValido = RegExp(r'^[a-zA-ZÀ-ÿ ]+$');

  @override
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    passwordController.dispose();
    confirmarController.dispose();
    super.dispose();
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

  String? _validateNombre(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El nombre es obligatorio.';
    }
    if (value.trim().length < 3) {
      return 'Mínimo 3 caracteres.';
    }
    if (!_nombreValido.hasMatch(value.trim())) {
      return 'Solo se permiten letras y espacios.';
    }
    return null;
  }

  String? _validateCorreo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo es obligatorio.';
    }
    if (!_correoValido.hasMatch(value.trim())) {
      return 'Ingrese un correo válido.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria.';
    }
    if (value.length < 6) {
      return 'Mínimo 6 caracteres.';
    }
    return null;
  }

  String? _validateConfirmar(String? value) {
    if (value != passwordController.text) {
      return 'Las contraseñas no coinciden.';
    }
    return null;
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Revise los campos marcados en rojo.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final mensaje = await authService.registrar(
        nombreController.text.trim(),
        correoController.text.trim(),
        passwordController.text,
      );
      _showMessage(mensaje);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
    } catch (e) {
      _showMessage('Ocurrió un error inesperado: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: nombreController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                      prefixIcon: Icon(Icons.badge),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateNombre,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateCorreo,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                      helperText: 'Mínimo 6 caracteres',
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: confirmarController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateConfirmar,
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _registrar,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Registrarse'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}