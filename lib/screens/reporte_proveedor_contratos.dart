import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/drawer_menu.dart';
import 'vista_previa_contrato.dart';

class ReporteProveedorContratosPage extends StatefulWidget {
  const ReporteProveedorContratosPage({super.key});

  @override
  State<ReporteProveedorContratosPage> createState() =>
      _ReporteProveedorContratosPageState();
}

class _ReporteProveedorContratosPageState
    extends State<ReporteProveedorContratosPage> {
  late String username;
  late String sector;
  late String rol;

  final TextEditingController _fechaInicioCtrl = TextEditingController();
  final TextEditingController _fechaFinCtrl = TextEditingController();

  String? _tipoContratoSeleccionado;
  String? _estadoSeleccionado;
  String? _rangoSeleccionado;

  final List<String> _tiposContratoDisponibles = [
    'Contrato de obra',
    'Contrato de prestación de servicios',
    'Contrato de consultoría',
    'Contrato de suministro',
    'Contrato de interventoría',
    'Contrato de compraventa',
    'Contrato de arrendamiento',
  ];

  final List<String> _estadosContrato = [
    'Todos los estados',
    'Activo',
    'En Proceso',
    'Finalizado',
    'Suspendido',
    'Terminado',
  ];

  bool _cargando = false;
  bool _reporteGenerado = false;
  String? _errorMensaje;

  List<Map<String, dynamic>> _proveedores = [];
  Map<String, dynamic>? _resumen;

  static const String _baseUrl = 'http://localhost/samde_db/api';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
    username = map['username'] ?? 'Usuario';
    sector = map['sector'] ?? 'No Asignado';
    rol = map['rol'] ?? 'consulta';

    // ✅ Cargar datos automáticamente al entrar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generarReporte();
    });
  }

  @override
  void dispose() {
    _fechaInicioCtrl.dispose();
    _fechaFinCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha(TextEditingController controller) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (fecha != null) {
      setState(() {
        controller.text = fecha.toIso8601String().substring(0, 10);
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
      _fechaInicioCtrl.text = inicio.toIso8601String().substring(0, 10);
      _fechaFinCtrl.text = fin.toIso8601String().substring(0, 10);
    });
  }

  Future<void> _generarReporte() async {
    // ✅ Las fechas son opcionales ahora
    setState(() {
      _cargando = true;
      _errorMensaje = null;
      _reporteGenerado = false;
    });

    try {
      String url = '$_baseUrl/reportes/reporte_proveedor_contratos.php?';

      // ✅ Solo agregar fechas si están seleccionadas
      if (_fechaInicioCtrl.text.isNotEmpty && _fechaFinCtrl.text.isNotEmpty) {
        url +=
            'fecha_inicio=${_fechaInicioCtrl.text}&fecha_fin=${_fechaFinCtrl.text}&';
      }

      if (_tipoContratoSeleccionado != null &&
          _tipoContratoSeleccionado != 'Todos los tipos') {
        url +=
            'tipo_contrato=${Uri.encodeComponent(_tipoContratoSeleccionado!)}&';
      }

      if (_estadoSeleccionado != null &&
          _estadoSeleccionado != 'Todos los estados') {
        url += 'estado=${Uri.encodeComponent(_estadoSeleccionado!)}&';
      }

      // Eliminar último '&' si existe
      if (url.endsWith('&')) {
        url = url.substring(0, url.length - 1);
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _proveedores = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _resumen = data['resumen'];
          _reporteGenerado = true;
        });
      } else {
        setState(() {
          _errorMensaje = data['message'] ?? 'Error al generar el reporte';
        });
      }
    } catch (e) {
      setState(() {
        _errorMensaje = 'Error de conexión: $e';
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _exportarExcel() async {
    String url = '$_baseUrl/reportes/exportar_proveedor_contratos_excel.php?';

    if (_fechaInicioCtrl.text.isNotEmpty && _fechaFinCtrl.text.isNotEmpty) {
      url +=
          'fecha_inicio=${_fechaInicioCtrl.text}&fecha_fin=${_fechaFinCtrl.text}&';
    }

    if (_tipoContratoSeleccionado != null &&
        _tipoContratoSeleccionado != 'Todos los tipos') {
      url +=
          'tipo_contrato=${Uri.encodeComponent(_tipoContratoSeleccionado!)}&';
    }

    if (_estadoSeleccionado != null &&
        _estadoSeleccionado != 'Todos los estados') {
      url += 'estado=${Uri.encodeComponent(_estadoSeleccionado!)}&';
    }

    if (url.endsWith('&')) {
      url = url.substring(0, url.length - 1);
    }

    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Descargando reporte en Excel...'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No se pudo iniciar la descarga'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _verDetalleContrato(Map<String, dynamic> contrato) async {
    final contratoId = contrato['id'];
    if (contratoId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VistaPreviaContratoPage(contratoId: contratoId),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  String _formatMoney(dynamic value) {
    if (value == null) return '\$0';
    try {
      final numValue = value is String
          ? double.tryParse(value) ?? 0
          : value.toDouble();
      return '\$${numValue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    } catch (e) {
      return '\$0';
    }
  }

  Color _getEstadoColor(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'activo':
      case 'en ejecución':
        return Colors.green;
      case 'en proceso':
        return Colors.orange;
      case 'finalizado':
      case 'terminado':
        return Colors.blue;
      case 'suspendido':
        return Colors.red;
      default:
        return Colors.grey;
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
        selectedIndex: 10,
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
                  colors: [Color(0xFFF1F8F1), Colors.white],
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFiltros(verde, isMobile),
                        const SizedBox(height: 24),
                        _buildContenido(verde, isMobile),
                      ],
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
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Contratos por Proveedor',
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
        height: 130,
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
                'Contratos por Proveedor',
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
      controller: _fechaInicioCtrl,
      readOnly: true,
      onTap: () => _seleccionarFecha(_fechaInicioCtrl),
      decoration: const InputDecoration(
        labelText: 'Fecha Inicio (Opcional)',
        hintText: 'Seleccione fecha inicial',
        suffixIcon: Icon(Icons.calendar_today),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );

    final fechaFinField = TextFormField(
      controller: _fechaFinCtrl,
      readOnly: true,
      onTap: () => _seleccionarFecha(_fechaFinCtrl),
      decoration: const InputDecoration(
        labelText: 'Fecha Fin (Opcional)',
        hintText: 'Seleccione fecha final',
        suffixIcon: Icon(Icons.calendar_today),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );

    final tipoContratoField = DropdownButtonFormField<String>(
      value: _tipoContratoSeleccionado ?? 'Todos los tipos',
      decoration: const InputDecoration(
        labelText: 'Tipo de Contrato (Opcional)',
        hintText: 'Todos los tipos',
        suffixIcon: Icon(Icons.category),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String>(
          value: 'Todos los tipos',
          child: Text('Todos los tipos', style: TextStyle(color: Colors.grey)),
        ),
        ..._tiposContratoDisponibles.map(
          (String tipo) =>
              DropdownMenuItem<String>(value: tipo, child: Text(tipo)),
        ),
      ],
      onChanged: (String? newValue) =>
          setState(() => _tipoContratoSeleccionado = newValue),
    );

    final estadoField = DropdownButtonFormField<String>(
      value: _estadoSeleccionado ?? 'Todos los estados',
      decoration: const InputDecoration(
        labelText: 'Estado del Contrato (Opcional)',
        hintText: 'Todos los estados',
        suffixIcon: Icon(Icons.track_changes),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      isExpanded: true,
      items: _estadosContrato
          .map(
            (String estado) =>
                DropdownMenuItem<String>(value: estado, child: Text(estado)),
          )
          .toList(),
      onChanged: (String? newValue) =>
          setState(() => _estadoSeleccionado = newValue),
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: verde, size: isMobile ? 22 : 28),
                const SizedBox(width: 12),
                Text(
                  'Filtros de Búsqueda',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
              ],
            ),
            Divider(height: isMobile ? 24 : 32),
            if (isMobile) ...[
              fechaInicioField,
              const SizedBox(height: 16),
              fechaFinField,
              const SizedBox(height: 16),
              tipoContratoField,
              const SizedBox(height: 16),
              estadoField,
            ] else ...[
              Row(
                children: [
                  Expanded(child: fechaInicioField),
                  const SizedBox(width: 16),
                  Expanded(child: fechaFinField),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: tipoContratoField),
                  const SizedBox(width: 16),
                  Expanded(child: estadoField),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Rangos rápidos:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (isMobile)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRangoButton('Hoy', 'hoy', isMobile),
                  _buildRangoButton('Este Mes', 'mes_actual', isMobile),
                  _buildRangoButton('Mes Anterior', 'mes_anterior', isMobile),
                  _buildRangoButton('Este Año', 'anio_actual', isMobile),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: _buildRangoButton('Hoy', 'hoy', isMobile)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRangoButton(
                      'Este Mes',
                      'mes_actual',
                      isMobile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRangoButton(
                      'Mes Anterior',
                      'mes_anterior',
                      isMobile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRangoButton(
                      'Este Año',
                      'anio_actual',
                      isMobile,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            if (isMobile) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cargando ? null : _generarReporte,
                  icon: _cargando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.filter_alt, size: 20),
                  label: const Text(
                    'FILTRAR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cargando ? null : _exportarExcel,
                  icon: const Icon(Icons.file_download, size: 20),
                  label: const Text(
                    'EXPORTAR EXCEL',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _fechaInicioCtrl.clear();
                      _fechaFinCtrl.clear();
                      _tipoContratoSeleccionado = null;
                      _estadoSeleccionado = null;
                      _rangoSeleccionado = null;
                      _reporteGenerado = false;
                      _proveedores.clear();
                      _resumen = null;
                      _errorMensaje = null;
                    });
                    _generarReporte();
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _cargando ? null : _generarReporte,
                      icon: _cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.filter_alt, size: 20),
                      label: const Text(
                        'FILTRAR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _cargando ? null : _exportarExcel,
                      icon: const Icon(Icons.file_download, size: 20),
                      label: const Text(
                        'EXPORTAR EXCEL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _fechaInicioCtrl.clear();
                          _fechaFinCtrl.clear();
                          _tipoContratoSeleccionado = null;
                          _estadoSeleccionado = null;
                          _rangoSeleccionado = null;
                          _reporteGenerado = false;
                          _proveedores.clear();
                          _resumen = null;
                          _errorMensaje = null;
                        });
                        _generarReporte();
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpiar'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangoButton(String label, String tipo, bool isMobile) {
    final bool seleccionado = _rangoSeleccionado == tipo;
    const Color verde = Color(0xFF2E7D32);
    return OutlinedButton(
      onPressed: () => _establecerRangoRapido(tipo),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 8 : 8,
          horizontal: isMobile ? 12 : 0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        backgroundColor: seleccionado ? verde : Colors.white,
        foregroundColor: seleccionado ? Colors.white : Colors.grey.shade700,
        side: BorderSide(
          color: seleccionado ? verde : Colors.grey.shade400,
          width: seleccionado ? 2 : 1,
        ),
        elevation: seleccionado ? 2 : 0,
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
    );
  }

  Widget _buildContenido(Color verde, bool isMobile) {
    if (_cargando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    if (_errorMensaje != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMensaje!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_reporteGenerado) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.business, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Cargando contratos...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_resumen != null) ...[
          if (isMobile) ...[
            _buildResumenCard(
              'Total Proveedores',
              '${_resumen!['total_proveedores']}',
              Icons.business,
              Colors.blue,
              isMobile,
            ),
            const SizedBox(height: 12),
            _buildResumenCard(
              'Total Contratos',
              '${_resumen!['total_contratos']}',
              Icons.assignment,
              Colors.orange,
              isMobile,
            ),
            const SizedBox(height: 12),
            _buildResumenCard(
              'Valor Total',
              _formatMoney(_resumen!['valor_total']),
              Icons.attach_money,
              Colors.green,
              isMobile,
            ),
          ] else
            Row(
              children: [
                _buildResumenCard(
                  'Total Proveedores',
                  '${_resumen!['total_proveedores']}',
                  Icons.business,
                  Colors.blue,
                  isMobile,
                ),
                const SizedBox(width: 16),
                _buildResumenCard(
                  'Total Contratos',
                  '${_resumen!['total_contratos']}',
                  Icons.assignment,
                  Colors.orange,
                  isMobile,
                ),
                const SizedBox(width: 16),
                _buildResumenCard(
                  'Valor Total',
                  _formatMoney(_resumen!['valor_total']),
                  Icons.attach_money,
                  Colors.green,
                  isMobile,
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
        if (_proveedores.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No se encontraron contratos con estos filtros',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _buildListaProveedores(verde, isMobile),
      ],
    );
  }

  Widget _buildListaProveedores(Color verde, bool isMobile) {
    return Column(
      children: _proveedores.map((proveedor) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.grey.shade50,
            leading: CircleAvatar(
              backgroundColor: verde.withValues(alpha: 0.1),
              child: Icon(Icons.business, color: verde, size: 24),
            ),
            title: Text(
              proveedor['proveedor'] ?? 'N/A',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: verde,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
            subtitle: Text(
              '${proveedor['total_contratos']} contratos · ${_formatMoney(proveedor['valor_total_proveedor'])}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  children: (proveedor['contratos'] as List).map((contrato) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: InkWell(
                        onTap: () => _verDetalleContrato(contrato),
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Contrato #${contrato['numero_contrato']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getEstadoColor(
                                      contrato['estado'],
                                    ).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    contrato['estado'] ?? 'N/A',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _getEstadoColor(
                                        contrato['estado'],
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tipo: ${contrato['tipo_contrato'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Valor: ${_formatMoney(contrato['valor_total'])}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Vigencia: ${_formatDate(contrato['fecha_inicio'])} - ${_formatDate(contrato['fecha_fin'])}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Actas: ${contrato['total_actas']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResumenCard(
    String titulo,
    String valor,
    IconData icono,
    Color color,
    bool isMobile,
  ) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: color, size: isMobile ? 24 : 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valor,
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
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
}
