import 'package:aerotech_app/widgets/boton_cerrar_sesion.dart';
import 'package:aerotech_app/models/aeropuerto.dart';
import 'package:aerotech_app/models/vuelo.dart';
import 'package:aerotech_app/pages/login_page.dart';
import 'package:aerotech_app/services/api_service.dart';
import 'package:aerotech_app/services/vuelo_service.dart';
import 'package:aerotech_app/widgets/aeropuerto_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VueloFormPage extends StatefulWidget {
  final Vuelo? vuelo;
  const VueloFormPage({super.key, this.vuelo});

  @override
  State<VueloFormPage> createState() => _VueloFormPageState();
}

class _VueloFormPageState extends State<VueloFormPage> {
  final _formKey = GlobalKey<FormState>();

  final fechaController = TextEditingController();
  final salidaController = TextEditingController();
  final llegadaController = TextEditingController();
  final precioController = TextEditingController();
  final filasController = TextEditingController();

  final VueloService vueloService = VueloService();

  bool _isSaving = false;
  late int _currentVersion;

  List<Aeropuerto> _aeropuertos = [];
  Aeropuerto? _origen;
  Aeropuerto? _destino;
  Object? _errorCarga;
  bool _cargandoAeropuertos = true;
  int _camposKey = 0;

  @override
  void initState() {
    super.initState();
    _currentVersion = widget.vuelo?.version ?? 1;
    if (widget.vuelo != null) _cargar(widget.vuelo!);
    _cargarAeropuertos();
  }

