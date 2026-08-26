import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/drawer_menu.dart';

class RegistrarIngresoPage extends StatefulWidget {
  const RegistrarIngresoPage({super.key});

  @override
  State<RegistrarIngresoPage> createState() => _RegistrarIngresoPageState();
}

class _RegistrarIngresoPageState extends State<RegistrarIngresoPage> {
  late String username;
  late String sector;
  late String rol;

  final _formKey = GlobalKey<FormState>();
  final _numeroIngresoController = TextEditingController();
  final _fechaIngresoController = TextEditingController();
  final _observacionController = TextEditingController();
  final _objetoContratoController = TextEditingController();
  final _searchController = TextEditingController();

  List<TextEditingController> _cantidadAdicionalControllers = [];

  String _searchQuery = '';
  List<Map<String, dynamic>> _ingresosFiltrados = [];

  String? _anioSeleccionado;
  int? _contratoSeleccionado;
  static const int BODEGA_FIJA_ID = 1;
  static const String BODEGA_FIJA_NOMBRE = 'Gobernación';

  List<String> _aniosDisponibles = [];
  List<Map<String, dynamic>> _contratosDisponibles = [];
  List<Map<String, dynamic>> _itemsContrato = [];
  List<Map<String, dynamic>> _detallesIngreso = [];
  List<Map<String, dynamic>> _ingresos = [];

  bool _cargando = false;
  bool _mostrandoLista = false;
  bool _modoEdicion = false;
  int? _ingresoEditandoId;

  static const String _baseUrl = 'http://192.168.10.64/samde_db/api';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Object? argumentosRaw = ModalRoute.of(context)!.settings.arguments;
    final Map<String, dynamic> argumentos =
        (argumentosRaw is Map<String, dynamic>) ? argumentosRaw : {};

