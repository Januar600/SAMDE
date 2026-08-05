import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/drawer_menu.dart';

class RegistrarEgresoPage extends StatefulWidget {
  const RegistrarEgresoPage({super.key});

  @override
  State<RegistrarEgresoPage> createState() => _RegistrarEgresoPageState();
}

class _RegistrarEgresoPageState extends State<RegistrarEgresoPage> {
  // ── USUARIO ────────────────────────────────────────────────
  late String username;
  late int usuarioId;
  late String sector;
  late String rol;

  // ── FORMULARIO ─────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _numeroEgresoController = TextEditingController();
  final _fechaEgresoController = TextEditingController();
  final _observacionController = TextEditingController();
  final _objetoContratoController = TextEditingController();
  final _searchController = TextEditingController();

  // ── CONTROLADORES POR FILA (cantidad a egresar) ────────────
  List<TextEditingController> _cantidadControllers = [];

  // ── VARIABLES DEL FORMULARIO ───────────────────────────────
  String? _anioSeleccionado;
  int? _contratoSeleccionado;
  String _contratoNumero = '';
  static const int BODEGA_FIJA_ID = 2;
  static const String BODEGA_FIJA_NOMBRE = 'SAMDE';

  // ── DATOS ──────────────────────────────────────────────────
  List<String> _aniosDisponibles = [];
  List<Map<String, dynamic>> _contratosDisponibles = [];
  List<Map<String, dynamic>> _itemsContrato = [];
  List<Map<String, dynamic>> _detallesEgreso = [];
  List<Map<String, dynamic>> _egresos = [];
  List<Map<String, dynamic>> _egresosFiltrados = [];
  String _searchQuery = '';

  // ── ESTADOS ───────────────────────────────────────────────
  bool _cargando = false;
  bool _mostrandoLista = false;
  bool _modoEdicion = false;
  int? _egresoEditandoId;

  static const String _baseUrl = 'http://localhost/samde_db/api';

