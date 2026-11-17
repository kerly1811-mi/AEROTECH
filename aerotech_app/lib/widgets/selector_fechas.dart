import 'package:flutter/material.dart';

class SeleccionFechas {
  final DateTime ida;
  final DateTime? regreso;

  const SeleccionFechas(this.ida, this.regreso);
}

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];
const _mesesCortos = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _diasCortos = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _letrasDias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendario de fechas de viaje, en español y con instrucciones paso a paso.
/// Con [idaYVuelta] se eligen dos fechas (ida y regreso); si no, una sola.
Future<SeleccionFechas?> mostrarSelectorFechas(
  BuildContext context, {
  required bool idaYVuelta,
  DateTime? ida,
  DateTime? regreso,
  DateTime? primera,
}) {
  final hoy = _soloFecha(DateTime.now());
  return showDialog<SeleccionFechas>(
    context: context,
    builder: (context) => _SelectorFechas(
      idaYVuelta: idaYVuelta,
      ida: ida,
      regreso: regreso,
      primera: _soloFecha(primera ?? hoy),
    ),
  );
}

class _SelectorFechas extends StatefulWidget {
  final bool idaYVuelta;
  final DateTime? ida;
  final DateTime? regreso;
  final DateTime primera;

  const _SelectorFechas({
    required this.idaYVuelta,
    required this.ida,
    required this.regreso,
    required this.primera,
  });

  @override
  State<_SelectorFechas> createState() => _SelectorFechasState();
}

class _SelectorFechasState extends State<_SelectorFechas> {
  DateTime? _ida;
  DateTime? _regreso;
  late DateTime _mes;

  @override
  void initState() {
    super.initState();
    _ida = widget.ida == null ? null : _soloFecha(widget.ida!);
    _regreso = widget.idaYVuelta && widget.regreso != null ? _soloFecha(widget.regreso!) : null;
    final base = _ida ?? widget.primera;
    _mes = DateTime(base.year, base.month);
  }

  bool get _completo => _ida != null && (!widget.idaYVuelta || _regreso != null);

  DateTime get _ultimoMes => DateTime(widget.primera.year + 2, widget.primera.month);

  bool get _puedeRetroceder => _mes.isAfter(DateTime(widget.primera.year, widget.primera.month));
  bool get _puedeAvanzar => _mes.isBefore(_ultimoMes);

  void _tocar(DateTime d) {
    setState(() {
      if (!widget.idaYVuelta) {
        _ida = d;
      } else if (_ida == null || _regreso != null) {
        _ida = d;
        _regreso = null;
      } else if (d.isBefore(_ida!)) {
        _ida = d;
      } else {
        _regreso = d;
      }
    });
  }

  String _texto(DateTime? d) {
    if (d == null) return '—';
    return '${_diasCortos[d.weekday - 1]}, ${d.day} ${_mesesCortos[d.month - 1]}';
  }

  Widget _tarjeta(String titulo, DateTime? fecha, {required bool activa, required String pista}) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: activa ? colors.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: activa ? colors.primary : Colors.grey.shade400,
            width: activa ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 2),
            Text(
              fecha == null ? pista : _texto(fecha),
              style: TextStyle(
                fontSize: fecha == null ? 13 : 17,
                fontWeight: fecha == null ? FontWeight.normal : FontWeight.bold,
                color: fecha == null ? Colors.grey.shade600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dia(DateTime d) {
    final colors = Theme.of(context).colorScheme;
    final deshabilitado = d.isBefore(widget.primera);
    final esIda = _ida != null && d == _ida;
    final esRegreso = _regreso != null && d == _regreso;
    final enRango = widget.idaYVuelta &&
        _ida != null &&
        _regreso != null &&
        d.isAfter(_ida!) &&
        d.isBefore(_regreso!);
    final conRango = widget.idaYVuelta && _ida != null && _regreso != null && _ida != _regreso;
    final esHoy = d == _soloFecha(DateTime.now());
    final seleccionado = esIda || esRegreso;
    final banda = colors.primaryContainer;

    return GestureDetector(
      onTap: deshabilitado ? null : () => _tocar(d),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Banda del rango entre ida y regreso
            if (enRango) Positioned.fill(child: Container(color: banda)),
            if (esIda && conRango)
              Positioned.fill(child: Row(children: [const Spacer(), Expanded(child: Container(color: banda))])),
            if (esRegreso && conRango)
              Positioned.fill(child: Row(children: [Expanded(child: Container(color: banda)), const Spacer()])),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: seleccionado ? colors.primary : null,
                border: esHoy && !seleccionado ? Border.all(color: colors.primary, width: 1.5) : null,
              ),
              child: Text(
                '${d.day}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                  color: seleccionado
                      ? colors.onPrimary
                      : (deshabilitado ? Colors.grey.shade400 : null),
                  decoration: deshabilitado ? TextDecoration.none : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cuadricula() {
    final primerDia = DateTime(_mes.year, _mes.month, 1);
    final diasMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final vacios = primerDia.weekday - 1;
    final celdas = <Widget>[
      for (var i = 0; i < vacios; i++) const SizedBox(height: 44),
      for (var d = 1; d <= diasMes; d++) _dia(DateTime(_mes.year, _mes.month, d)),
    ];
    while (celdas.length % 7 != 0) {
      celdas.add(const SizedBox(height: 44));
    }
    return Column(
      children: [
        for (var i = 0; i < celdas.length; i += 7) Row(children: [for (final c in celdas.sublist(i, i + 7)) Expanded(child: c)]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pidiendoIda = _ida == null || _regreso != null || !widget.idaYVuelta;
    final mes = _meses[_mes.month - 1];

    final String ayuda;
    if (!widget.idaYVuelta) {
      ayuda = 'Toca en el calendario el día en que quieres viajar.';
    } else if (_ida == null) {
      ayuda = 'Paso 1: toca el día de IDA.';
    } else if (_regreso == null) {
      ayuda = 'Paso 2: ahora toca el día de REGRESO.';
    } else {
      ayuda = '¡Listo! Si quieres cambiarlas, toca otro día.';
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.idaYVuelta ? '¿Cuándo viajas?' : '¿Qué día viajas?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _completo ? Colors.green.shade50 : colors.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _completo ? Icons.check_circle : Icons.touch_app,
                      color: _completo ? Colors.green.shade700 : colors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(ayuda, style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _tarjeta('IDA', _ida, activa: pidiendoIda, pista: 'Elige un día'),
                  if (widget.idaYVuelta) ...[
                    const SizedBox(width: 10),
                    _tarjeta('REGRESO', _regreso, activa: !pidiendoIda, pista: 'Elige un día'),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: _puedeRetroceder ? () => setState(() => _mes = DateTime(_mes.year, _mes.month - 1)) : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Mes anterior',
                  ),
                  Expanded(
                    child: Text(
                      '${mes[0].toUpperCase()}${mes.substring(1)} ${_mes.year}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: _puedeAvanzar ? () => setState(() => _mes = DateTime(_mes.year, _mes.month + 1)) : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Mes siguiente',
                  ),
                ],
              ),
              Row(
                children: [
                  for (final l in _letrasDias)
                    Expanded(
                      child: Center(
                        child: Text(l, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              _cuadricula(),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _completo ? () => Navigator.pop(context, SeleccionFechas(_ida!, _regreso)) : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar fechas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
