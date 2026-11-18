import 'package:aerotech_app/pages/home_page.dart';
import 'package:aerotech_app/pages/registro_page.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:aerotech_app/services/auth_service.dart';
import 'package:aerotech_app/widgets/logo_aerotech.dart';
import 'package:aerotech_app/widgets/ruta_mundial.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static void irAlLogin(BuildContext context, String message) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final correoController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService authService = AuthService();

  bool _isLoading = false;
  bool _ocultar = true;

  @override
  void dispose() {
    correoController.dispose();
    passwordController.dispose();
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

  String? _validateCorreo(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo es obligatorio.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es obligatoria.';
    }
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await authService.login(
        correoController.text.trim(),
        passwordController.text,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on ApiException catch (e) {
      _showMessage(e.message, isError: true);
    } catch (e) {
      _showMessage('Ocurrió un error inesperado: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _formulario() {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Bienvenido',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Inicia sesión para reservar tu vuelo', style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 24),
              TextFormField(
                controller: correoController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: const Icon(Icons.alternate_email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                validator: _validateCorreo,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: _ocultar,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  suffixIcon: IconButton(
                    icon: Icon(_ocultar ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _ocultar = !_ocultar),
                  ),
                ),
                validator: _validatePassword,
                onFieldSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2A8A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Iniciar sesión', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'La primera conexión puede tardar hasta un minuto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegistroPage()),
                ),
                child: Text('¿No tienes cuenta? Regístrate', style: TextStyle(color: colors.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _portada({required bool ancho}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: ancho ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        LogoAeroTech(tamano: ancho ? 72 : 56, claro: true),
        const SizedBox(height: 14),
        Text(
          'Tu próximo vuelo,\na un toque.',
          textAlign: ancho ? TextAlign.start : TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: ancho ? 40 : 22,
            fontWeight: FontWeight.w300,
            height: 1.15,
          ),
        ),
        if (ancho) ...[
          const SizedBox(height: 10),
          const Text(
            'Compara destinos, elige tu asiento y viaja con un solo comprobante.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 28),
          const SizedBox(
            width: 520,
            child: RutaMundial(
              origenLat: -0.1292,
              origenLon: -78.3575,
              destinoLat: 40.4983,
              destinoLon: -3.5676,
              origenCodigo: 'UIO',
              destinoCodigo: 'MAD',
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF061A47), Color(0xFF0B3B9E), Color(0xFF1565C0)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final ancho = c.maxWidth >= 900;

            if (ancho) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(child: _portada(ancho: true)),
                      const SizedBox(width: 64),
                      SizedBox(width: 420, child: _formulario()),
                    ],
                  ),
                ),
              );
            }

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _portada(ancho: false),
                      const SizedBox(height: 24),
                      _formulario(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