  Future<void> _cargarAeropuertos() async {
    setState(() {
      _cargandoAeropuertos = true;
      _errorCarga = null;
    });
    try {
      final lista = await vueloService.getAeropuertos();
      if (!mounted) return;
      setState(() {
        _aeropuertos = lista;
        final vuelo = widget.vuelo;
        if (vuelo != null) _asignarRuta(vuelo);
        _cargandoAeropuertos = false;
      });
    } on SessionExpiredException catch (e) {
      if (mounted) LoginPage.irAlLogin(context, e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCarga = e;
        _cargandoAeropuertos = false;
      });
    }
  }

  void _asignarRuta(Vuelo vuelo) {
    Aeropuerto? buscar(int id) {
      for (final a in _aeropuertos) {
        if (a.id == id) return a;
      }
      return null;
    }

    _origen = buscar(vuelo.origenId);
    _destino = buscar(vuelo.destinoId);
    _camposKey++;
  }

  void _cargar(Vuelo vuelo) {
    fechaController.text = vuelo.fecha;
    salidaController.text = vuelo.horaSalida;
    llegadaController.text = vuelo.horaLlegada;
    precioController.text = vuelo.precio.toStringAsFixed(2);
    filasController.text = vuelo.filas.toString();
  }

  @override
  void dispose() {
    fechaController.dispose();
    salidaController.dispose();
    llegadaController.dispose();
    precioController.dispose();
    filasController.dispose();
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

  Future<void> _seleccionarFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(fechaController.text) ?? hoy,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 2),
    );
    if (fecha != null) {
      fechaController.text = fecha.toIso8601String().substring(0, 10);
    }
  }

  Future<void> _seleccionarHora(TextEditingController controller) async {
    final partes = controller.text.split(':');
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(partes[0]) ?? 8,
        minute: partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0,
      ),
    );
    if (hora != null) {
      controller.text =
          '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
    }
  }

  String? _validateOrigen(Aeropuerto? value) {
    if (value == null) return 'Seleccione un aeropuerto de la lista.';
    return null;
  }

  String? _validateDestino(Aeropuerto? value) {
    if (value == null) return 'Seleccione un aeropuerto de la lista.';
    if (value == _origen) return 'El destino debe ser distinto al origen.';
    return null;
  }

  String? _validateRequerido(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio.';
    }
    return null;
  }

  String? _validatePrecio(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El precio es obligatorio.';
    }
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) return 'Ingrese un número válido.';
    if (parsed <= 0) return 'El precio debe ser mayor a 0.';
    return null;
  }

  String? _validateFilas(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El número de filas es obligatorio.';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Ingrese un número entero.';
    if (parsed < 1 || parsed > 40) return 'Debe estar entre 1 y 40 filas.';
    return null;
  }

  Future<void> _handleConflict(ConflictException e) async {
    if (!mounted) return;
    final refresh = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Conflicto de datos'),
          content: Text(
            '${e.message}\n\n'
            'Otro usuario cambió este vuelo mientras usted lo editaba.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cerrar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cargar datos actuales'),
            ),
          ],
        ),
      ),
    );

    if (refresh == true && e.current != null && mounted) {
      final actual = Vuelo.fromJson(e.current!);
      setState(() {
        _cargar(actual);
        _asignarRuta(actual);
        _currentVersion = actual.version;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      _showMessage('Revise los campos marcados en rojo.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    final vuelo = Vuelo(
      id: widget.vuelo?.id ?? 0,
      origen: _origen!.ciudad,
      destino: _destino!.ciudad,
      origenId: _origen!.id,
      destinoId: _destino!.id,
      fecha: fechaController.text.trim(),
      horaSalida: salidaController.text.trim(),
      horaLlegada: llegadaController.text.trim(),
      precio: double.parse(precioController.text.trim().replaceAll(',', '.')),
      filas: int.parse(filasController.text.trim()),
      asientosDisponibles: widget.vuelo?.asientosDisponibles ?? 0,
      version: _currentVersion,
    );

    try {
      if (widget.vuelo != null) {
        final actualizado = await vueloService.updateVuelo(vuelo);
        _currentVersion = actualizado.version;
        _showMessage('Vuelo actualizado correctamente.');
      } else {
        await vueloService.createVuelo(vuelo);
        _showMessage('Vuelo creado correctamente.');
      }
      if (mounted) Navigator.pop(context, true);
    } on SessionExpiredException catch (e) {
      if (mounted) LoginPage.irAlLogin(context, e.message);
    } on ConflictException catch (e) {
      await _handleConflict(e);
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
    final isEditing = widget.vuelo != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar vuelo' : 'Nuevo vuelo'),
        actions: const [BotonCerrarSesion()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  if (_cargandoAeropuertos)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    )
                  else if (_errorCarga != null)
                    Column(
                      children: [
                        Text(
                          _errorCarga is ApiException
                              ? (_errorCarga as ApiException).message
                              : 'No se pudieron cargar los aeropuertos.',
                          textAlign: TextAlign.center,
                        ),
                        TextButton.icon(
                          onPressed: _cargarAeropuertos,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    )
                  else ...[
                    AeropuertoField(
                      key: ValueKey('origen$_camposKey'),
                      label: 'Origen',
                      icon: Icons.flight_takeoff,
                      opciones: _aeropuertos,
                      valor: _origen,
                      onChanged: (a) => _origen = a,
                      validator: _validateOrigen,
                    ),
                    const SizedBox(height: 15),
                    AeropuertoField(
                      key: ValueKey('destino$_camposKey'),
                      label: 'Destino',
                      icon: Icons.flight_land,
                      opciones: _aeropuertos,
                      valor: _destino,
                      onChanged: (a) => _destino = a,
                      validator: _validateDestino,
                    ),
                  ],
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: fechaController,
                    readOnly: true,
                    onTap: _seleccionarFecha,
                    decoration: const InputDecoration(
                      labelText: 'Fecha',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validateRequerido,
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: salidaController,
                          readOnly: true,
                          onTap: () => _seleccionarHora(salidaController),
                          decoration: const InputDecoration(
                            labelText: 'Hora salida',
                            prefixIcon: Icon(Icons.schedule),
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateRequerido,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: llegadaController,
                          readOnly: true,
                          onTap: () => _seleccionarHora(llegadaController),
                          decoration: const InputDecoration(
                            labelText: 'Hora llegada',
                            prefixIcon: Icon(Icons.schedule),
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateRequerido,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: precioController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Precio',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validatePrecio,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: filasController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Número de filas',
                      prefixIcon: Icon(Icons.event_seat),
                      border: OutlineInputBorder(),
                      helperText: '6 asientos por fila (A B C | D E F), máximo 40 filas',
                    ),
                    validator: _validateFilas,
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSaving || _cargandoAeropuertos || _errorCarga != null ? null : _guardar,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Actualizar' : 'Guardar'),
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