    username = argumentos['username'] ?? 'Usuario';
    sector = argumentos['sector'] ?? 'No Asignado';
    rol = argumentos['rol'] ?? 'consulta';
  }

  @override
  void initState() {
    super.initState();
    _cargarAnios();
    _cargarIngresos();
    _searchController.addListener(_filtrarIngresos);
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

  String _formatearFechaParaBD(String fecha) {
    if (fecha.isEmpty) return '';
    return fecha;
  }

  double _convertirADouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    if (valor is String) {
      final limpio = valor.replaceAll(',', '').replaceAll(' ', '').trim();
      return double.tryParse(limpio) ?? 0.0;
    }
    return 0.0;
  }

  int _convertirANumero(dynamic valor) {
    if (valor == null) return 0;
    if (valor is int) return valor;
    if (valor is double) return valor.toInt();
    if (valor is String) {
      final limpio = valor.replaceAll(',', '').replaceAll(' ', '').trim();
      return int.tryParse(limpio) ?? 0;
    }
    return 0;
  }

  String _formatearPrecio(dynamic valor) {
    if (valor == null) return '\$0';
    final double numero = valor is double
        ? valor
        : double.tryParse(valor.toString()) ?? 0;
    final int entero = numero.round();
    final String numeroStr = entero.toString();
    String resultado = '';
    int contador = 0;
    for (int i = numeroStr.length - 1; i >= 0; i--) {
      resultado = numeroStr[i] + resultado;
      contador++;
      if (contador % 3 == 0 && i != 0) resultado = '.$resultado';
    }
    return '\$$resultado';
  }

  String _formatearNumero(dynamic valor) {
    if (valor == null) return '0';
    final double numero = valor is double
        ? valor
        : double.tryParse(valor.toString()) ?? 0;
    return numero == numero.truncateToDouble()
        ? numero.truncate().toString()
        : numero.toStringAsFixed(2);
  }

  bool _validarCantidades() {
    for (int i = 0; i < _detallesIngreso.length; i++) {
      final detalle = _detallesIngreso[i];
      final double contratada = _convertirADouble(
        detalle['cantidad_contratada'],
      );
      final double baseIngresada = _convertirADouble(
        detalle['cantidad_ingresada'],
      );

      double cantidadFinal;
      if (_modoEdicion) {
        final adicional = _cantidadAdicionalControllers.length > i
            ? _convertirADouble(_cantidadAdicionalControllers[i].text)
            : 0.0;
        cantidadFinal = baseIngresada + adicional;
      } else {
        cantidadFinal = _convertirADouble(detalle['cantidad_ingresada']);
      }

      if (cantidadFinal > contratada) {
        _mostrarMensaje(
          '⚠️ La cantidad total (${_formatearNumero(cantidadFinal)}) no puede ser mayor a la contratada (${_formatearNumero(contratada)}) para "${detalle['nombre_item']}"',
          Colors.orange,
        );
        return false;
      }
    }
    return true;
  }

  void _filtrarIngresos() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      if (_searchQuery.isEmpty) {
        _ingresosFiltrados = List.from(_ingresos);
      } else {
        _ingresosFiltrados = _ingresos.where((ingreso) {
          final numero = (ingreso['numero_ingreso'] ?? '').toLowerCase();
          final contrato = (ingreso['numero_contrato'] ?? '').toLowerCase();
          final bodega = (ingreso['bodega'] ?? '').toLowerCase();
          final usuario = (ingreso['usuario_registro'] ?? '').toLowerCase();
          final observacion = (ingreso['observacion'] ?? '').toLowerCase();
          return numero.contains(_searchQuery) ||
              contrato.contains(_searchQuery) ||
              bodega.contains(_searchQuery) ||
              usuario.contains(_searchQuery) ||
              observacion.contains(_searchQuery);
        }).toList();
      }
    });
  }

  void _cargarAnios() {
    final anioActual = DateTime.now().year;
    _aniosDisponibles = {
      (anioActual - 2).toString(),
      (anioActual - 1).toString(),
      ...List.generate(10, (index) => (anioActual + index).toString()),
    }.toList()..sort();
  }

  Future<void> _cargarContratosPorAnio(String anio) async {
    setState(() => _cargando = true);
    _contratosDisponibles = [];
    _itemsContrato = [];
    _detallesIngreso = [];
    _objetoContratoController.clear();

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/contratos/listar_contrato.php'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final todos = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _contratosDisponibles = todos
              .where((c) => (c['fecha_inicio'] ?? '').startsWith(anio))
              .toList();

          if (_contratosDisponibles.isEmpty) {
            _mostrarMensaje(
              'No hay contratos para el año $anio',
              Colors.orange,
            );
          }
        }
      }
    } catch (e) {
      _mostrarMensaje('Error cargando contratos: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarTodosLosContratos() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/contratos/listar_contrato.php'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _contratosDisponibles = List<Map<String, dynamic>>.from(
              data['data'] ?? [],
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando todos los contratos: $e');
    }
  }

  Future<void> _cargarItemsContrato(int contratoId) async {
    setState(() => _cargando = true);
    _itemsContrato = [];
    _detallesIngreso = [];

    try {
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/contratos/obtener_contrato.php?id=$contratoId',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final contratoData = data['data'] ?? {};
          final items = contratoData['items'] as List? ?? [];

          if (items.isNotEmpty) {
            setState(() {
              _itemsContrato = List<Map<String, dynamic>>.from(items);
              _detallesIngreso = _itemsContrato
                  .map(
                    (item) => {
                      'id_item_contrato': _convertirANumero(
                        item['id'] ?? item['id_item_contrato'] ?? 0,
                      ),
                      'nombre_item':
                          item['nombre']?.toString() ??
                          item['nombre_item']?.toString() ??
                          '',
                      'descripcion': item['descripcion']?.toString() ?? '',
                      'cantidad_contratada': _convertirADouble(
                        item['cantidad'] ?? item['cantidad_contratada'] ?? 0,
                      ),
                      'total_ingresado': _convertirADouble(
                        item['total_ingresado'] ?? 0,
                      ),
                      'cantidad_ingresada': 0.0,
                      'precio_unitario': _convertirADouble(
                        item['valor_unitario'] ?? item['precio_unitario'] ?? 0,
                      ),
                    },
                  )
                  .toList();
            });
          } else {
            _mostrarMensaje(
              '⚠️ Este contrato no tiene items asociados',
              Colors.orange,
            );
          }
        } else {
          _mostrarMensaje(
            '❌ ${data['message'] ?? 'Error al cargar items'}',
            Colors.red,
          );
        }
      } else {
        _mostrarMensaje('Error al conectar con el servidor', Colors.red);
      }
    } catch (e) {
      _mostrarMensaje('❌ Error cargando items: $e', Colors.red);
      debugPrint('Error detallado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _actualizarCantidadIngresada(int index, String valor) {
    final cantidad = _convertirADouble(valor);
    final contratada = _convertirADouble(
      _detallesIngreso[index]['cantidad_contratada'],
    );

    setState(() {
      _detallesIngreso[index]['cantidad_ingresada'] = cantidad;
    });

    if (cantidad > contratada && contratada > 0) {
      _mostrarMensaje(
        '⚠️ La cantidad (${_formatearNumero(cantidad)}) excede lo contratado (${_formatearNumero(contratada)})',
        Colors.orange,
      );
    }
  }

  void _actualizarCantidadAdicional(int index, String valor) {
    final adicional = _convertirADouble(valor);
    final baseIngresada = _convertirADouble(
      _detallesIngreso[index]['cantidad_ingresada'],
    );
    final contratada = _convertirADouble(
      _detallesIngreso[index]['cantidad_contratada'],
    );
    final total = baseIngresada + adicional;

    if (total > contratada && contratada > 0) {
      _mostrarMensaje(
        '⚠️ El total (${_formatearNumero(total)}) excede lo contratado (${_formatearNumero(contratada)})',
        Colors.orange,
      );
    }
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  Future<void> _registrarIngreso() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contratoSeleccionado == null) {
      _mostrarMensaje('Seleccione un contrato', Colors.orange);
      return;
    }
    if (!_detallesIngreso.any(
      (d) => (_convertirADouble(d['cantidad_ingresada']) ?? 0) > 0,
    )) {
      _mostrarMensaje(
        'Debe ingresar al menos un item con cantidad > 0',
        Colors.orange,
      );
      return;
    }
    if (!_validarCantidades()) return;

    setState(() => _cargando = true);
    try {
      String fechaFormateada = _formatearFechaParaBD(
        _fechaIngresoController.text.trim(),
      );
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ingresos/registrar_ingreso.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id_contrato': _contratoSeleccionado,
              'id_bodega': BODEGA_FIJA_ID,
              'numero_ingreso': _numeroIngresoController.text.trim(),
              'fecha_ingreso': fechaFormateada,
              'observacion': _observacionController.text.trim(),
              'usuario_registro': username,
              'detalles': _detallesIngreso
                  .map(
                    (d) => ({
                      'id_item_contrato': d['id_item_contrato'],
                      'cantidad_ingresada':
                          _convertirADouble(d['cantidad_ingresada']) ?? 0,
                      'precio_unitario':
                          _convertirADouble(d['precio_unitario']) ?? 0,
                    }),
                  )
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        _limpiarFormulario();
        _mostrarMensaje('✅ Ingreso registrado exitosamente', Colors.green);
        await _cargarIngresos();
        setState(() => _mostrandoLista = true);
      } else {
        final mensajeError = data['message'] ?? 'Error desconocido';
        _mostrarMensaje('❌ $mensajeError', Colors.red);
        if (data['errors'] != null && data['errors'] is List) {
          for (var error in data['errors']) {
            _mostrarMensaje('📌 ${error.toString()}', Colors.orange);
          }
        }
      }
    } catch (e) {
      _mostrarMensaje('❌ Error: ${e.toString()}', Colors.red);
      debugPrint('Error detallado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _verIngresoDetalle(Map<String, dynamic> ingreso) async {
    final ingresoId = ingreso['id'];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      ),
    );

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/ingresos/obtener_ingreso.php?id=$ingresoId'),
          )
          .timeout(const Duration(seconds: 10));
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final ingresoData = data['data']['ingreso'];
          final detallesRaw = data['data']['detalles'] as List;
          final List<Map<String, dynamic>> detalles = detallesRaw
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          if (mounted) _mostrarDialogoDetalle(ingresoData, detalles);
        } else {
          _mostrarMensaje(
            '❌ ${data['message'] ?? 'Error al cargar detalle'}',
            Colors.red,
          );
        }
      } else {
        _mostrarMensaje('Error al conectar con el servidor', Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _mostrarMensaje('❌ Error de conexión: $e', Colors.red);
    }
  }

  void _mostrarDialogoDetalle(
    Map<String, dynamic> ingresoData,
    List<Map<String, dynamic>> detalles,
  ) {
    String observacion = (ingresoData['observacion'] ?? '').toString().trim();
    String usuario =
        ingresoData['usuario_nombre'] ??
        ingresoData['usuario_registro'] ??
        'N/A';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.inventory_2, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Detalle de Ingreso #${ingresoData['numero_ingreso'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Fecha', ingresoData['fecha'] ?? 'N/A'),
                    _buildInfoRow(
                      'Contrato',
                      ingresoData['numero_contrato'] ?? 'N/A',
                    ),
                    _buildInfoRow('Bodega', ingresoData['bodega'] ?? 'N/A'),
                    _buildInfoRow('Usuario', usuario),
                    if (observacion.isNotEmpty)
                      _buildInfoRow('Observación', observacion),
                    const Divider(height: 24),
                    const Text(
                      'Items del Ingreso',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (detalles.isEmpty)
                      const Text(
                        'No hay items registrados',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
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
                            headingRowColor: WidgetStateProperty.all(
                              Colors.green.shade50,
                            ),
                            columns: const [
                              DataColumn(
                                label: Text(
                                  '#',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Item',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Cant. Contratada',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Cant. Ingresada',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Precio Unit.',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Subtotal',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                            rows: detalles.asMap().entries.map((entry) {
                              final index = entry.key;
                              final detalle = entry.value;
                              final cantidadIngresada = _convertirADouble(
                                detalle['cantidad_ingresada'],
                              );
                              final precioUnitario = _convertirADouble(
                                detalle['precio_unitario'],
                              );
                              final subtotal =
                                  cantidadIngresada * precioUnitario;

                              return DataRow(
                                cells: [
                                  DataCell(Text('${index + 1}')),
                                  DataCell(
                                    Text(
                                      detalle['nombre_item'] ?? 'N/A',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Text(
                                        _formatearNumero(
                                          detalle['cantidad_contratada'],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Text(
                                        _formatearNumero(
                                          detalle['cantidad_ingresada'],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _formatearPrecio(precioUnitario),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _formatearPrecio(subtotal),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (detalles.isNotEmpty) _buildTotalRow(detalles),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(List<Map<String, dynamic>> detalles) {
    double total = 0;
    for (var detalle in detalles) {
      total +=
          _convertirADouble(detalle['cantidad_ingresada']) *
          _convertirADouble(detalle['precio_unitario']);
    }
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
            _formatearPrecio(total),
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

  Future<void> _cargarIngresoParaEditar(int ingresoId) async {
    setState(() => _cargando = true);
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/ingresos/obtener_ingreso.php?id=$ingresoId'),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final ingresoData = data['data']['ingreso'];
        final detallesData = List<Map<String, dynamic>>.from(
          data['data']['detalles'] as List,
        );

        final String fechaIngreso = ingresoData['fecha'] ?? '';
        String anioContrato = '';
        if (fechaIngreso.isNotEmpty && fechaIngreso.length >= 4) {
          anioContrato = fechaIngreso.substring(0, 4);
        }

        await _cargarTodosLosContratos();

        final contratoId = _convertirANumero(
          ingresoData['contrato_id'] ?? ingresoData['id_contrato'],
        );
        await _cargarItemsContrato(contratoId);

        final contratoEncontrado = _contratosDisponibles.firstWhere(
          (c) => _convertirANumero(c['id']) == contratoId,
          orElse: () => {},
        );

        for (final c in _cantidadAdicionalControllers) {
          c.dispose();
        }

        setState(() {
          _modoEdicion = true;
          _ingresoEditandoId = ingresoId;

          _numeroIngresoController.text = ingresoData['numero_ingreso'] ?? '';
          _fechaIngresoController.text = fechaIngreso;
          _observacionController.text = ingresoData['observacion'] ?? '';

          _anioSeleccionado = anioContrato;
          _contratoSeleccionado = contratoId;

          _objetoContratoController.text =
              contratoEncontrado['objeto_contrato']?.toString() ??
              contratoEncontrado['objeto']?.toString() ??
              'No especificado';

          _cantidadAdicionalControllers = _detallesIngreso
              .map((_) => TextEditingController(text: ''))
              .toList();

          for (var detalleIngreso in detallesData) {
            final itemId = _convertirANumero(
              detalleIngreso['id_item_contrato'],
            );
            final cantidadIngresada = _convertirADouble(
              detalleIngreso['cantidad_ingresada'],
            );

            final index = _detallesIngreso.indexWhere(
              (d) => d['id_item_contrato'] == itemId,
            );
            if (index != -1) {
              _detallesIngreso[index]['cantidad_ingresada'] = cantidadIngresada;
            }
          }
        });

        setState(() => _mostrandoLista = false);
      } else {
        _mostrarMensaje(
          '❌ ${data['message'] ?? 'Error al cargar ingreso'}',
          Colors.red,
        );
      }
    } catch (e) {
      _mostrarMensaje('❌ Error cargando ingreso: $e', Colors.red);
      debugPrint('Error detallado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _actualizarIngreso() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validarCantidades()) return;

    final detallesActualizados = <Map<String, dynamic>>[];
    for (int i = 0; i < _detallesIngreso.length; i++) {
      final detalle = _detallesIngreso[i];
      final baseIngresada = _convertirADouble(detalle['cantidad_ingresada']);
      final adicional = i < _cantidadAdicionalControllers.length
          ? _convertirADouble(_cantidadAdicionalControllers[i].text)
          : 0.0;
      final cantidadTotal = baseIngresada + adicional;

      if (cantidadTotal > 0) {
        detallesActualizados.add({
          'id_item_contrato': detalle['id_item_contrato'],
          'cantidad_ingresada': cantidadTotal,
          'precio_unitario': _convertirADouble(detalle['precio_unitario']),
        });
      }
    }

    if (detallesActualizados.isEmpty) {
      _mostrarMensaje(
        'Debe ingresar al menos un item con cantidad > 0',
        Colors.orange,
      );
      return;
    }

    setState(() => _cargando = true);
    try {
      String fechaFormateada = _formatearFechaParaBD(
        _fechaIngresoController.text.trim(),
      );
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ingresos/actualizar_ingreso.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': _ingresoEditandoId,
              'id_bodega': BODEGA_FIJA_ID,
              'numero_ingreso': _numeroIngresoController.text.trim(),
              'fecha_ingreso': fechaFormateada,
              'observacion': _observacionController.text.trim(),
              'detalles': detallesActualizados,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _limpiarFormulario();
        _mostrarMensaje('✅ Ingreso actualizado', Colors.green);
        await _cargarIngresos();
        setState(() => _mostrandoLista = true);
      } else {
        final mensajeError = data['message'] ?? 'Error al actualizar';
        _mostrarMensaje('❌ $mensajeError', Colors.red);
        if (data['errors'] != null && data['errors'] is List) {
          for (var error in data['errors']) {
            _mostrarMensaje('📌 ${error.toString()}', Colors.orange);
          }
        }
      }
    } catch (e) {
      _mostrarMensaje('❌ Error: ${e.toString()}', Colors.red);
      debugPrint('Error detallado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarIngreso(int ingresoId, String numeroIngreso) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Ingreso'),
        content: Text('¿Eliminar ingreso #$numeroIngreso?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _cargando = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/ingresos/eliminar_ingreso.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': ingresoId}),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _mostrarMensaje('✅ Ingreso eliminado', Colors.green);
        await _cargarIngresos();
      } else {
        _mostrarMensaje(
          ' ${data['message'] ?? 'Error al eliminar'}',
          Colors.red,
        );
      }
    } catch (e) {
      _mostrarMensaje('❌ Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarIngresos() async {
    setState(() => _cargando = true);
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/ingresos/listar_ingresos.php'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _ingresos = List<Map<String, dynamic>>.from(data['data'] ?? []);
            _ingresosFiltrados = List.from(_ingresos);
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando ingresos: $e');
      _mostrarMensaje('Error al cargar ingresos: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _limpiarFormulario() {
    _numeroIngresoController.clear();
    _fechaIngresoController.clear();
    _observacionController.clear();
    _objetoContratoController.clear();
    _anioSeleccionado = null;
    _contratoSeleccionado = null;
    _contratosDisponibles = [];
    _itemsContrato = [];
    _detallesIngreso = [];
    _modoEdicion = false;
    _ingresoEditandoId = null;

    for (final c in _cantidadAdicionalControllers) {
      c.dispose();
    }
    _cantidadAdicionalControllers = [];
  }

  InputDecoration _inputDeco(
    String label, {
    String? hint,
    bool alignLabel = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      isDense: true,
      alignLabelWithHint: alignLabel,
    );
  }

  DataColumn _buildDataColumn(String label, Color verde) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: verde,
        ),
      ),
    );
  }

  Widget _buildCardIngreso(Map<String, dynamic> ingreso, Color verde) {
    final bool puedeEliminar =
        (rol == 'administrador' || rol == 'administrativo');

    return InkWell(
      onTap: () => _verIngresoDetalle(ingreso),
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
                      color: verde.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      ingreso['numero_ingreso'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: verde,
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
                    ingreso['fecha_ingreso'] ?? '',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.assignment, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Contrato: ${ingreso['numero_contrato'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.store, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Bodega: ${ingreso['bodega'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.shopping_bag,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Items: ${ingreso['total_items'] ?? 0}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Usuario: ${ingreso['usuario_registro'] ?? 'N/A'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
              if ((ingreso['observacion'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.comment, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ingreso['observacion'].toString().trim(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _cargarIngresoParaEditar(
                      int.parse(ingreso['id'].toString()),
                    ),
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (puedeEliminar) ...[
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _eliminarIngreso(
                        int.parse(ingreso['id'].toString()),
                        ingreso['numero_ingreso'] ?? '',
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
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListaIngresos() {
    const Color verde = Color(0xFF2E7D32);

    if (_ingresos.isEmpty && !_cargando) {
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
                  'No hay ingresos registrados',
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
                  label: const Text('Nuevo Ingreso'),
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
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: ' Buscar por número, contrato, bodega...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: verde, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _filtrarIngresos();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _filtrarIngresos(),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.inventory_2, color: verde, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Listado de Ingresos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: verde.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Total: ${_ingresosFiltrados.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: verde,
                    ),
                  ),
                ),
                if (_cargando) ...[
                  const SizedBox(width: 8),
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
          ..._ingresosFiltrados.map(
            (ingreso) => _buildCardIngreso(ingreso, verde),
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
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
                : () {
                    if (!_validarCantidades()) return;
                    _modoEdicion ? _actualizarIngreso() : _registrarIngreso();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
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
                    _modoEdicion ? 'ACTUALIZAR INGRESO' : 'REGISTRAR INGRESO',
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
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSeccionDetalles(Color verde, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt, color: verde, size: 20),
            const SizedBox(width: 8),
            Text(
              'Detalles de Ingreso',
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
                '${_detallesIngreso.length} items',
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
        _detallesIngreso.isEmpty
            ? Container(
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Seleccione un contrato para cargar los items',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            : isMobile
            ? _buildDetallesMobile(verde)
            : _buildDetallesDesktop(verde),
      ],
    );
  }

  Widget _buildDetallesMobile(Color verde) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _detallesIngreso.length,
      itemBuilder: (context, index) {
        final detalle = _detallesIngreso[index];
        final cantidadContratada = _convertirADouble(
          detalle['cantidad_contratada'],
        );
        final totalIngresado = _convertirADouble(
          detalle['total_ingresado'] ?? 0,
        );
        final stockContrato = cantidadContratada - totalIngresado;
        final baseIngresada = _convertirADouble(detalle['cantidad_ingresada']);

        final cantidadAdicional =
            _modoEdicion && index < _cantidadAdicionalControllers.length
            ? _convertirADouble(_cantidadAdicionalControllers[index].text)
            : 0.0;
        final cantidadTotal = baseIngresada + cantidadAdicional;
        final tieneError =
            cantidadTotal > cantidadContratada && cantidadContratada > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: verde.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: verde,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detalle['nombre_item'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((detalle['descripcion'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      detalle['descripcion'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildBadge(
                      'Contratada',
                      _formatearNumero(cantidadContratada),
                      Colors.purple,
                    ),
                    _buildBadge(
                      'Ya ingresado',
                      _formatearNumero(totalIngresado),
                      Colors.blue,
                    ),
                    _buildBadge(
                      'Pendiente',
                      _formatearNumero(stockContrato),
                      stockContrato > 0 ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _modoEdicion ? 'Cantidad adicional:' : 'Cantidad a ingresar:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _modoEdicion
                      ? (_cantidadAdicionalControllers.length > index
                            ? _cantidadAdicionalControllers[index]
                            : TextEditingController())
                      : null,
                  initialValue: _modoEdicion
                      ? null
                      : (baseIngresada == 0
                            ? ''
                            : _formatearNumero(baseIngresada)),
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 13,
                    color: tieneError ? Colors.red.shade700 : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: _modoEdicion ? '0' : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    isDense: true,
                    errorText: tieneError ? 'Excede contratado' : null,
                    errorStyle: const TextStyle(fontSize: 10),
                  ),
                  onChanged: (value) {
                    if (_modoEdicion) {
                      _actualizarCantidadAdicional(index, value);
                    } else {
                      _actualizarCantidadIngresada(index, value);
                    }
                    setState(() {});
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    final cantidad = double.tryParse(value);
                    if (cantidad == null || cantidad < 0) return 'Inválido';
                    return null;
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetallesDesktop(Color verde) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            key: ValueKey(_modoEdicion),
            columnSpacing: 12,
            headingRowHeight: 36,
            headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
            columns: [
              _buildDataColumn('#', verde),
              _buildDataColumn('Item', verde),
              _buildDataColumn('Descripción', verde),
              _buildDataColumn('Cant. Contratada', verde),
              _buildDataColumn('Total Ingresado (Base)', verde),
              _buildDataColumn('Pendiente por Ingresar', verde),
              _buildDataColumn(
                _modoEdicion ? 'Cant. Adicional *' : 'Cant. a Ingresar *',
                verde,
              ),
            ],
            rows: _detallesIngreso.asMap().entries.map((entry) {
              final index = entry.key;
              final detalle = entry.value;

              final cantidadContratada = _convertirADouble(
                detalle['cantidad_contratada'],
              );
              final totalIngresado = _convertirADouble(
                detalle['total_ingresado'] ?? 0,
              );
              final stockContrato = cantidadContratada - totalIngresado;
              final baseIngresada = _convertirADouble(
                detalle['cantidad_ingresada'],
              );

              final cantidadAdicional =
                  _modoEdicion && index < _cantidadAdicionalControllers.length
                  ? _convertirADouble(_cantidadAdicionalControllers[index].text)
                  : 0.0;
              final cantidadTotal = baseIngresada + cantidadAdicional;
              final tieneError =
                  cantidadTotal > cantidadContratada && cantidadContratada > 0;

              return DataRow(
                cells: [
                  DataCell(
                    Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                  ),
                  DataCell(
                    Text(
                      detalle['nombre_item'] ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 150,
                      child: Text(
                        detalle['descripcion'] ?? '-',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Text(
                        _formatearNumero(cantidadContratada),
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
                        _formatearNumero(totalIngresado),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
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
                        color: stockContrato > 0
                            ? Colors.green.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: stockContrato > 0
                              ? Colors.green.shade200
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Text(
                        _formatearNumero(stockContrato),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: stockContrato > 0
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      decoration: BoxDecoration(
                        color: tieneError ? Colors.red.shade50 : null,
                        borderRadius: BorderRadius.circular(4),
                        border: tieneError
                            ? Border.all(color: Colors.red.shade300)
                            : null,
                      ),
                      child: SizedBox(
                        width: 100,
                        child: TextFormField(
                          controller: _modoEdicion
                              ? (_cantidadAdicionalControllers.length > index
                                    ? _cantidadAdicionalControllers[index]
                                    : TextEditingController())
                              : null,
                          initialValue: _modoEdicion
                              ? null
                              : (baseIngresada == 0
                                    ? ''
                                    : _formatearNumero(baseIngresada)),
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            fontSize: 12,
                            color: tieneError
                                ? Colors.red.shade700
                                : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: _modoEdicion ? '0' : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            isDense: true,
                            errorText: tieneError ? 'Excede' : null,
                            errorStyle: const TextStyle(fontSize: 9),
                          ),
                          onChanged: (value) {
                            if (_modoEdicion) {
                              _actualizarCantidadAdicional(index, value);
                            } else {
                              _actualizarCantidadIngresada(index, value);
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) return null;
                            final cantidad = double.tryParse(value);
                            if (cantidad == null || cantidad < 0)
                              return 'Inválido';
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionDatosIngreso(Color verde, bool isMobile) {
    final usuarioField = TextFormField(
      initialValue: username,
      decoration: InputDecoration(
        labelText: 'Usuario que registra',
        prefixIcon: const Icon(Icons.person, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      readOnly: true,
      enabled: false,
    );

    final numeroField = TextFormField(
      controller: _numeroIngresoController,
      decoration: _inputDeco('Número de Ingreso *', hint: 'Ej: 0001'),
      style: const TextStyle(fontSize: 14),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Ingrese número de ingreso' : null,
    );

    final bodegaField = TextFormField(
      initialValue: BODEGA_FIJA_NOMBRE,
      decoration: InputDecoration(
        labelText: 'Bodega',
        prefixIcon: const Icon(Icons.store, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      readOnly: true,
      enabled: false,
    );

    final fechaField = TextFormField(
      controller: _fechaIngresoController,
      decoration: _inputDeco('Fecha Ingreso *', hint: 'YYYY-MM-DD'),
      style: const TextStyle(fontSize: 14),
      readOnly: true,
      onTap: () => _pickDate(_fechaIngresoController),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Ingrese fecha ingreso' : null,
    );

    final anioField = DropdownButtonFormField<String>(
      value: _anioSeleccionado,
      hint: const Text('Seleccione año contrato *'),
      isExpanded: true,
      items: _aniosDisponibles
          .map(
            (anio) => DropdownMenuItem<String>(value: anio, child: Text(anio)),
          )
          .toList(),
      onChanged: _modoEdicion
          ? null
          : (newValue) {
              setState(() {
                _anioSeleccionado = newValue;
                _contratoSeleccionado = null;
                _contratosDisponibles = [];
                _itemsContrato = [];
                _detallesIngreso = [];
                _objetoContratoController.clear();
              });
              if (newValue != null) _cargarContratosPorAnio(newValue);
            },
      decoration: _inputDeco('Seleccione año contrato *'),
      validator: (v) => v == null ? 'Seleccione un año' : null,
    );

    final contratoField = DropdownButtonFormField<int>(
      value: _contratoSeleccionado,
      hint: const Text('Seleccione Contrato *'),
      isExpanded: true,
      items: _contratosDisponibles
          .map(
            (c) => DropdownMenuItem<int>(
              value: c['id'],
              child: Text(c['numero_contrato'] ?? ''),
            ),
          )
          .toList(),
      onChanged: _modoEdicion
          ? null
          : (newValue) {
              setState(() {
                _contratoSeleccionado = newValue;
                _itemsContrato = [];
                _detallesIngreso = [];
                final contratoSeleccionado = _contratosDisponibles.firstWhere(
                  (c) => c['id'] == newValue,
                  orElse: () => {},
                );
                final objeto =
                    contratoSeleccionado['objeto_contrato']?.toString() ??
                    contratoSeleccionado['objeto']?.toString() ??
                    'No especificado';
                _objetoContratoController.text = objeto;
              });
              if (newValue != null) _cargarItemsContrato(newValue);
            },
      decoration: _inputDeco('Seleccione Contrato *'),
      validator: (v) => v == null ? 'Seleccione un contrato' : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2, color: verde, size: 20),
            const SizedBox(width: 8),
            Text(
              'Datos del Ingreso',
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
        if (isMobile) ...[
          usuarioField,
          const SizedBox(height: 14),
          numeroField,
          const SizedBox(height: 14),
          bodegaField,
          const SizedBox(height: 14),
          fechaField,
          const SizedBox(height: 14),
          anioField,
          const SizedBox(height: 14),
          contratoField,
        ] else ...[
          Row(
            children: [
              Expanded(child: usuarioField),
              const SizedBox(width: 14),
              Expanded(child: numeroField),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: bodegaField),
              const SizedBox(width: 14),
              Expanded(child: fechaField),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: anioField),
              const SizedBox(width: 14),
              Expanded(child: contratoField),
            ],
          ),
        ],
        const SizedBox(height: 14),
        TextFormField(
          controller: _objetoContratoController,
          maxLines: 2,
          decoration: _inputDeco('Objeto del Contrato', alignLabel: true),
          style: const TextStyle(fontSize: 14),
          readOnly: true,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _observacionController,
          maxLines: 2,
          decoration: _inputDeco('Observación', alignLabel: true),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Scaffold(
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 3,
      ),
      body: Column(
        children: [
          _buildResponsiveHeader(verdeInstitucional, isMobile, isTablet),
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
                  ? _buildListaIngresos()
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 12 : 20),
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
                              padding: EdgeInsets.all(isMobile ? 16 : 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSeccionDatosIngreso(
                                    verdeInstitucional,
                                    isMobile,
                                  ),
                                  SizedBox(height: isMobile ? 20 : 24),
                                  _buildSeccionDetalles(
                                    verdeInstitucional,
                                    isMobile,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildBotones(verdeInstitucional),
                                ],
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

  Widget _buildResponsiveHeader(Color verde, bool isMobile, bool isTablet) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 192, 231, 195),
          border: Border(bottom: BorderSide(color: verde, width: 3)),
        ),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/logos/banner_gobernacion.png',
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                  Positioned(
                    left: 0,
                    child: Builder(
                      builder: (ctx) => IconButton(
                        icon: Icon(Icons.menu, color: verde, size: 28),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ),
                  if (!_modoEdicion)
                    Positioned(
                      right: 0,
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _mostrandoLista = !_mostrandoLista);
                            if (_mostrandoLista) _cargarIngresos();
                          },
                          icon: Icon(
                            _mostrandoLista ? Icons.add : Icons.list,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: Text(
                            _mostrandoLista ? 'Nuevo' : 'Listado',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mostrandoLista
                                ? verde
                                : Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                  if (_modoEdicion)
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 26,
                        ),
                        onPressed: () {
                          _limpiarFormulario();
                          setState(() => _mostrandoLista = true);
                        },
                        tooltip: 'Cancelar edición',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _modoEdicion
                  ? 'Editar Ingreso #$_ingresoEditandoId'
                  : 'Registrar Ingresos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 192, 231, 195),
          border: Border(bottom: BorderSide(color: verde, width: 4)),
        ),
        child: Row(
          children: [
            Builder(
              builder: (innerContext) => IconButton(
                icon: Icon(Icons.menu, color: verde, size: 30),
                onPressed: () => Scaffold.of(innerContext).openDrawer(),
                tooltip: 'Abrir menú',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Image.asset(
                'assets/logos/banner_gobernacion.png',
                height: isTablet ? 100 : 130,
                fit: BoxFit.contain,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _modoEdicion
                    ? 'Editar Ingreso #$_ingresoEditandoId'
                    : 'Registrar Ingresos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 22 : 26,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: !_modoEdicion
                    ? SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _mostrandoLista = !_mostrandoLista);
                            if (_mostrandoLista) _cargarIngresos();
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
                            elevation: 2,
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 28,
                        ),
                        onPressed: () {
                          _limpiarFormulario();
                          setState(() => _mostrandoLista = true);
                        },
                        tooltip: 'Cancelar edición',
                      ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    _numeroIngresoController.dispose();
    _fechaIngresoController.dispose();
    _observacionController.dispose();
    _objetoContratoController.dispose();
    _searchController.dispose();
    for (final c in _cantidadAdicionalControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
