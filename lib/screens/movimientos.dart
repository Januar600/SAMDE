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
    bool isMobile,
  ) {
    return Card(
      elevation: 2,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: isMobile ? 28 : 32),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cantidad.toString(),
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Scaffold(
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 6,
      ),
      body: Column(
        children: [
          _buildResponsiveHeader(verde, isMobile, isTablet),
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
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildResumenCards(isMobile),
                    SizedBox(height: isMobile ? 16 : 20),
                    _buildFiltros(verde, isMobile),
                    SizedBox(height: isMobile ? 16 : 20),
                    _buildMovimientos(verde, isMobile),
                  ],
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
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Historial de Movimientos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 192, 231, 195),
          border: Border(bottom: BorderSide(color: verde, width: 4)),
        ),
        child: Row(
          children: [
            Builder(
              builder: (ctx) => IconButton(
                icon: Icon(Icons.menu, color: verde, size: 30),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Image.asset(
                'assets/logos/banner_gobernacion.png',
                height: isTablet ? 100 : 110,
                fit: BoxFit.contain,
              ),
            ),
            Expanded(
              flex: 2,
              child: const Text(
                'Historial de Movimientos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
            const Expanded(flex: 2, child: SizedBox()),
          ],
        ),
      );
    }
  }

  Widget _buildResumenCards(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTarjetaResumen(
                  'Total Ingresos',
                  _totalIngresos,
                  Icons.add_circle,
                  Colors.green,
                  isMobile,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTarjetaResumen(
                  'Total Egresos',
                  _totalEgresos,
                  Icons.remove_circle,
                  Colors.orange,
                  isMobile,
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
                  isMobile,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTarjetaResumen(
                  'Total General',
                  _totalIngresos + _totalEgresos + _totalEntregas,
                  Icons.inventory,
                  Colors.purple,
                  isMobile,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTarjetaResumen(
                  'Total Ingresos',
                  _totalIngresos,
                  Icons.add_circle,
                  Colors.green,
                  isMobile,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTarjetaResumen(
                  'Total Egresos',
                  _totalEgresos,
                  Icons.remove_circle,
                  Colors.orange,
                  isMobile,
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
                  isMobile,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTarjetaResumen(
                  'Total General',
                  _totalIngresos + _totalEgresos + _totalEntregas,
                  Icons.inventory,
                  Colors.purple,
                  isMobile,
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildFiltros(Color verde, bool isMobile) {
    final fechaInicioField = TextField(
      controller: _fechaInicioController,
      decoration: InputDecoration(
        labelText: 'Fecha Inicio',
        hintText: 'YYYY-MM-DD',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () => _pickDate(_fechaInicioController),
        ),
      ),
      readOnly: true,
    );

    final fechaFinField = TextField(
      controller: _fechaFinController,
      decoration: InputDecoration(
        labelText: 'Fecha Fin',
        hintText: 'YYYY-MM-DD',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () => _pickDate(_fechaFinController),
        ),
      ),
      readOnly: true,
    );

    final tipoMovimientoField = DropdownButtonFormField<String>(
      value: _tipoMovimientoSeleccionado,
      hint: const Text('Tipo de Movimiento'),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: ['INGRESO', 'EGRESO', 'ENTREGA', 'AJUSTE']
          .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
          .toList(),
      onChanged: (value) {
        setState(() {
          _tipoMovimientoSeleccionado = value;
          _aplicarFiltros();
        });
      },
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: verde, size: isMobile ? 18 : 20),
                const SizedBox(width: 8),
                Text(
                  'Filtros de Búsqueda',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            if (isMobile) ...[
              fechaInicioField,
              const SizedBox(height: 12),
              fechaFinField,
              const SizedBox(height: 12),
              tipoMovimientoField,
            ] else ...[
              Row(
                children: [
                  Expanded(child: fechaInicioField),
                  const SizedBox(width: 12),
                  Expanded(child: fechaFinField),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: tipoMovimientoField)]),
            ],
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
                  label: Text(
                    'Limpiar',
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _cargarMovimientos,
                  icon: const Icon(Icons.search),
                  label: Text(
                    'Buscar',
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                  ),
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
    );
  }

  Widget _buildMovimientos(Color verde, bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.table_chart, color: verde, size: isMobile ? 18 : 20),
                const SizedBox(width: 8),
                Text(
                  'Movimientos Registrados',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
                const Spacer(),
                Text(
                  'Filas: ${_movimientosFiltrados.length}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            _cargando
                ? const Center(child: CircularProgressIndicator())
                : _movimientosFiltrados.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No hay movimientos registrados',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                : isMobile
                ? _buildMovimientosMobile(verde)
                : _buildMovimientosDesktop(verde),
          ],
        ),
      ),
    );
  }

  Widget _buildMovimientosMobile(Color verde) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _movimientosFiltrados.length,
      itemBuilder: (context, index) {
        final mov = _movimientosFiltrados[index];
        final tipoLimpio = _limpiarTipoMovimiento(mov['tipo_movimiento']);
        final colorTipo = _getColorTipoMovimiento(tipoLimpio);
        final iconoTipo = _getIconoTipoMovimiento(tipoLimpio);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
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
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorTipo.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(iconoTipo, color: colorTipo, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            tipoLimpio,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colorTipo,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatearFecha(mov['fecha_movimiento']),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  mov['nombre_items'] ?? 'Sin item',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildBadge(
                      'Contrato',
                      mov['numero_contrato'] ?? 'N/A',
                      Colors.blue,
                    ),
                    _buildBadge(
                      'Bodega',
                      mov['bodega_nombre'] ?? 'N/A',
                      Colors.purple,
                    ),
                    _buildBadge(
                      'Cantidad',
                      _formatearNumero(mov['cantidad']),
                      Colors.orange,
                    ),
                    _buildBadge(
                      'Stock',
                      _formatearNumero(mov['stock_actual']),
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.description,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        mov['documento_numero'] ?? '-',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        mov['usuario_nombre'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
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

  Widget _buildMovimientosDesktop(Color verde) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12,
        headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
        columns: [
          DataColumn(
            label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Contrato',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('Item', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Bodega',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Cantidad',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          DataColumn(
            label: Text(
              'Documento',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataColumn(
            label: Text(
              'Usuario',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: _movimientosFiltrados.map((mov) {
          final tipoLimpio = _limpiarTipoMovimiento(mov['tipo_movimiento']);

          return DataRow(
            cells: [
              DataCell(Text(_formatearFecha(mov['fecha_movimiento']))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    mov['numero_contrato'] ?? 'N/A',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),
              DataCell(Text(mov['nombre_items'] ?? '')),
              DataCell(Text(mov['bodega_nombre'] ?? '')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIconoTipoMovimiento(tipoLimpio),
                      color: _getColorTipoMovimiento(tipoLimpio),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(tipoLimpio),
                  ],
                ),
              ),
              DataCell(Text(_formatearNumero(mov['cantidad']))),
              DataCell(Text(_formatearNumero(mov['stock_actual']))),
              DataCell(Text(mov['documento_numero'] ?? '-')),
              DataCell(Text(mov['usuario_nombre'] ?? 'N/A')),
            ],
          );
        }).toList(),
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
