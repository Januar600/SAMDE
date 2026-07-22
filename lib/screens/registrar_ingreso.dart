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
  // -------- VARIABLES DE USUARIO --------
  late String username;
  late String sector;
  late String rol;

  // -------- CONTROLADORES DEL FORMULARIO --------
  final _formKey = GlobalKey<FormState>();
  final _numeroIngresoController = TextEditingController();
  final _fechaIngresoController = TextEditingController();
  final _observacionController = TextEditingController();
  final _searchController = TextEditingController();

  // -------- VARIABLES DE BÚSQUEDA --------
  String _searchQuery = '';
  List<Map<String, dynamic>> _ingresosFiltrados = [];

  // -------- VARIABLES DEL FORMULARIO --------
  String? _anioSeleccionado;
  int? _contratoSeleccionado;
  static const int BODEGA_FIJA_ID = 1;
  static const String BODEGA_FIJA_NOMBRE = 'Gobernación';

  // -------- LISTAS DE DATOS --------
  List<String> _aniosDisponibles = [];
  List<Map<String, dynamic>> _contratosDisponibles = [];
  List<Map<String, dynamic>> _itemsContrato = [];
  List<Map<String, dynamic>> _detallesIngreso = [];
  List<Map<String, dynamic>> _ingresos = [];

  // -------- ESTADOS DE CARGA Y VISUALIZACIÓN --------
  bool _cargando = false;
  bool _mostrandoLista = false;
  bool _modoEdicion = false;
  int? _ingresoEditandoId;

  // -------- URL DE LA API --------
  static const String _baseUrl = 'http://localhost/samde_db/api';

  // -------- CICLO DE VIDA --------
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

  // -------- ✅ SELECCIONAR FECHA CON DATEPICKER (IGUAL QUE CONTRATOS) --------
  Future<void> _pickDate(TextEditingController ctrl) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha != null) ctrl.text = fecha.toIso8601String().substring(0, 10);
  }

  // -------- ✅ FUNCIÓN PARA FORMATEAR FECHA (SIMPLIFICADA) --------
  String _formatearFechaParaBD(String fecha) {
    if (fecha.isEmpty) return '';
    return fecha;
  }

  // -------- ✅ FUNCIÓN AUXILIAR PARA CONVERTIR A DOUBLE --------
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

  // -------- ✅ FUNCIÓN AUXILIAR PARA CONVERTIR A NÚMERO (INT) --------
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

  // -------- FORMATEAR PRECIO CON PUNTOS DE MIL --------
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
      if (contador % 3 == 0 && i != 0) {
        resultado = '.' + resultado;
      }
    }

    return '\$$resultado';
  }

  // -------- FORMATEAR NÚMERO (CANTIDADES) --------
  String _formatearNumero(dynamic valor) {
    if (valor == null) return '0';
    final double numero = valor is double
        ? valor
        : double.tryParse(valor.toString()) ?? 0;
    return numero == numero.truncateToDouble()
        ? numero.truncate().toString()
        : numero.toStringAsFixed(2);
  }

  // -------- ✅ VALIDAR CANTIDADES INGRESADAS --------
  bool _validarCantidades() {
    for (var detalle in _detallesIngreso) {
      final double contratada = detalle['cantidad_contratada'] ?? 0;
      final double ingresada = detalle['cantidad_ingresada'] ?? 0;

      if (ingresada > contratada) {
        _mostrarMensaje(
          '⚠️ La cantidad ingresada (${_formatearNumero(ingresada)}) no puede ser mayor a la contratada (${_formatearNumero(contratada)}) para "${detalle['nombre_item']}"',
          Colors.orange,
        );
        return false;
      }
    }
    return true;
  }

  // -------- MÉTODOS DE FILTRADO --------
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

  // -------- CARGAR AÑOS DISPONIBLES --------
  void _cargarAnios() {
    final anioActual = DateTime.now().year;
    _aniosDisponibles = [
      (anioActual - 2).toString(),
      (anioActual - 1).toString(),
      ...List.generate(10, (index) => (anioActual + index).toString()),
    ].toSet().toList()..sort();
  }

  // -------- CARGAR CONTRATOS POR AÑO --------
  Future<void> _cargarContratosPorAnio(String anio) async {
    setState(() => _cargando = true);
    _contratosDisponibles = [];
    _itemsContrato = [];
    _detallesIngreso = [];

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/contratos/listar_contrato.php'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

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

  // -------- ✅ CARGAR TODOS LOS CONTRATOS --------
  Future<void> _cargarTodosLosContratos() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/contratos/listar_contrato.php'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final todos = List<Map<String, dynamic>>.from(data['data'] ?? []);
          setState(() {
            _contratosDisponibles = todos;
          });
        }
      }
    } catch (e) {
      debugPrint('Error cargando todos los contratos: $e');
    }
  }

  // -------- CARGAR ITEMS DEL CONTRATO --------
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
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

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

  // -------- ACTUALIZAR CANTIDAD INGRESADA --------
  void _actualizarCantidadIngresada(int index, String valor) {
    final cantidad = double.tryParse(valor) ?? 0;
    final contratada = _detallesIngreso[index]['cantidad_contratada'] ?? 0;

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

  // -------- MOSTRAR MENSAJES --------
  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  // -------- REGISTRAR INGRESO --------
  Future<void> _registrarIngreso() async {
    if (!_formKey.currentState!.validate()) return;

    if (_contratoSeleccionado == null) {
      _mostrarMensaje('Seleccione un contrato', Colors.orange);
      return;
    }

    if (!_detallesIngreso.any((d) => (d['cantidad_ingresada'] ?? 0) > 0)) {
      _mostrarMensaje(
        'Debe ingresar al menos un item con cantidad > 0',
        Colors.orange,
      );
      return;
    }

    if (!_validarCantidades()) {
      return;
    }

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
                      'cantidad_ingresada': d['cantidad_ingresada'] ?? 0,
                      'precio_unitario': d['precio_unitario'] ?? 0,
                    }),
                  )
                  .toList(),
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw Exception('⏰ El servidor no respondió a tiempo'),
          );

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

  // -------- VER DETALLE DEL INGRESO --------
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
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          final ingresoData = data['data']['ingreso'];
          final detallesRaw = data['data']['detalles'] as List;

          final List<Map<String, dynamic>> detalles = detallesRaw.map((item) {
            return Map<String, dynamic>.from(item);
          }).toList();

          if (mounted) {
            _mostrarDialogoDetalle(ingresoData, detalles);
          }
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

  // -------- MOSTRAR DIÁLOGO DE DETALLE (CORREGIDO) --------
  void _mostrarDialogoDetalle(
    Map<String, dynamic> ingresoData,
    List<Map<String, dynamic>> detalles,
  ) {
    // ✅ DEBUG: Ver qué datos llegan
    print('═══════════════════════════════════════');
    print('📋 DATOS DEL INGRESO:');
    print('  usuario_registro: ${ingresoData['usuario_registro']}');
    print('  usuario_nombre: ${ingresoData['usuario_nombre']}');
    print('  usuario_id: ${ingresoData['usuario_id']}');
    print('═══════════════════════════════════════');

    String observacion = (ingresoData['observacion'] ?? '').toString().trim();

    // ✅ CORREGIDO: Mostrar usuario_nombre o usuario_registro
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
          content: SizedBox(
            width: 600,
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
                  _buildInfoRow(
                    'Usuario',
                    usuario,
                  ), // ✅ USAR VARIABLE CORREGIDA
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
                          headingRowColor: MaterialStateProperty.all(
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
                            final subtotal = cantidadIngresada * precioUnitario;

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
                                  Text(
                                    _formatearNumero(
                                      detalle['cantidad_contratada'],
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _formatearNumero(
                                      detalle['cantidad_ingresada'],
                                    ),
                                    style: const TextStyle(fontSize: 12),
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

                  if (detalles.isNotEmpty) ...[_buildTotalRow(detalles)],
                ],
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

  // -------- CONSTRUIR FILA DE INFORMACIÓN --------
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

  // -------- CONSTRUIR FILA DE TOTALES --------
  Widget _buildTotalRow(List<Map<String, dynamic>> detalles) {
    double total = 0;
    for (var detalle in detalles) {
      final cantidad = _convertirADouble(detalle['cantidad_ingresada']);
      final precio = _convertirADouble(detalle['precio_unitario']);
      total += cantidad * precio;
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

  // -------- CARGAR INGRESO PARA EDITAR --------
  Future<void> _cargarIngresoParaEditar(int ingresoId) async {
    setState(() => _cargando = true);

    final url = Uri.parse(
      '$_baseUrl/ingresos/obtener_ingreso.php?id=$ingresoId',
    );

    try {
      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

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

        // 1. Asegurar que el año esté en la lista de años disponibles
        if (anioContrato.isNotEmpty &&
            !_aniosDisponibles.contains(anioContrato)) {
          _aniosDisponibles.add(anioContrato);
          _aniosDisponibles.sort();
        }

        // 2. Cargar todos los contratos para tener el mayor contexto posible
        await _cargarTodosLosContratos();

        final contratoId = _convertirANumero(ingresoData['contrato_id']);
        final numeroContrato = ingresoData['numero_contrato'] ?? 'N/A';

        // 3. Verificar si el contrato ya está en la lista
        bool contratoExiste = _contratosDisponibles.any(
          (c) => c['id'] == contratoId,
        );

        // 4. SI NO EXISTE, lo agregamos manualmente para que el dropdown pueda mostrarlo
        if (!contratoExiste) {
          _contratosDisponibles.add({
            'id': contratoId,
            'numero_contrato': numeroContrato,
          });
        }

        setState(() {
          _modoEdicion = true;
          _ingresoEditandoId = ingresoId;

          _numeroIngresoController.text = ingresoData['numero_ingreso'] ?? '';
          _fechaIngresoController.text = fechaIngreso;
          _observacionController.text = ingresoData['observacion'] ?? '';

          _anioSeleccionado = anioContrato;
          _contratoSeleccionado =
              contratoId; // Ahora siempre tendrá un valor válido

          _detallesIngreso = detallesData.map((detalle) {
            return {
              'id_item_contrato': _convertirANumero(
                detalle['id_item_contrato'],
              ),
              'nombre_item': detalle['nombre_item']?.toString() ?? '',
              'descripcion': detalle['descripcion']?.toString() ?? '',
              'cantidad_contratada': _convertirADouble(
                detalle['cantidad_contratada'],
              ),
              'cantidad_ingresada': _convertirADouble(
                detalle['cantidad_ingresada'],
              ),
              'precio_unitario': _convertirADouble(
                detalle['valor_unitario'] ?? detalle['precio_unitario'] ?? 0,
              ),
            };
          }).toList();
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

  // -------- ACTUALIZAR INGRESO --------
  Future<void> _actualizarIngreso() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_detallesIngreso.any((d) => (d['cantidad_ingresada'] ?? 0) > 0)) {
      _mostrarMensaje(
        'Debe ingresar al menos un item con cantidad > 0',
        Colors.orange,
      );
      return;
    }

    if (!_validarCantidades()) {
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
              'detalles': _detallesIngreso
                  .map(
                    (d) => ({
                      'id_item_contrato': d['id_item_contrato'],
                      'cantidad_ingresada': d['cantidad_ingresada'] ?? 0,
                      'precio_unitario': d['precio_unitario'] ?? 0,
                    }),
                  )
                  .toList(),
            }),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw Exception('⏰ El servidor no respondió a tiempo'),
          );

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

  // -------- ELIMINAR INGRESO --------
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
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

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

  // -------- CARGAR INGRESOS --------
  Future<void> _cargarIngresos() async {
    setState(() => _cargando = true);

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/ingresos/listar_ingresos.php'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

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

  // -------- LIMPIAR FORMULARIO --------
  void _limpiarFormulario() {
    _numeroIngresoController.clear();
    _fechaIngresoController.clear();
    _observacionController.clear();
    _anioSeleccionado = null;
    _contratoSeleccionado = null;
    _contratosDisponibles = [];
    _itemsContrato = [];
    _detallesIngreso = [];
    _modoEdicion = false;
    _ingresoEditandoId = null;
  }

  // -------- DECORACIÓN DE INPUT --------
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

  // -------- COLUMNA DE DATATABLE --------
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

  // -------- CONSTRUIR TARJETA DE INGRESO --------
  Widget _buildCardIngreso(Map<String, dynamic> ingreso, Color verde) {
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------- LISTA DE INGRESOS CON BÚSQUEDA --------
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

  // -------- BOTONES DE ACCIÓN --------
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
                    if (!_validarCantidades()) {
                      return;
                    }
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

  // -------- SECCIÓN: DETALLES DEL INGRESO --------
  Widget _buildSeccionDetalles(Color verde) {
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
            : Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IntrinsicHeight(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 12,
                      headingRowHeight: 36,
                      headingRowColor: MaterialStateProperty.all(
                        Colors.green.shade50,
                      ),
                      columns: [
                        _buildDataColumn('#', verde),
                        _buildDataColumn('Contrato', verde),
                        _buildDataColumn('Item', verde),
                        _buildDataColumn('Descripción', verde),
                        _buildDataColumn('Cant. Contratada', verde),
                        _buildDataColumn('Cant. a Ingresar *', verde),
                      ],
                      rows: _detallesIngreso.asMap().entries.map((entry) {
                        final index = entry.key;
                        final detalle = entry.value;
                        final cantidadIngresada =
                            detalle['cantidad_ingresada'] ?? 0;
                        final cantidadContratada =
                            detalle['cantidad_contratada'] ?? 0;
                        final tieneError =
                            cantidadIngresada > cantidadContratada;

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                '${index + 1}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
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
                                  _contratoSeleccionado?.toString() ?? '-',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: verde,
                                  ),
                                ),
                              ),
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
                              Text(
                                _formatearNumero(
                                  detalle['cantidad_contratada'],
                                ),
                                style: const TextStyle(fontSize: 12),
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
                                    initialValue:
                                        detalle['cantidad_ingresada'] == 0
                                        ? ''
                                        : _formatearNumero(
                                            detalle['cantidad_ingresada'],
                                          ),
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tieneError
                                          ? Colors.red.shade700
                                          : Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                      isDense: true,
                                      errorText: tieneError ? 'Excede' : null,
                                      errorStyle: TextStyle(
                                        fontSize: 9,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    onChanged: (value) =>
                                        _actualizarCantidadIngresada(
                                          index,
                                          value,
                                        ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty)
                                        return null;
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
              ),
      ],
    );
  }

  // -------- SECCIÓN: DATOS DEL INGRESO --------
  Widget _buildSeccionDatosIngreso(Color verde) {
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

        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: username,
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                readOnly: true,
                enabled: false,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _numeroIngresoController,
                decoration: _inputDeco('Número de Ingreso *', hint: 'Ej: 0001'),
                style: const TextStyle(fontSize: 14),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese número de ingreso'
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                readOnly: true,
                enabled: false,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _fechaIngresoController,
                decoration: _inputDeco('Fecha Ingreso *', hint: 'YYYY-MM-DD'),
                style: const TextStyle(fontSize: 14),
                readOnly: true,
                onTap: () => _pickDate(_fechaIngresoController),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese fecha ingreso'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _anioSeleccionado,
                hint: const Text('Seleccione año contrato *'),
                isExpanded: true,
                items: _aniosDisponibles
                    .map(
                      (anio) => DropdownMenuItem<String>(
                        value: anio,
                        child: Text(anio),
                      ),
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
                        });
                        if (newValue != null) _cargarContratosPorAnio(newValue);
                      },
                decoration: _inputDeco('Seleccione año contrato *'),
                validator: (v) => v == null ? 'Seleccione un año' : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonFormField<int>(
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
                        });
                        if (newValue != null) _cargarItemsContrato(newValue);
                      },
                decoration: _inputDeco('Seleccione Contrato *'),
                validator: (v) => v == null ? 'Seleccione un contrato' : null,
              ),
            ),
          ],
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

  // -------- BUILD --------
  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);

    return Scaffold(
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 3,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 192, 231, 195),
              border: Border(
                bottom: BorderSide(color: verdeInstitucional, width: 4),
              ),
            ),
            child: Row(
              children: [
                Builder(
                  builder: (innerContext) => IconButton(
                    icon: const Icon(
                      Icons.menu,
                      color: verdeInstitucional,
                      size: 30,
                    ),
                    onPressed: () => Scaffold.of(innerContext).openDrawer(),
                    tooltip: 'Abrir menú',
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
                          ? 'Editar Ingreso #$_ingresoEditandoId'
                          : 'Registrar Ingresos',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
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
                            ? verdeInstitucional
                            : Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
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
                    tooltip: 'Cancelar edición',
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
                  ? _buildListaIngresos()
                  : Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
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
                                    _buildSeccionDatosIngreso(
                                      verdeInstitucional,
                                    ),
                                    const SizedBox(height: 20),
                                    _buildSeccionDetalles(verdeInstitucional),
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
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _numeroIngresoController.dispose();
    _fechaIngresoController.dispose();
    _observacionController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
