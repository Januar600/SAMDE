import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/drawer_menu.dart';

class ReporteUsuarioPage extends StatefulWidget {
  const ReporteUsuarioPage({super.key});

  @override
  State<ReporteUsuarioPage> createState() => _ReporteUsuarioPageState();
}

class _ReporteUsuarioPageState extends State<ReporteUsuarioPage> {
  late String username;
  late String sector;
  late String rol;

  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _documentoCtrl = TextEditingController();
  final TextEditingController _fechaInicioCtrl = TextEditingController();
  final TextEditingController _fechaFinCtrl = TextEditingController();

  String? _rangoSeleccionado;

  bool _cargando = false;
  bool _reporteGenerado = false;
  String? _errorMensaje;

  List<Map<String, dynamic>> _resultados = [];
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
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _documentoCtrl.dispose();
    _fechaInicioCtrl.dispose();
    _fechaFinCtrl.dispose();
    super.dispose();
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

  Future<void> _buscar() async {
    FocusScope.of(context).unfocus(); // Cierra el teclado en móvil

    if (_nombreCtrl.text.isEmpty && _documentoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Debe ingresar al menos un nombre o documento'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _cargando = true;
      _errorMensaje = null;
      _reporteGenerado = false;
    });

    try {
      String url = '$_baseUrl/reportes/reporte_usuario.php?';

      if (_nombreCtrl.text.isNotEmpty) {
        url += 'busqueda=${Uri.encodeComponent(_nombreCtrl.text)}&';
      }

      if (_documentoCtrl.text.isNotEmpty) {
        url += 'documento=${Uri.encodeComponent(_documentoCtrl.text)}&';
      }

      if (_fechaInicioCtrl.text.isNotEmpty && _fechaFinCtrl.text.isNotEmpty) {
        url +=
            'fecha_inicio=${_fechaInicioCtrl.text}&fecha_fin=${_fechaFinCtrl.text}&';
      }

      if (url.endsWith('&')) {
        url = url.substring(0, url.length - 1);
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _resultados = List<Map<String, dynamic>>.from(data['data'] ?? []);
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
    if (_nombreCtrl.text.isEmpty && _documentoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Debe ingresar al menos un nombre o documento antes de exportar',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String url = '$_baseUrl/reportes/exportar_usuario_excel.php?';

    if (_nombreCtrl.text.isNotEmpty) {
      url += 'busqueda=${Uri.encodeComponent(_nombreCtrl.text)}&';
    }

    if (_documentoCtrl.text.isNotEmpty) {
      url += 'documento=${Uri.encodeComponent(_documentoCtrl.text)}&';
    }

    if (_fechaInicioCtrl.text.isNotEmpty && _fechaFinCtrl.text.isNotEmpty) {
      url +=
          'fecha_inicio=${_fechaInicioCtrl.text}&fecha_fin=${_fechaFinCtrl.text}&';
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

  Future<void> _verDetalleActa(Map<String, dynamic> actaResumen) async {
    final actaId = actaResumen['id'];
    if (actaId == null) return;

    List<Map<String, dynamic>> itemsEntregados = [];
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/actas/obtener_acta.php?id=$actaId'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        itemsEntregados = List<Map<String, dynamic>>.from(
          data['data']['detalles'] ?? [],
        );
      }
    } catch (e) {
      debugPrint('Error cargando items: $e');
    }

    if (mounted) _mostrarDialogoDetalle(actaResumen, itemsEntregados);
  }

  void _mostrarDialogoDetalle(
    Map<String, dynamic> acta,
    List<Map<String, dynamic>> items,
  ) {
    const Color verde = Color(0xFF2E7D32);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(
                      bottom: BorderSide(color: Colors.green.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description,
                        color: Colors.green.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Detalle Acta #${acta['numero_acta']}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow('Entregado a:', acta['entregado_a'] ?? 'N/A'),
                        if (acta['documento_identidad'] != null &&
                            acta['documento_identidad'].isNotEmpty)
                          _infoRow('Documento:', acta['documento_identidad']),
                        _infoRow('Fecha:', _formatDate(acta['fecha_entrega'])),
                        _infoRow('Área:', acta['area_dependencia'] ?? 'N/A'),
                        _infoRow(
                          'Entregado por:',
                          acta['nombre_entrego'] ?? 'N/A',
                        ),
                        const Divider(height: 32),
                        Text(
                          'Items Entregados',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: verde,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                color: Colors.green.shade100,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        'Item',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: verde,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Contrato',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: verde,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Cant.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: verde,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (items.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: Text('Sin items registrados'),
                                  ),
                                )
                              else
                                ...items.map(
                                  (item) => Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.green.shade100,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            item['nombre_item'] ?? 'N/A',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            item['numero_contrato'] ?? 'N/A',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${item['cantidad_entregada']}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: verde,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
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

  // ✅ NUEVO WIDGET: Mensaje para rotar el dispositivo
  Widget _buildRotacionMensaje(Color verde) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.screen_rotation, size: 56, color: Colors.amber.shade700),
          const SizedBox(height: 16),
          Text(
            '📱 Para una mejor visualización',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.amber.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Por favor, gira tu dispositivo de manera horizontal para ver el reporte completo de manera cómoda.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.amber.shade900,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: verde,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: verde.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.rotate_90_degrees_cw,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Gira el dispositivo',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF2E7D32);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    // ✅ DETECTAR SI ESTÁ EN MÓVIL Y EN POSICIÓN VERTICAL (PORTRAIT)
    final isPortrait = isMobile && (screenHeight > screenWidth);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 9,
      ),
      body: SafeArea(
        child: Column(
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
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.all(isMobile ? 12 : 24),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFiltros(verde, isMobile),
                            const SizedBox(height: 16),
                            // ✅ LÓGICA CLAVE: Si hay resultados Y está en vertical, muestra el aviso
                            if (_reporteGenerado && isPortrait)
                              _buildRotacionMensaje(verde)
                            else
                              _buildContenido(verde, isMobile),
                          ],
                        )
                      : Center(
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
              'Búsqueda por Usuario',
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
                'Búsqueda por Usuario',
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
    final documentoField = TextFormField(
      controller: _documentoCtrl,
      decoration: InputDecoration(
        labelText: 'Documento (NIT o CC)',
        hintText: 'Número de documento',
        prefixIcon: const Icon(Icons.credit_card),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    final nombreField = _buildCampoNombreAutocomplete(verde);

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
                Icon(Icons.search, color: verde, size: isMobile ? 22 : 28),
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
              nombreField,
              const SizedBox(height: 16),
              documentoField,
            ] else ...[
              Row(
                children: [
                  Expanded(child: nombreField),
                  const SizedBox(width: 16),
                  Expanded(child: documentoField),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Acotar por fecha (Opcional):',
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
                  onPressed: _cargando ? null : _buscar,
                  icon: _cargando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.search, size: 20),
                  label: const Text(
                    'BUSCAR HISTORIAL',
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
                      _nombreCtrl.clear();
                      _documentoCtrl.clear();
                      _fechaInicioCtrl.clear();
                      _fechaFinCtrl.clear();
                      _rangoSeleccionado = null;
                      _reporteGenerado = false;
                      _resultados.clear();
                      _resumen = null;
                      _errorMensaje = null;
                    });
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
                      onPressed: _cargando ? null : _buscar,
                      icon: _cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.search, size: 20),
                      label: const Text(
                        'BUSCAR HISTORIAL',
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
                          _nombreCtrl.clear();
                          _documentoCtrl.clear();
                          _fechaInicioCtrl.clear();
                          _fechaFinCtrl.clear();
                          _rangoSeleccionado = null;
                          _reporteGenerado = false;
                          _resultados.clear();
                          _resumen = null;
                          _errorMensaje = null;
                        });
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

  Widget _buildCampoNombreAutocomplete(Color verde) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        final query = textEditingValue.text.trim();
        if (query.length < 2) return const Iterable<String>.empty();

        try {
          final response = await http
              .get(
                Uri.parse(
                  '$_baseUrl/reportes/obtener_nombres_entrega.php?q=${Uri.encodeComponent(query)}',
                ),
              )
              .timeout(const Duration(seconds: 5));

          final data = jsonDecode(response.body);

          if (data['success'] == true) {
            final List<dynamic> nombres = data['data'] ?? [];
            return nombres
                .map((item) {
                  return '${item['nombre'] ?? ''}|||${item['documento'] ?? ''}';
                })
                .take(5);
          }
        } catch (e) {
          debugPrint('Error en autocompletado: $e');
        }

        return const Iterable<String>.empty();
      },
      displayStringForOption: (String option) => option.split('|||')[0],
      onSelected: (String selection) {
        final parts = selection.split('|||');
        final nombre = parts[0];
        final documento = parts.length > 1 ? parts[1] : '';

        _nombreCtrl.text = nombre;
        _documentoCtrl.text = documento.isNotEmpty ? documento : '';
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Nombre o Razón Social',
            hintText: 'Buscar por nombre de quien recibió',
            prefixIcon: const Icon(Icons.person),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      _nombreCtrl.clear();
                      _documentoCtrl.clear();
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) {
            _nombreCtrl.text = value;
          },
          onFieldSubmitted: (value) {
            _nombreCtrl.text = value;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final option = options.elementAt(index);
                  final parts = option.split('|||');
                  final nombre = parts[0];
                  final documento = parts.length > 1 ? parts[1] : '';

                  return InkWell(
                    onTap: () => onSelected(option),
                    child: SizedBox(
                      height: 56,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: verde.withValues(alpha: 0.1),
                              child: Icon(Icons.person, color: verde, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    nombre,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (documento.isNotEmpty)
                                    Text(
                                      'Doc: $documento',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
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
              Icon(Icons.search, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Ingrese un nombre o documento y presione "Buscar Historial"',
                textAlign: TextAlign.center,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: _rangoSeleccionado != null
                ? Colors.blue.shade50
                : Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _rangoSeleccionado != null
                  ? Colors.blue.shade200
                  : Colors.green.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _rangoSeleccionado != null
                    ? Icons.date_range
                    : Icons.calendar_today,
                color: _rangoSeleccionado != null
                    ? Colors.blue.shade700
                    : Colors.green.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _rangoSeleccionado != null
                      ? 'Filtrando por: ${_rangoSeleccionado!.replaceAll('_', ' ').toUpperCase()} (${_fechaInicioCtrl.text} a ${_fechaFinCtrl.text})'
                      : 'Mostrando historial completo (todas las fechas)',
                  style: TextStyle(
                    color: _rangoSeleccionado != null
                        ? Colors.blue.shade700
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_resumen != null) ...[
          if (isMobile) ...[
            _buildResumenCard(
              'Total Actas',
              '${_resumen!['total_actas']}',
              Icons.description,
              Colors.blue,
              isMobile,
            ),
            const SizedBox(height: 12),
            _buildResumenCard(
              'Total Items',
              '${_resumen!['total_items']}',
              Icons.inventory_2,
              Colors.orange,
              isMobile,
            ),
            const SizedBox(height: 12),
            _buildResumenCard(
              'Cant. Entregada',
              '${_resumen!['total_cantidad']}',
              Icons.shopping_cart,
              Colors.green,
              isMobile,
            ),
            const SizedBox(height: 12),
            _buildResumenCard(
              'Contratos',
              '${_resumen!['total_contratos']}',
              Icons.folder,
              Colors.purple,
              isMobile,
            ),
          ] else
            Row(
              children: [
                _buildResumenCard(
                  'Total Actas',
                  '${_resumen!['total_actas']}',
                  Icons.description,
                  Colors.blue,
                  isMobile,
                ),
                const SizedBox(width: 16),
                _buildResumenCard(
                  'Total Items',
                  '${_resumen!['total_items']}',
                  Icons.inventory_2,
                  Colors.orange,
                  isMobile,
                ),
                const SizedBox(width: 16),
                _buildResumenCard(
                  'Cant. Entregada',
                  '${_resumen!['total_cantidad']}',
                  Icons.shopping_cart,
                  Colors.green,
                  isMobile,
                ),
                const SizedBox(width: 16),
                _buildResumenCard(
                  'Contratos',
                  '${_resumen!['total_contratos']}',
                  Icons.folder,
                  Colors.purple,
                  isMobile,
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
        if (_resultados.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No se encontraron entregas para este usuario',
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
          isMobile
              ? _buildResultadosMobile(verde)
              : _buildResultadosDesktop(verde),
      ],
    );
  }

  Widget _buildResultadosMobile(Color verde) {
    return Column(
      children: _resultados.map((acta) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _verDetalleActa(acta),
            borderRadius: BorderRadius.circular(8),
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
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Acta #${acta['numero_acta'] ?? 'N/A'}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: verde,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(acta['fecha_entrega']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildBadge(
                        'Documento',
                        acta['documento_identidad'] ?? 'N/A',
                        Colors.teal,
                      ),
                      _buildBadge(
                        'Entregado por',
                        acta['nombre_entrego'] ?? 'N/A',
                        Colors.purple,
                      ),
                      _buildBadge(
                        'Área',
                        acta['area_dependencia'] ?? 'N/A',
                        Colors.orange,
                      ),
                      _buildBadge(
                        'Items',
                        '${acta['total_items']}',
                        Colors.green,
                      ),
                      _buildBadge(
                        'Cantidad',
                        '${acta['total_cantidad']}',
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

  Widget _buildResultadosDesktop(Color verde) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: verde.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Acta',
                    style: TextStyle(fontWeight: FontWeight.bold, color: verde),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Fecha',
                    style: TextStyle(fontWeight: FontWeight.bold, color: verde),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Documento',
                    style: TextStyle(fontWeight: FontWeight.bold, color: verde),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Entregado a',
                    style: TextStyle(fontWeight: FontWeight.bold, color: verde),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Entregado por',
                    style: TextStyle(fontWeight: FontWeight.bold, color: verde),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Área',
                    style: TextStyle(fontWeight: FontWeight.bold, color: verde),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Items',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: verde),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Cant.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: verde),
                  ),
                ),
              ],
            ),
          ),
          ..._resultados.map((acta) {
            return InkWell(
              onTap: () => _verDetalleActa(acta),
              borderRadius: BorderRadius.circular(8),
              hoverColor: Colors.green.withValues(alpha: 0.05),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          acta['numero_acta'] ?? 'N/A',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: verde,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatDate(acta['fecha_entrega']),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        acta['documento_identidad'] ?? 'N/A',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        acta['entregado_a'] ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        acta['nombre_entrego'] ?? 'N/A',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Text(
                        acta['area_dependencia'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${acta['total_items']}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${acta['total_cantidad']}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
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
                        fontSize: isMobile ? 20 : 24,
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
