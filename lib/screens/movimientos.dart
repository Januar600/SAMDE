import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/drawer_menu.dart';

class HistorialMovimientosPage extends StatefulWidget {
  const HistorialMovimientosPage({super.key});

  @override
  State<HistorialMovimientosPage> createState() =>
      _HistorialMovimientosPageState();
}

class _HistorialMovimientosPageState extends State<HistorialMovimientosPage> {
  late String username;
  late String sector;
  late String rol;

  final TextEditingController _fechaInicioController = TextEditingController();
  final TextEditingController _fechaFinController = TextEditingController();

  String? _tipoMovimientoSeleccionado;
  int? _bodegaSeleccionada;
  int? _contratoSeleccionado;

  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _movimientosFiltrados = [];
  bool _cargando = false;

  // Totales que vendrán directamente de la API
  int _totalIngresos = 0;
  int _totalEgresos = 0;
  int _totalEntregas = 0;

  static const String _baseUrl = 'http://localhost/samde_db/api';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
    username = map['username'] ?? 'Usuario';
    sector = map['sector'] ?? 'No Asignado';
    rol = map['rol'] ?? 'consulta';
  }

  @override
  void initState() {
    super.initState();
    _cargarMovimientos();
  }

  // ✅ NUEVA FUNCIÓN: Limpia el tipo de movimiento quitando números al final (ej: "EGRESO 1" -> "EGRESO")
  String _limpiarTipoMovimiento(String? tipo) {
    if (tipo == null) return '';
    return tipo.replaceAll(RegExp(r'\s*\d+$'), '').trim();
  }

  Future<void> _cargarMovimientos() async {
    setState(() => _cargando = true);

    try {
      String url = '$_baseUrl/movimientos/listar_movimientos.php';
      final params = <String, String>{};

      if (_fechaInicioController.text.isNotEmpty) {
        params['fecha_inicio'] = _fechaInicioController.text;
      }
      if (_fechaFinController.text.isNotEmpty) {
        params['fecha_fin'] = _fechaFinController.text;
      }
      if (_tipoMovimientoSeleccionado != null) {
        params['tipo_movimiento'] = _tipoMovimientoSeleccionado!;
      }
      if (_bodegaSeleccionada != null) {
        params['bodega_id'] = _bodegaSeleccionada.toString();
      }
      if (_contratoSeleccionado != null) {
        params['contrato_id'] = _contratoSeleccionado.toString();
      }

      if (params.isNotEmpty) {
        final uri = Uri.parse(url).replace(queryParameters: params);
        url = uri.toString();
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _movimientos = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _movimientosFiltrados = List.from(_movimientos);

          _totalIngresos = data['total_ingresos'] ?? 0;
          _totalEgresos = data['total_egresos'] ?? 0;
          _totalEntregas = data['total_entregas'] ?? 0;
        });
      } else {
        _mostrarMensaje('Error al cargar movimientos', Colors.red);
      }
    } catch (e) {
      _mostrarMensaje('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _aplicarFiltros() {
    setState(() {
      if (_tipoMovimientoSeleccionado == null) {
        _movimientosFiltrados = List.from(_movimientos);
      } else {
        _movimientosFiltrados = _movimientos
            .where(
              (m) =>
                  _limpiarTipoMovimiento(m['tipo_movimiento']) ==
                  _tipoMovimientoSeleccionado,
            )
            .toList();
      }
    });
  }

  void _mostrarMensaje(String mensaje, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: color));
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (fecha != null) {
      controller.text = fecha.toIso8601String().substring(0, 10);
    }
  }

  Widget _buildTarjetaResumen(
    String titulo,
    int cantidad,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cantidad.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ACTUALIZADO: Usa la función de limpieza para determinar el color
  Color _getColorTipoMovimiento(String tipo) {
    final tipoLimpio = _limpiarTipoMovimiento(tipo).toUpperCase();
    switch (tipoLimpio) {
      case 'INGRESO':
        return Colors.green;
      case 'EGRESO':
        return Colors.orange;
      case 'ENTREGA':
        return Colors.blue;
      case 'AJUSTE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ✅ ACTUALIZADO: Usa la función de limpieza para determinar el ícono
  IconData _getIconoTipoMovimiento(String tipo) {
    final tipoLimpio = _limpiarTipoMovimiento(tipo).toUpperCase();
    switch (tipoLimpio) {
      case 'INGRESO':
        return Icons.add_circle;
      case 'EGRESO':
        return Icons.remove_circle;
      case 'ENTREGA':
        return Icons.handshake;
      case 'AJUSTE':
        return Icons.tune;
      default:
        return Icons.inventory;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF2E7D32);

    return Scaffold(
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 6,
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
                const Expanded(
                  child: Center(
                    child: Text(
                      'Historial de Movimientos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                  ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTarjetaResumen(
                            'Total Ingresos',
                            _totalIngresos,
                            Icons.add_circle,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTarjetaResumen(
                            'Total Egresos',
                            _totalEgresos,
                            Icons.remove_circle,
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTarjetaResumen(
                            'Total Entregas',
                            _totalEntregas,
                            Icons.handshake,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTarjetaResumen(
                            'Total General',
                            _totalIngresos + _totalEgresos + _totalEntregas,
                            Icons.inventory,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.filter_list, color: verde),
                                const SizedBox(width: 8),
                                Text(
                                  'Filtros de Búsqueda',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: verde,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _fechaInicioController,
                                    decoration: InputDecoration(
                                      labelText: 'Fecha Inicio',
                                      hintText: 'YYYY-MM-DD',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.calendar_today),
                                        onPressed: () =>
                                            _pickDate(_fechaInicioController),
                                      ),
                                    ),
                                    readOnly: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _fechaFinController,
                                    decoration: InputDecoration(
                                      labelText: 'Fecha Fin',
                                      hintText: 'YYYY-MM-DD',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: const Icon(Icons.calendar_today),
                                        onPressed: () =>
                                            _pickDate(_fechaFinController),
                                      ),
                                    ),
                                    readOnly: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _tipoMovimientoSeleccionado,
                                    hint: const Text('Tipo de Movimiento'),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    items:
                                        [
                                          'INGRESO',
                                          'EGRESO',
                                          'ENTREGA',
                                          'AJUSTE',
                                        ].map((tipo) {
                                          return DropdownMenuItem(
                                            value: tipo,
                                            child: Text(tipo),
                                          );
                                        }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _tipoMovimientoSeleccionado = value;
                                        _aplicarFiltros();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _fechaInicioController.clear();
                                      _fechaFinController.clear();
                                      _tipoMovimientoSeleccionado = null;
                                      _bodegaSeleccionada = null;
                                      _contratoSeleccionado = null;
                                    });
                                    _cargarMovimientos();
                                  },
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Limpiar Filtros'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _cargarMovimientos,
                                  icon: const Icon(Icons.search),
                                  label: const Text('Buscar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: verde,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.table_chart, color: verde),
                                const SizedBox(width: 8),
                                Text(
                                  'Movimientos Registrados',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: verde,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Filas: ${_movimientosFiltrados.length}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _cargando
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _movimientosFiltrados.isEmpty
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Text(
                                        'No hay movimientos registrados',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columnSpacing: 12,
                                      headingRowColor: WidgetStateProperty.all(
                                        Colors.green.shade50,
                                      ),
                                      columns: [
                                        DataColumn(
                                          label: Text(
                                            'Fecha',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Contrato',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Item',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Bodega',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Tipo',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Cantidad',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Stock',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Documento',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Usuario',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: _movimientosFiltrados.map((mov) {
                                        // ✅ Usamos la función de limpieza aquí
                                        final tipoLimpio =
                                            _limpiarTipoMovimiento(
                                              mov['tipo_movimiento'],
                                            );

                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                _formatearFecha(
                                                  mov['fecha_movimiento'],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  mov['numero_contrato'] ??
                                                      'N/A',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(mov['nombre_items'] ?? ''),
                                            ),
                                            DataCell(
                                              Text(mov['bodega_nombre'] ?? ''),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _getIconoTipoMovimiento(
                                                      tipoLimpio,
                                                    ),
                                                    color:
                                                        _getColorTipoMovimiento(
                                                          tipoLimpio,
                                                        ),
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    tipoLimpio, // ✅ AQUÍ SE MUESTRA SIN EL NÚMERO
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                _formatearNumero(
                                                  mov['cantidad'],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                _formatearNumero(
                                                  mov['stock_actual'],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                mov['documento_numero'] ?? '-',
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                mov['usuario_nombre'] ?? 'N/A',
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(String? fecha) {
    if (fecha == null || fecha.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(fecha);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (e) {
      return fecha;
    }
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

  @override
  void dispose() {
    _fechaInicioController.dispose();
    _fechaFinController.dispose();
    super.dispose();
  }
}
