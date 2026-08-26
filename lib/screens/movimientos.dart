import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/drawer_menu.dart'; // Ajusta esta ruta si es necesario

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
  final TextEditingController _searchController = TextEditingController();

  String? _tipoMovimientoSeleccionado;
  String? _rangoSeleccionado;
  String _filtroLocal = '';

  int? _bodegaSeleccionada;
  int? _contratoSeleccionado;

  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _movimientosFiltrados = [];
  bool _cargando = false;

  int _totalIngresos = 0;
  int _totalEgresos = 0;
  int _totalEntregas = 0;
  int _totalAjustes = 0; // 🆕
  int _totalEliminados = 0; // 🆕

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

  @override
  void dispose() {
    _fechaInicioController.dispose();
    _fechaFinController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── HELPERS ──────────────────────────────────────────────────
  String _limpiarTipoMovimiento(String? tipo) {
    if (tipo == null) return '';
    return tipo.replaceAll(RegExp(r'\s*\d+$'), '').trim().toUpperCase();
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String _formatearNumero(dynamic valor) {
    if (valor == null) return '0';
    final double n = _toDouble(valor);
    return n == n.truncateToDouble()
        ? n.truncate().toString()
        : n.toStringAsFixed(2);
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

  // 🆕 ACTUALIZADO: Colores para todos los tipos
  Color _getColorTipoMovimiento(String tipo) {
    switch (tipo) {
      case 'INGRESO':
        return Colors.green;
      case 'EGRESO':
        return Colors.orange;
      case 'ENTREGA':
        return Colors.blue;
      case 'AJUSTE':
        return Colors.amber.shade700;
      case 'ELIMINO':
        return Colors.red.shade700;
      default:
        return Colors.grey;
    }
  }

  // 🆕 ACTUALIZADO: Iconos para todos los tipos
  IconData _getIconoTipoMovimiento(String tipo) {
    switch (tipo) {
      case 'INGRESO':
        return Icons.add_circle;
      case 'EGRESO':
        return Icons.remove_circle;
      case 'ENTREGA':
        return Icons.handshake;
      case 'AJUSTE':
        return Icons.edit_note;
      case 'ELIMINO':
        return Icons.delete_forever;
      default:
        return Icons.inventory;
    }
  }

  // ── DATOS ────────────────────────────────────────────────────
  Future<void> _cargarMovimientos() async {
    setState(() => _cargando = true);

    try {
      String url = '$_baseUrl/movimientos/listar_movimientos.php';
      final params = <String, String>{};

      if (_fechaInicioController.text.isNotEmpty)
        params['fecha_inicio'] = _fechaInicioController.text;
      if (_fechaFinController.text.isNotEmpty)
        params['fecha_fin'] = _fechaFinController.text;
      if (_bodegaSeleccionada != null)
        params['bodega_id'] = _bodegaSeleccionada.toString();
      if (_contratoSeleccionado != null)
        params['contrato_id'] = _contratoSeleccionado.toString();

      if (params.isNotEmpty) {
        url = Uri.parse(url).replace(queryParameters: params).toString();
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
          _totalIngresos = data['total_ingresos'] ?? 0;
          _totalEgresos = data['total_egresos'] ?? 0;
          _totalEntregas = data['total_entregas'] ?? 0;
          _totalAjustes = data['total_ajustes'] ?? 0; // 🆕
          _totalEliminados = data['total_eliminados'] ?? 0; // 🆕
        });
        _aplicarFiltros();
      } else {
        _mostrarMensaje('Error al cargar movimientos', Colors.red);
      }
    } catch (e) {
      _mostrarMensaje('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ── FILTROS ──────────────────────────────────────────────────
  void _aplicarFiltros() {
    setState(() {
      _movimientosFiltrados = _movimientos.where((m) {
        final tipoOk =
            _tipoMovimientoSeleccionado == null ||
            _limpiarTipoMovimiento(m['tipo_movimiento']) ==
                _tipoMovimientoSeleccionado;

        final q = _filtroLocal.toLowerCase().trim();
        final searchOk =
            q.isEmpty ||
            (m['nombre_items'] ?? '').toString().toLowerCase().contains(q) ||
            (m['numero_contrato'] ?? '').toString().toLowerCase().contains(q) ||
            (m['usuario_nombre'] ?? '').toString().toLowerCase().contains(q) ||
            (m['bodega_nombre'] ?? '').toString().toLowerCase().contains(q) ||
            (m['documento_numero'] ?? '').toString().toLowerCase().contains(q);

        return tipoOk && searchOk;
      }).toList();
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
      setState(() {
        controller.text = fecha.toIso8601String().substring(0, 10);
        _rangoSeleccionado = null;
      });
    }
  }

  void _establecerRangoRapido(String tipo) {
    final ahora = DateTime.now();
    DateTime inicio;
    DateTime fin;

    switch (tipo) {
      case 'hoy':
        inicio = DateTime(ahora.year, ahora.month, ahora.day);
        fin = ahora;
        break;
      case 'mes_actual':
        inicio = DateTime(ahora.year, ahora.month, 1);
        fin = ahora;
        break;
      case 'mes_anterior':
        inicio = DateTime(ahora.year, ahora.month - 1, 1);
        fin = DateTime(ahora.year, ahora.month, 0);
        break;
      case 'anio_actual':
        inicio = DateTime(ahora.year, 1, 1);
        fin = ahora;
        break;
      default:
        return;
    }

    setState(() {
      _rangoSeleccionado = tipo;
      _fechaInicioController.text = inicio.toIso8601String().substring(0, 10);
      _fechaFinController.text = fin.toIso8601String().substring(0, 10);
    });
  }

  // ── WIDGETS DE VISUALIZACIÓN ─────────────────────────────────

  // 🆕 ACTUALIZADO: Lógica inteligente para auditoría vs inventario
  Widget _buildCantidad(Map<String, dynamic> mov, bool isMobile) {
    final tipo = _limpiarTipoMovimiento(mov['tipo_movimiento']).toUpperCase();
    final color = _getColorTipoMovimiento(tipo);
    final icon = _getIconoTipoMovimiento(tipo);

    // Si es auditoría de registro, no mostramos cantidad numérica
    if (tipo == 'AJUSTE' || tipo == 'ELIMINO') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isMobile ? 14 : 16),
          const SizedBox(width: 4),
          Text(
            tipo == 'AJUSTE' ? 'Modificado' : 'Eliminado',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: isMobile ? 13 : 14,
            ),
          ),
        ],
      );
    }

    // Lógica original intacta para movimientos de inventario
    String signo = '';
    if (tipo == 'INGRESO') signo = '+';
    if (tipo == 'EGRESO') signo = '+'; // ✅ Respeta tu flujo de bodega destino
    if (tipo == 'ENTREGA') signo = '-';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: isMobile ? 14 : 16),
        const SizedBox(width: 4),
        Text(
          '$signo${_formatearNumero(mov['cantidad'])}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: isMobile ? 13 : 14,
          ),
        ),
      ],
    );
  }

  // 🆕 ACTUALIZADO: Manejo de stock nulo para auditorías
  Widget _buildStock(dynamic stock, String tipo, bool isMobile) {
    if (tipo == 'AJUSTE' || tipo == 'ELIMINO') {
      return Text(
        'N/A',
        style: TextStyle(
          fontSize: isMobile ? 12 : 13,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final double n = _toDouble(stock);
    Color color;
    IconData icon;

    if (n <= 0) {
      color = Colors.red;
      icon = Icons.error_outline;
    } else if (n <= 5) {
      color = Colors.orange;
      icon = Icons.warning_amber_rounded;
    } else {
      color = Colors.green;
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isMobile ? 12 : 14),
          const SizedBox(width: 4),
          Text(
            _formatearNumero(n),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: isMobile ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipoBadge(String tipoRaw, bool isMobile) {
    final tipo = _limpiarTipoMovimiento(tipoRaw).toUpperCase();
    final color = _getColorTipoMovimiento(tipo);
    final icon = _getIconoTipoMovimiento(tipo);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: isMobile ? 12 : 14),
          const SizedBox(width: 4),
          Text(
            tipo,
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaResumen(
    String titulo,
    int cantidad,
    IconData icon,
    Color color,
    bool isMobile,
  ) {
    return Expanded(
      child: Card(
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
                child: Icon(icon, color: color, size: isMobile ? 24 : 32),
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
      ),
    );
  }

  Widget _buildRangoButton(String label, String tipo, bool isMobile) {
    final bool seleccionado = _rangoSeleccionado == tipo;
    const Color verde = Color(0xFF2E7D32);

    return Expanded(
      child: OutlinedButton(
        onPressed: () => _establecerRangoRapido(tipo),
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            vertical: 8,
            horizontal: isMobile ? 8 : 0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          backgroundColor: seleccionado ? verde : Colors.white,
          foregroundColor: seleccionado ? Colors.white : Colors.grey.shade700,
          side: BorderSide(
            color: seleccionado ? verde : Colors.grey.shade400,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (seleccionado) ...[
              const Icon(Icons.check, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD PRINCIPAL ──────────────────────────────────────────
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
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF1F8E9), Colors.white],
                ),
              ),
              child: RefreshIndicator(
                onRefresh: _cargarMovimientos,
                color: verde,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fila 1 de tarjetas
                      Row(
                        children: [
                          _buildTarjetaResumen(
                            'Total Ingresos',
                            _totalIngresos,
                            Icons.add_circle,
                            Colors.green,
                            isMobile,
                          ),
                          const SizedBox(width: 8),
                          _buildTarjetaResumen(
                            'Total Egresos',
                            _totalEgresos,
                            Icons.remove_circle,
                            Colors.orange,
                            isMobile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Fila 2 de tarjetas
                      Row(
                        children: [
                          _buildTarjetaResumen(
                            'Total Entregas',
                            _totalEntregas,
                            Icons.handshake,
                            Colors.blue,
                            isMobile,
                          ),
                          const SizedBox(width: 8),
                          _buildTarjetaResumen(
                            'Total General',
                            _totalIngresos + _totalEgresos + _totalEntregas,
                            Icons.inventory,
                            Colors.purple,
                            isMobile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // 🆕 Fila 3 de tarjetas (Auditoría)
                      Row(
                        children: [
                          _buildTarjetaResumen(
                            'Ajustes (Modif.)',
                            _totalAjustes,
                            Icons.edit_note,
                            Colors.amber.shade700,
                            isMobile,
                          ),
                          const SizedBox(width: 8),
                          _buildTarjetaResumen(
                            'Eliminados',
                            _totalEliminados,
                            Icons.delete_forever,
                            Colors.red.shade700,
                            isMobile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildFiltros(verde, isMobile),
                      const SizedBox(height: 20),
                      _buildMovimientos(verde, isMobile),
                    ],
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
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.account_balance,
                      size: 40,
                      color: Colors.grey,
                    ),
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
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.account_balance,
                  size: 60,
                  color: Colors.grey,
                ),
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

  Widget _buildFiltros(Color verde, bool isMobile) {
    final fechaInicioField = TextFormField(
      controller: _fechaInicioController,
      readOnly: true,
      onTap: () => _pickDate(_fechaInicioController),
      decoration: const InputDecoration(
        labelText: 'Fecha Inicio',
        hintText: 'YYYY-MM-DD',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        suffixIcon: Icon(Icons.calendar_today),
      ),
    );

    final fechaFinField = TextFormField(
      controller: _fechaFinController,
      readOnly: true,
      onTap: () => _pickDate(_fechaFinController),
      decoration: const InputDecoration(
        labelText: 'Fecha Fin',
        hintText: 'YYYY-MM-DD',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        suffixIcon: Icon(Icons.calendar_today),
      ),
    );

    // 🆕 Lista actualizada de tipos para el dropdown
    final List<String> tiposMovimiento = [
      'INGRESO',
      'EGRESO',
      'ENTREGA',
      'AJUSTE',
      'ELIMINO',
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 16),
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
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (texto) {
                _filtroLocal = texto;
                _aplicarFiltros();
              },
              decoration: InputDecoration(
                hintText: 'Buscar por item, contrato, bodega o usuario...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _filtroLocal.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _filtroLocal = '';
                          _aplicarFiltros();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (isMobile) ...[
              fechaInicioField,
              const SizedBox(height: 12),
              fechaFinField,
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _tipoMovimientoSeleccionado,
                hint: const Text('Tipo de Movimiento'),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                items: tiposMovimiento
                    .map(
                      (tipo) =>
                          DropdownMenuItem(value: tipo, child: Text(tipo)),
                    )
                    .toList(),
                onChanged: (value) {
                  _tipoMovimientoSeleccionado = value;
                  _aplicarFiltros();
                },
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(child: fechaInicioField),
                  const SizedBox(width: 12),
                  Expanded(child: fechaFinField),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _tipoMovimientoSeleccionado,
                      hint: const Text('Tipo de Movimiento'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                      items: tiposMovimiento
                          .map(
                            (tipo) => DropdownMenuItem(
                              value: tipo,
                              child: Text(tipo),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        _tipoMovimientoSeleccionado = value;
                        _aplicarFiltros();
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Rangos rápidos:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildRangoButton('Hoy', 'hoy', isMobile),
                const SizedBox(width: 8),
                _buildRangoButton('Este Mes', 'mes_actual', isMobile),
                const SizedBox(width: 8),
                _buildRangoButton('Mes Anterior', 'mes_anterior', isMobile),
                const SizedBox(width: 8),
                _buildRangoButton('Este Año', 'anio_actual', isMobile),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _fechaInicioController.clear();
                      _fechaFinController.clear();
                      _tipoMovimientoSeleccionado = null;
                      _rangoSeleccionado = null;
                      _bodegaSeleccionada = null;
                      _contratoSeleccionado = null;
                      _searchController.clear();
                      _filtroLocal = '';
                    });
                    _cargarMovimientos();
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
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
                  '${_movimientosFiltrados.length}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.grey.shade600,
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
            const SizedBox(height: 12),
            if (_cargando && _movimientosFiltrados.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_movimientosFiltrados.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    _movimientos.isEmpty
                        ? 'No hay movimientos registrados'
                        : 'Sin resultados para los filtros aplicados',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              isMobile
                  ? _buildMovimientosMobile(verde)
                  : _buildMovimientosDesktop(verde),
          ],
        ),
      ),
    );
  }

  // 📱 TARJETAS EN MÓVIL
  Widget _buildMovimientosMobile(Color verde) {
    return Column(
      children: _movimientosFiltrados.map((mov) {
        final tipo = _limpiarTipoMovimiento(
          mov['tipo_movimiento'],
        ).toUpperCase();
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildTipoBadge(mov['tipo_movimiento'], true),
                    const Spacer(),
                    Text(
                      _formatearFecha(mov['fecha_movimiento']),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  mov['nombre_items'] ?? 'Registro de Auditoría',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _buildCantidad(mov, true),
                    _buildStock(
                      mov['stock_actual'],
                      tipo,
                      true,
                    ), // 🆕 Pasamos el tipo
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Contrato: ${mov['numero_contrato'] ?? 'N/A'} · Bodega: ${mov['bodega_nombre'] ?? 'N/A'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Usuario: ${mov['usuario_nombre'] ?? 'N/A'} · Doc: ${mov['documento_numero'] ?? '-'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (mov['observacion'] != null &&
                    mov['observacion'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Obs: ${mov['observacion']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 🖥️ TABLA EN DESKTOP
  Widget _buildMovimientosDesktop(Color verde) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12,
        headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
        columns: const [
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
            label: Text(
              'Item / Registro',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
              'Acción / Cantidad',
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
          DataColumn(
            label: Text(
              'Observación',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        rows: _movimientosFiltrados.map((mov) {
          final tipo = _limpiarTipoMovimiento(
            mov['tipo_movimiento'],
          ).toUpperCase();
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
              DataCell(
                Text(
                  mov['nombre_items'] ?? 'Auditoría de Registro',
                  style: TextStyle(
                    fontWeight: tipo == 'AJUSTE' || tipo == 'ELIMINO'
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              DataCell(Text(mov['bodega_nombre'] ?? 'N/A')),
              DataCell(_buildTipoBadge(mov['tipo_movimiento'], false)),
              DataCell(_buildCantidad(mov, false)),
              DataCell(
                _buildStock(mov['stock_actual'], tipo, false),
              ), // 🆕 Pasamos el tipo
              DataCell(Text(mov['documento_numero'] ?? '-')),
              DataCell(Text(mov['usuario_nombre'] ?? 'N/A')),
              DataCell(
                Text(
                  mov['observacion'] ?? '-',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