  // ── CICLO DE VIDA ──────────────────────────────────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
    username = map['username'] ?? 'Usuario';
    usuarioId = map['usuario_id'] ?? 1;
    sector = map['sector'] ?? 'No Asignado';
    rol = map['rol'] ?? 'consulta';
  }

  @override
  void initState() {
    super.initState();
    _cargarAnios();
    _cargarEgresos();
    _searchController.addListener(_filtrarEgresos);
  }

  void _inicializarControllersCantidad() {
    for (final c in _cantidadControllers) {
      c.dispose();
    }
    _cantidadControllers = _detallesEgreso.map((detalle) {
      final cantidad = _modoEdicion
          ? (detalle['cantidad_adicional'] ?? 0.0)
          : (detalle['cantidad_egresada'] ?? 0.0);
      return TextEditingController(
        text: cantidad == 0.0 ? '' : _formatearNumero(cantidad),
      );
    }).toList();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha != null) ctrl.text = fecha.toIso8601String().substring(0, 10);
  }

  String _formatearNumero(dynamic valor) {
    if (valor == null) return '0';
    final double n = valor is double
        ? valor
        : double.tryParse(valor.toString()) ?? 0;
    return n == n.truncateToDouble()
        ? n.truncate().toString()
        : n.toStringAsFixed(2);
  }

  String _formatearConPuntos(dynamic valor) {
    if (valor == null) return '0';
    final double n = valor is double
        ? valor
        : double.tryParse(valor.toString()) ?? 0;
    final String s = n.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '').trim()) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  void _filtrarEgresos() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _egresosFiltrados = _searchQuery.isEmpty
          ? List.from(_egresos)
          : _egresos.where((e) {
              return (e['numero_egreso'] ?? '').toLowerCase().contains(
                    _searchQuery,
                  ) ||
                  (e['bodega_nombre'] ?? '').toLowerCase().contains(
                    _searchQuery,
                  ) ||
                  (e['usuario_nombre'] ?? '').toLowerCase().contains(
                    _searchQuery,
                  ) ||
                  (e['observacion'] ?? '').toLowerCase().contains(_searchQuery);
            }).toList();
    });
  }

  bool _validarStock() {
    final itemsConCantidad = _detallesEgreso.where((d) {
      final val = _modoEdicion
          ? _toDouble(d['cantidad_adicional'])
          : _toDouble(d['cantidad_egresada']);
      return val > 0;
    }).toList();

    if (itemsConCantidad.isEmpty) {
      _snack('Debe egresar al menos un item con cantidad > 0', Colors.orange);
      return false;
    }

    for (final detalle in itemsConCantidad) {
      final double stock = _toDouble(detalle['stock_disponible']);
      final double baseEgresada = _modoEdicion
          ? _toDouble(detalle['cantidad_egresada'])
          : 0.0;
      final double adicional = _modoEdicion
          ? _toDouble(detalle['cantidad_adicional'])
          : _toDouble(detalle['cantidad_egresada']);
      final double totalProyectado = baseEgresada + adicional;

      if (_modoEdicion) {
        if (adicional > stock) {
          _snack(
            '⚠️ Stock insuficiente en "${detalle['nombre_item']}". Disponible: ${_formatearNumero(stock)}, Solicitado (adicional): ${_formatearNumero(adicional)}',
            Colors.red,
          );
          return false;
        }
      } else {
        if (totalProyectado > stock) {
          _snack(
            '⚠️ Stock insuficiente en "${detalle['nombre_item']}". Disponible: ${_formatearNumero(stock)}, Solicitado: ${_formatearNumero(totalProyectado)}',
            Colors.red,
          );
          return false;
        }
      }
    }
    return true;
  }

  void _cargarAnios() {
    final now = DateTime.now().year;
    _aniosDisponibles = {
      (now - 2).toString(),
      (now - 1).toString(),
      ...List.generate(10, (i) => (now + i).toString()),
    }.toList()..sort();
  }

  Future<void> _cargarContratosPorAnio(String anio) async {
    setState(() {
      _cargando = true;
      _contratosDisponibles = [];
      _itemsContrato = [];
      _detallesEgreso = [];
      _objetoContratoController.clear();
      _contratoNumero = '';
    });
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/contratos/listar_contrato.php'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        final todos = List<Map<String, dynamic>>.from(data['data'] ?? []);
        setState(() {
          _contratosDisponibles = todos
              .where((c) => (c['fecha_inicio'] ?? '').startsWith(anio))
              .toList();
        });
        if (_contratosDisponibles.isEmpty) {
          _snack('No hay contratos para el año $anio', Colors.orange);
        }
      }
    } catch (e) {
      _snack('Error cargando contratos: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarTodosLosContratos() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/contratos/listar_contrato.php'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        setState(() {
          _contratosDisponibles = List<Map<String, dynamic>>.from(
            data['data'] ?? [],
          );
        });
      }
    } catch (e) {
      debugPrint('Error cargando todos los contratos: $e');
    }
  }

  Future<void> _cargarItemsContrato(int contratoId) async {
    setState(() {
      _cargando = true;
      _itemsContrato = [];
      _detallesEgreso = [];
    });

    final contratoObj = _contratosDisponibles.firstWhere(
      (c) => _toInt(c['id']) == contratoId,
      orElse: () => {},
    );
    _contratoNumero =
        contratoObj['numero_contrato']?.toString() ?? contratoId.toString();
    _objetoContratoController.text =
        contratoObj['objeto_contrato']?.toString() ??
        contratoObj['objeto']?.toString() ??
        'No especificado';

    try {
      final url = '$_baseUrl/egresos/obtener_stock.php?contrato_id=$contratoId';
      final r = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);

      if (r.statusCode == 200 && data['success'] == true) {
        final items = List<Map<String, dynamic>>.from(data['data'] ?? []);
        if (items.isEmpty) {
          _snack('Este contrato no tiene items asociados', Colors.orange);
        } else {
          setState(() {
            _itemsContrato = items;
            _detallesEgreso = items.map((item) {
              final totalIngresadoRaw = item['total_ingresado'];
              final totalIngresado = totalIngresadoRaw is int
                  ? totalIngresadoRaw.toDouble()
                  : totalIngresadoRaw is double
                  ? totalIngresadoRaw
                  : double.tryParse(totalIngresadoRaw.toString()) ?? 0.0;

              final totalEgresadoRaw = item['total_egresado'];
              final totalEgresado = totalEgresadoRaw is int
                  ? totalEgresadoRaw.toDouble()
                  : totalEgresadoRaw is double
                  ? totalEgresadoRaw
                  : double.tryParse(totalEgresadoRaw.toString()) ?? 0.0;

              return {
                'id_item_contrato': _toInt(item['item_contrato_id']),
                'nombre_item': item['nombre']?.toString() ?? '',
                'descripcion': item['descripcion']?.toString() ?? '',
                'cantidad_contratada': _toDouble(item['cantidad_contratada']),
                'total_ingresado': totalIngresado,
                'total_egresado': totalEgresado,
                'stock_disponible': _toDouble(item['stock_disponible']),
                'cantidad_egresada': 0.0,
                'cantidad_adicional': 0.0,
                'precio_unitario': _toDouble(item['precio_unitario']),
              };
            }).toList();
            _inicializarControllersCantidad();
          });
        }
      } else {
        _snack(' ${data['message'] ?? 'Error al cargar items'}', Colors.red);
      }
    } catch (e) {
      _snack('❌ Error cargando items: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _actualizarCantidad(int index, String valor) {
    final cantidad = double.tryParse(valor) ?? 0;
    final detalle = _detallesEgreso[index];
    final stock = _toDouble(detalle['stock_disponible']);

    setState(() {
      if (_modoEdicion) {
        _detallesEgreso[index]['cantidad_adicional'] = cantidad;
      } else {
        _detallesEgreso[index]['cantidad_egresada'] = cantidad;
      }
    });

    if (_modoEdicion && cantidad > stock && stock >= 0) {
      _snack(
        '⚠️ Excede stock. Disponible: ${_formatearNumero(stock)}',
        Colors.red,
      );
    } else if (!_modoEdicion && cantidad > stock && stock >= 0) {
      _snack(
        '⚠️ Excede stock. Disponible: ${_formatearNumero(stock)}',
        Colors.red,
      );
    }
  }

  Future<void> _registrarEgreso() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contratoSeleccionado == null) {
      _snack('Seleccione un contrato', Colors.orange);
      return;
    }
    if (!_validarStock()) return;

    setState(() => _cargando = true);
    try {
      final body = {
        'contrato_id': _contratoSeleccionado,
        'numero_egreso': _numeroEgresoController.text.trim(),
        'id_bodega': BODEGA_FIJA_ID,
        'usuario_id': usuarioId,
        'usuario_registro': username,
        'fecha': _fechaEgresoController.text.trim(),
        'observacion': _observacionController.text.trim(),
        'detalles': _detallesEgreso
            .where((d) => _toDouble(d['cantidad_egresada']) > 0)
            .map(
              (d) => {
                'item_contrato_id': d['id_item_contrato'],
                'cantidad': d['cantidad_egresada'],
                'precio_unitario': d['precio_unitario'],
              },
            )
            .toList(),
      };

      final r = await http
          .post(
            Uri.parse('$_baseUrl/egresos/registrar_egreso.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        _limpiarFormulario();
        _snack('✅ Egreso registrado exitosamente', Colors.green);
        await _cargarEgresos();
        setState(() => _mostrandoLista = true);
      } else {
        _snack(' ${data['message'] ?? 'Error desconocido'}', Colors.red);
      }
    } catch (e) {
      _snack('❌ Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _actualizarEgreso() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validarStock()) return;
    setState(() => _cargando = true);
    try {
      final detallesActualizados = _detallesEgreso
          .where((d) {
            final base = _toDouble(d['cantidad_egresada']);
            final adicional = _toDouble(d['cantidad_adicional']);
            return (base + adicional) > 0;
          })
          .map((d) {
            final base = _toDouble(d['cantidad_egresada']);
            final adicional = _toDouble(d['cantidad_adicional']);
            return {
              'item_contrato_id': d['id_item_contrato'],
              'cantidad': base + adicional,
              'precio_unitario': d['precio_unitario'],
            };
          })
          .toList();

      final r = await http
          .post(
            Uri.parse('$_baseUrl/egresos/actualizar_egreso.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': _egresoEditandoId,
              'numero_egreso': _numeroEgresoController.text.trim(),
              'id_bodega': BODEGA_FIJA_ID,
              'fecha': _fechaEgresoController.text.trim(),
              'observacion': _observacionController.text.trim(),
              'detalles': detallesActualizados,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        _limpiarFormulario();
        _snack('✅ Egreso actualizado', Colors.green);
        await _cargarEgresos();
        setState(() => _mostrandoLista = true);
      } else {
        _snack('❌ ${data['message'] ?? 'Error al actualizar'}', Colors.red);
      }
    } catch (e) {
      _snack('❌ Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarEgreso(int id, String numero) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Egreso'),
        content: Text('¿Eliminar egreso #$numero?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cargando = true);
    try {
      final r = await http
          .post(
            Uri.parse('$_baseUrl/egresos/eliminar_egreso.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': id}),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        _snack('✅ Egreso eliminado', Colors.green);
        await _cargarEgresos();
      } else {
        _snack('❌ ${data['message'] ?? 'Error al eliminar'}', Colors.red);
      }
    } catch (e) {
      _snack('❌ Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _verDetalle(Map<String, dynamic> egreso) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      ),
    );
    try {
      final r = await http
          .get(
            Uri.parse(
              '$_baseUrl/egresos/obtener_egreso.php?id=${egreso['id']}',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (mounted) Navigator.pop(context);
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        _mostrarDialogoDetalle(
          data['data']['egreso'],
          List<Map<String, dynamic>>.from(data['data']['detalles']),
        );
      } else {
        _snack('❌ ${data['message'] ?? 'Error'}', Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _snack(' Error: $e', Colors.red);
    }
  }

  // ✅ MODIFICADO: Se agregó la columna "Cant. Contratada" ANTES de "Cant. Ingresada"
  void _mostrarDialogoDetalle(
    Map<String, dynamic> eg,
    List<Map<String, dynamic>> detalles,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Egreso #${eg['numero_egreso'] ?? 'N/A'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Fecha', eg['fecha'] ?? 'N/A'),
                _infoRow('Bodega', eg['bodega_nombre'] ?? 'N/A'),
                _infoRow('Usuario', eg['usuario_nombre'] ?? 'N/A'),
                if ((eg['observacion'] ?? '').toString().trim().isNotEmpty)
                  _infoRow('Obs.', eg['observacion'].toString().trim()),
                const Divider(height: 24),
                Text(
                  'Items del Egreso',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                if (detalles.isEmpty)
                  const Text('Sin items', style: TextStyle(color: Colors.grey))
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 12,
                      headingRowColor: WidgetStateProperty.all(
                        Colors.green.shade50,
                      ),
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('Item')),
                        DataColumn(
                          label: Text('Cant. Contratada'),
                        ), // ✅ AGREGADA AQUÍ
                        DataColumn(label: Text('Cant. Ingresada')),
                        DataColumn(label: Text('Cant. Egresada')),
                        DataColumn(label: Text('Precio Unit.')),
                        DataColumn(label: Text('Subtotal')),
                      ],
                      rows: detalles.asMap().entries.map((e) {
                        final d = e.value;
                        final cantContratada = _toDouble(
                          d['cantidad_contratada'] ?? 0,
                        ); // ✅ DATO CONTRATADA
                        final cantIngresada = _toDouble(
                          d['cantidad_ingresada'] ?? cantContratada,
                        );
                        final cant = _toDouble(d['cantidad']);
                        final precio = _toDouble(d['precio_unitario']);

                        return DataRow(
                          cells: [
                            DataCell(Text('${e.key + 1}')),
                            DataCell(
                              Text(
                                d['nombre_item'] ?? 'N/A',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            // ✅ CELDA: CANTIDAD CONTRATADA
                            DataCell(
                              Center(
                                child: Text(_formatearNumero(cantContratada)),
                              ),
                            ),
                            // ✅ CELDA: CANTIDAD INGRESADA
                            DataCell(
                              Center(
                                child: Text(_formatearNumero(cantIngresada)),
                              ),
                            ),
                            DataCell(
                              Center(child: Text(_formatearNumero(cant))),
                            ),
                            DataCell(
                              Center(child: Text(_formatearConPuntos(precio))),
                            ),
                            DataCell(
                              Text(
                                _formatearConPuntos(cant * precio),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                if (detalles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _totalRow(detalles),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(': ', style: TextStyle(color: Colors.grey.shade600)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );

  Widget _totalRow(List<Map<String, dynamic>> detalles) {
    final total = detalles.fold(
      0.0,
      (sum, d) =>
          sum + _toDouble(d['cantidad']) * _toDouble(d['precio_unitario']),
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text(
            'TOTAL: ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            _formatearConPuntos(total),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cargarEgresoParaEditar(int egresoId) async {
    setState(() => _cargando = true);
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/egresos/obtener_egreso.php?id=$egresoId'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final egresoData = data['data']['egreso'];
        final detallesData = List<Map<String, dynamic>>.from(
          data['data']['detalles'] as List,
        );
        final String fechaEgreso = egresoData['fecha'] ?? '';
        String anioContrato = fechaEgreso.isNotEmpty && fechaEgreso.length >= 4
            ? fechaEgreso.substring(0, 4)
            : '';

        await _cargarTodosLosContratos();
        final contratoIdDelEgreso =
            int.tryParse(egresoData['contrato_id']?.toString() ?? '0') ?? 0;
        final contratoEncontrado = _contratosDisponibles.firstWhere(
          (c) => _toInt(c['id']) == contratoIdDelEgreso,
          orElse: () => {},
        );

        if (contratoEncontrado.isNotEmpty) {
          await _cargarItemsContrato(contratoIdDelEgreso);
          setState(() {
            _modoEdicion = true;
            _egresoEditandoId = egresoId;
            _numeroEgresoController.text = egresoData['numero_egreso'] ?? '';
            _fechaEgresoController.text = fechaEgreso;
            _observacionController.text = egresoData['observacion'] ?? '';
            _anioSeleccionado = anioContrato;
            _contratoSeleccionado = contratoIdDelEgreso;
            _contratoNumero =
                contratoEncontrado['numero_contrato']?.toString() ?? '';
            _objetoContratoController.text =
                contratoEncontrado['objeto_contrato']?.toString() ??
                contratoEncontrado['objeto']?.toString() ??
                'No especificado';

            for (var detalleEgreso in detallesData) {
              final itemId =
                  int.tryParse(
                    detalleEgreso['item_contrato_id']?.toString() ?? '0',
                  ) ??
                  0;
              final cantidadEgresada =
                  double.tryParse(
                    detalleEgreso['cantidad']?.toString() ?? '0',
                  ) ??
                  0.0;
              final index = _detallesEgreso.indexWhere(
                (d) => d['id_item_contrato'] == itemId,
              );
              if (index != -1) {
                _detallesEgreso[index]['cantidad_egresada'] = cantidadEgresada;
                _detallesEgreso[index]['cantidad_adicional'] = 0.0;
              }
            }
            _inicializarControllersCantidad();
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ El contrato #$contratoIdDelEgreso no existe'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        setState(() => _mostrandoLista = false);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Error al cargar egreso'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando egreso: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error detallado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarEgresos() async {
    setState(() => _cargando = true);
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/egresos/listar_egresos.php'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        setState(() {
          _egresos = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _egresosFiltrados = List.from(_egresos);
        });
      }
    } catch (e) {
      debugPrint('Error cargando egresos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _limpiarFormulario() {
    _numeroEgresoController.clear();
    _fechaEgresoController.clear();
    _observacionController.clear();
    _objetoContratoController.clear();
    for (final c in _cantidadControllers) {
      c.dispose();
    }
    _cantidadControllers = [];
    _anioSeleccionado = null;
    _contratoSeleccionado = null;
    _contratoNumero = '';
    _contratosDisponibles = [];
    _itemsContrato = [];
    _detallesEgreso = [];
    _modoEdicion = false;
    _egresoEditandoId = null;
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  InputDecoration _deco(
    String label, {
    String? hint,
    bool alignLabel = false,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    isDense: true,
    alignLabelWithHint: alignLabel,
  );

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF2E7D32);
    return Scaffold(
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 4,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 192, 231, 195),
              border: Border(bottom: BorderSide(color: verde, width: 4)),
            ),
            child: Row(
              children: [
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: verde, size: 30),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/logos/banner_gobernacion.png',
                  height: 110,
                  fit: BoxFit.contain,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _modoEdicion
                          ? 'Editar Egreso #$_egresoEditandoId'
                          : 'Registrar Egresos',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                  ),
                ),
                if (!_modoEdicion)
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _mostrandoLista = !_mostrandoLista);
                        if (_mostrandoLista) _cargarEgresos();
                      },
                      icon: Icon(
                        _mostrandoLista ? Icons.add : Icons.list,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        _mostrandoLista ? 'Nuevo' : 'Ver Listado',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mostrandoLista
                            ? verde
                            : Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                if (_modoEdicion)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 28),
                    onPressed: () {
                      _limpiarFormulario();
                      setState(() => _mostrandoLista = true);
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.green.shade50, Colors.white],
                ),
              ),
              child: _mostrandoLista
                  ? _buildListaEgresos()
                  : Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: Form(
                            key: _formKey,
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSeccionDatos(verde),
                                    const SizedBox(height: 20),
                                    _buildSeccionDetalles(verde),
                                    const SizedBox(height: 20),
                                    _buildBotones(verde),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionDatos(Color verde) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: verde, size: 20),
            const SizedBox(width: 8),
            Text(
              'Datos del Egreso',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
          ],
        ),
        const Divider(height: 20, thickness: 1),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: username,
                readOnly: true,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Usuario que registra',
                  prefixIcon: const Icon(Icons.person, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _numeroEgresoController,
                decoration: _deco('Número de Egreso *', hint: 'Ej: EGR-0001'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese número de egreso'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: BODEGA_FIJA_NOMBRE,
                readOnly: true,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Bodega',
                  prefixIcon: const Icon(Icons.store, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _fechaEgresoController,
                decoration: _deco('Fecha Egreso *', hint: 'YYYY-MM-DD'),
                readOnly: true,
                onTap: () => _pickDate(_fechaEgresoController),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingrese fecha' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _anioSeleccionado,
                hint: const Text('Año contrato *'),
                isExpanded: true,
                items: _aniosDisponibles
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: _modoEdicion
                    ? null
                    : (v) {
                        setState(() {
                          _anioSeleccionado = v;
                          _contratoSeleccionado = null;
                          _contratosDisponibles = [];
                          _itemsContrato = [];
                          _detallesEgreso = [];
                          _objetoContratoController.clear();
                          _contratoNumero = '';
                        });
                        if (v != null) _cargarContratosPorAnio(v);
                      },
                decoration: _deco('Año contrato *'),
                validator: (v) => v == null ? 'Seleccione año' : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue:
                    _contratoSeleccionado != null &&
                        _contratosDisponibles.any(
                          (c) => _toInt(c['id']) == _contratoSeleccionado,
                        )
                    ? _contratoSeleccionado
                    : null,
                hint: const Text('Contrato *'),
                isExpanded: true,
                items: _contratosDisponibles
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: _toInt(c['id']),
                        child: Text(c['numero_contrato'] ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: _modoEdicion
                    ? null
                    : (v) {
                        setState(() {
                          _contratoSeleccionado = v;
                          _itemsContrato = [];
                          _detallesEgreso = [];
                          final contratoSeleccionado = _contratosDisponibles
                              .firstWhere(
                                (c) => _toInt(c['id']) == v,
                                orElse: () => {},
                              );
                          _contratoNumero =
                              contratoSeleccionado['numero_contrato']
                                  ?.toString() ??
                              '';
                          _objetoContratoController.text =
                              contratoSeleccionado['objeto_contrato']
                                  ?.toString() ??
                              contratoSeleccionado['objeto']?.toString() ??
                              'No especificado';
                        });
                        if (v != null) _cargarItemsContrato(v);
                      },
                decoration: _deco('Contrato *'),
                validator: (v) => v == null ? 'Seleccione contrato' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _objetoContratoController,
          readOnly: true,
          maxLines: 2,
          decoration: _deco('Objeto del Contrato', alignLabel: true).copyWith(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _observacionController,
          maxLines: 3,
          minLines: 2,
          decoration: _deco('Observación', alignLabel: true),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSeccionDetalles(Color verde) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt, color: verde, size: 20),
            const SizedBox(width: 8),
            Text(
              'Detalles de Egreso',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: verde.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_detallesEgreso.length} items',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 20, thickness: 1),
        const SizedBox(height: 8),
        if (_detallesEgreso.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'Sin items',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                Text(
                  'Seleccione un contrato para cargar los items',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 12,
                headingRowHeight: 36,
                headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
                columns: [
                  DataColumn(
                    label: Text(
                      '#',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Item',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Cant. Contratada',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Cant. Ingresada',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                  ),
                  if (!_modoEdicion)
                    DataColumn(
                      label: Text(
                        'Cant. Egresada (base)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: verde,
                        ),
                      ),
                    ),
                  if (_modoEdicion)
                    DataColumn(
                      label: Text(
                        'Cant. Egresada (Base)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: verde,
                        ),
                      ),
                    ),
                  DataColumn(
                    label: Text(
                      'Stock Disponible',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      _modoEdicion ? 'Cant. Adicional *' : 'Cant. a Egresar *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                  ),
                ],
                rows: _detallesEgreso.asMap().entries.map((entry) {
                  final i = entry.key;
                  final detalle = entry.value;
                  final contratada = _toDouble(detalle['cantidad_contratada']);
                  final ingresada = _toDouble(detalle['total_ingresado']);
                  final baseEgresada = _modoEdicion
                      ? _toDouble(detalle['cantidad_egresada'])
                      : _toDouble(detalle['total_egresado']);
                  final adicional = _toDouble(detalle['cantidad_adicional']);
                  final stock = _toDouble(detalle['stock_disponible']);
                  final cantidadMostrar = _modoEdicion
                      ? adicional
                      : _toDouble(detalle['cantidad_egresada']);
                  final excede = _modoEdicion
                      ? (adicional > stock && adicional > 0)
                      : (cantidadMostrar > stock && cantidadMostrar > 0);

                  return DataRow(
                    cells: [
                      DataCell(
                        Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                      ),
                      DataCell(
                        Text(
                          detalle['nombre_item'] ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Text(
                            _formatearNumero(contratada),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Text(
                            _formatearNumero(ingresada),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ),
                      if (!_modoEdicion)
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Text(
                              _formatearNumero(baseEgresada),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ),
                      if (_modoEdicion)
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Text(
                              _formatearNumero(baseEgresada),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: stock > 0
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: stock > 0
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Text(
                            _formatearNumero(stock),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: stock > 0
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _cantidadControllers.length > i
                                ? _cantidadControllers[i]
                                : null,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              fontSize: 12,
                              color: excede
                                  ? Colors.red.shade700
                                  : Colors.black,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              isDense: true,
                              filled: excede,
                              fillColor: excede ? Colors.red.shade50 : null,
                              errorText: excede ? 'Excede' : null,
                              errorStyle: const TextStyle(fontSize: 9),
                            ),
                            onChanged: (v) => _actualizarCantidad(i, v),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBotones(Color verde) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _cargando
                ? null
                : () => _modoEdicion ? _actualizarEgreso() : _registrarEgreso(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _modoEdicion ? Colors.orange.shade700 : verde,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _cargando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _modoEdicion ? 'ACTUALIZAR EGRESO' : 'REGISTRAR EGRESO',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        if (_modoEdicion) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () {
                _limpiarFormulario();
                setState(() => _mostrandoLista = true);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cancelar Edición',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildListaEgresos() {
    const Color verde = Color(0xFF2E7D32);
    if (_egresos.isEmpty && !_cargando) {
      return Center(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No hay egresos registrados',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _mostrandoLista = false),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo Egreso'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: ' Buscar por número, bodega, usuario...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filtrarEgresos();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Total: ${_egresosFiltrados.length} egresos',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (_cargando)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ..._egresosFiltrados.map(
            (egreso) => InkWell(
              onTap: () => _verDetalle(egreso),
              borderRadius: BorderRadius.circular(10),
              child: Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Contrato: ${egreso['numero_contrato'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            egreso['fecha'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.store,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Bodega: ${egreso['bodega_nombre'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.shopping_bag,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Items: ${egreso['total_items'] ?? 0}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Usuario: ${egreso['usuario_nombre'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _cargarEgresoParaEditar(_toInt(egreso['id'])),
                            icon: Icon(
                              Icons.edit,
                              color: Colors.blue.shade600,
                              size: 18,
                            ),
                            label: Text(
                              'Editar',
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 12,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (rol == 'administrador' || rol == 'administrativo')
                            TextButton.icon(
                              onPressed: () => _eliminarEgreso(
                                _toInt(egreso['id']),
                                egreso['numero_egreso'] ?? '',
                              ),
                              icon: Icon(
                                Icons.delete,
                                color: Colors.red.shade600,
                                size: 18,
                              ),
                              label: Text(
                                'Eliminar',
                                style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () {
                _limpiarFormulario();
                setState(() => _mostrandoLista = false);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Volver al Formulario',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _numeroEgresoController.dispose();
    _fechaEgresoController.dispose();
    _observacionController.dispose();
    _objetoContratoController.dispose();
    _searchController.dispose();
    for (final c in _cantidadControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
