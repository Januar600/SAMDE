import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/drawer_menu.dart';

class ReporteAnualConsolidadoPage extends StatefulWidget {
  const ReporteAnualConsolidadoPage({super.key});

  @override
  State<ReporteAnualConsolidadoPage> createState() =>
      _ReporteAnualConsolidadoPageState();
}

class _ReporteAnualConsolidadoPageState
    extends State<ReporteAnualConsolidadoPage> {
  late String username;
  late String sector;
  late String rol;

  int _anioSeleccionado = DateTime.now().year;
  List<int> _aniosDisponibles = []; // ✅ Lista dinámica de años
  bool _cargando = false;
  bool _reporteGenerado = false;
  String? _errorMensaje;

  Map<String, dynamic>? _data;

  static const String _baseUrl = 'http://localhost/samde_db/api';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
    username = map['username'] ?? 'Usuario';
    sector = map['sector'] ?? 'No Asignado';
    rol = map['rol'] ?? 'consulta';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generarReporte();
    });
  }

  Future<void> _generarReporte() async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
      _reporteGenerado = false;
    });

    try {
      final url =
          '$_baseUrl/reportes/reporte_anual_consolidado.php?anio=$_anioSeleccionado';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _data = data;
          _reporteGenerado = true;

          // ✅ Cargar años disponibles desde el backend
          if (data['anios_disponibles'] != null) {
            _aniosDisponibles = List<int>.from(data['anios_disponibles']);
          }
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
    final url =
        '$_baseUrl/reportes/exportar_anual_consolidado_excel.php?anio=$_anioSeleccionado';
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Descargando reporte anual...'),
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
        selectedIndex: 12,
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
                        _buildSelectorAnio(verde, isMobile),
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
              'Reporte Anual Consolidado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
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
                'Reporte Anual Consolidado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
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

  Widget _buildSelectorAnio(Color verde, bool isMobile) {
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
                Icon(
                  Icons.calendar_month,
                  color: verde,
                  size: isMobile ? 22 : 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Seleccione el Año',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
              ],
            ),
            Divider(height: isMobile ? 24 : 32),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _anioSeleccionado,
                    decoration: const InputDecoration(
                      labelText: 'Año de Reporte',
                      suffixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(8)),
                      ),
                    ),
                    // ✅ Lista dinámica de años desde el backend
                    items: _aniosDisponibles.isEmpty
                        ? [
                            DropdownMenuItem<int>(
                              value: _anioSeleccionado,
                              child: Text(
                                '$_anioSeleccionado',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ]
                        : _aniosDisponibles
                              .map(
                                (year) => DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    '$year',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              )
                              .toList(),
                    onChanged: (int? newValue) {
                      if (newValue != null && newValue != _anioSeleccionado) {
                        setState(() => _anioSeleccionado = newValue);
                        _generarReporte();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
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
                        : const Icon(Icons.refresh, size: 20),
                    label: const Text(
                      'ACTUALIZAR',
                      style: TextStyle(
                        fontSize: 14,
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
                  child: ElevatedButton.icon(
                    onPressed: _cargando ? null : _exportarExcel,
                    icon: const Icon(Icons.file_download, size: 20),
                    label: const Text(
                      'EXPORTAR EXCEL',
                      style: TextStyle(
                        fontSize: 14,
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
              ],
            ),
          ],
        ),
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

    if (!_reporteGenerado || _data == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.assessment, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Seleccione un año para generar el reporte',
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

    final resumen = _data!['resumen_ejecutivo'] as Map<String, dynamic>;
    final desgloseTipo = List<Map<String, dynamic>>.from(
      _data!['desglose_tipo'] ?? [],
    );
    final topProveedores = List<Map<String, dynamic>>.from(
      _data!['top_proveedores'] ?? [],
    );
    final distribucionArea = List<Map<String, dynamic>>.from(
      _data!['distribucion_area'] ?? [],
    );
    final estadoContratos = List<Map<String, dynamic>>.from(
      _data!['estado_contratos'] ?? [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A. RESUMEN EJECUTIVO
        _buildSeccionHeader(
          verde,
          'A',
          'Resumen Ejecutivo',
          Icons.assessment,
          isMobile,
        ),
        const SizedBox(height: 12),
        if (isMobile) ...[
          _buildKpiCard(
            'Total Contratos',
            '${resumen['total_contratos']}',
            Icons.description,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildKpiCard(
            'Valor Total',
            _formatMoney(resumen['valor_total_contratado']),
            Icons.attach_money,
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildKpiCard(
            'Total Actas',
            '${resumen['total_actas']}',
            Icons.receipt_long,
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildKpiCard(
            'Total Items',
            '${resumen['total_items']}',
            Icons.inventory_2,
            Colors.purple,
          ),
          const SizedBox(height: 12),
          _buildKpiCard(
            'Cant. Entregada',
            '${resumen['total_cantidad']}',
            Icons.shopping_cart,
            Colors.teal,
          ),
        ] else
          Row(
            children: [
              _buildKpiCard(
                'Total Contratos',
                '${resumen['total_contratos']}',
                Icons.description,
                Colors.blue,
              ),
              const SizedBox(width: 12),
              _buildKpiCard(
                'Valor Total',
                _formatMoney(resumen['valor_total_contratado']),
                Icons.attach_money,
                Colors.green,
              ),
              const SizedBox(width: 12),
              _buildKpiCard(
                'Total Actas',
                '${resumen['total_actas']}',
                Icons.receipt_long,
                Colors.orange,
              ),
              const SizedBox(width: 12),
              _buildKpiCard(
                'Total Items',
                '${resumen['total_items']}',
                Icons.inventory_2,
                Colors.purple,
              ),
              const SizedBox(width: 12),
              _buildKpiCard(
                'Cant. Entregada',
                '${resumen['total_cantidad']}',
                Icons.shopping_cart,
                Colors.teal,
              ),
            ],
          ),
        const SizedBox(height: 32),

        // B. DESGLOSE POR TIPO
        _buildSeccionHeader(
          verde,
          'B',
          'Desglose por Tipo de Contrato',
          Icons.category,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildTablaSimple(
          headers: ['Tipo de Contrato', 'Cantidad', 'Valor Total'],
          rows: desgloseTipo
              .map(
                (r) => [
                  r['tipo_contrato'] ?? 'N/A',
                  '${r['cantidad']}',
                  _formatMoney(r['valor_total']),
                ],
              )
              .toList(),
          isMobile: isMobile,
        ),
        const SizedBox(height: 32),

        // C. TOP PROVEEDORES
        _buildSeccionHeader(
          verde,
          'C',
          'Top 10 Proveedores',
          Icons.leaderboard,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildTablaSimple(
          headers: ['Proveedor', 'Contratos', 'Valor Total', 'Actas'],
          rows: topProveedores
              .map(
                (r) => [
                  r['proveedor'] ?? 'N/A',
                  '${r['total_contratos']}',
                  _formatMoney(r['valor_total']),
                  '${r['total_actas']}',
                ],
              )
              .toList(),
          isMobile: isMobile,
        ),
        const SizedBox(height: 32),

        // D. DISTRIBUCIÓN POR ÁREA
        _buildSeccionHeader(
          verde,
          'D',
          'Distribución por Área / Dependencia',
          Icons.business,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildTablaSimple(
          headers: ['Área', 'Total Actas', 'Total Cantidad'],
          rows: distribucionArea
              .map(
                (r) => [
                  r['area_dependencia'] ?? 'N/A',
                  '${r['total_actas']}',
                  '${r['total_cantidad']}',
                ],
              )
              .toList(),
          isMobile: isMobile,
        ),
        const SizedBox(height: 32),

        // E. ESTADO DE CONTRATOS
        _buildSeccionHeader(
          verde,
          'E',
          'Estado Final de Contratos',
          Icons.track_changes,
          isMobile,
        ),
        const SizedBox(height: 12),
        _buildTablaSimple(
          headers: ['Estado', 'Cantidad', 'Valor Total'],
          rows: estadoContratos
              .map(
                (r) => [
                  r['estado'] ?? 'N/A',
                  '${r['cantidad']}',
                  _formatMoney(r['valor_total']),
                ],
              )
              .toList(),
          isMobile: isMobile,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSeccionHeader(
    Color verde,
    String letra,
    String titulo,
    IconData icono,
    bool isMobile,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isMobile ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: verde.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: verde, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: verde,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              letra,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Icon(icono, color: verde, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: isMobile ? 15 : 18,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String titulo,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                valor,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTablaSimple({
    required List<String> headers,
    required List<List<dynamic>> rows,
    required bool isMobile,
  }) {
    if (rows.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sin datos disponibles',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: headers
                  .map(
                    (h) => Expanded(
                      child: Text(
                        h,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: row
                    .map(
                      (cell) => Expanded(
                        child: Text(
                          cell.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(), // ✅ cell.toString()
              ),
            );
          }),
        ],
      ),
    );
  }
}
