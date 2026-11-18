import 'package:aerotech_app/config.dart';
import 'package:aerotech_app/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Al vencer el token se cierra la sesión sin esperar ninguna acción ni respuesta del servidor.
    Config.alExpirar = _sesionExpirada;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Config.alExpirar = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) Config.verificarExpiracion();
  }

  void _sesionExpirada() {
    // pushAndRemoveUntil también cierra cualquier diálogo o pantalla abierta.
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Su sesión expiró. Inicie sesión nuevamente.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 8),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AeroTech',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
