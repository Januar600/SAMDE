import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ConsultarActasPage extends StatefulWidget {
  const ConsultarActasPage({super.key});

  @override
  State<ConsultarActasPage> createState() => _ConsultarActasPageState();
}

class _ConsultarActasPageState extends State<ConsultarActasPage> {
  late String username;
  late String sector;
  late String rol;

  List<Map<String, dynamic>> _actas = [];
  List<Map<String, dynamic>> _actasFiltradas = [];
  bool _cargando = false;
  final _busquedaController = TextEditingController();
  String _filtroBusqueda = '';

  static const String _baseUrl = 'http://192.168.10.64/samde_db/api';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route.settings.arguments != null) {
      final args = route.settings.arguments;
      final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
      username = map['username'] ?? 'Usuario';
      sector = map['sector'] ?? 'No Asignado';
      rol = map['rol'] ?? 'consulta';
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarActas();
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      if (date is String) {
        final parts = date.split('-');
        if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
      return date.toString();
    } catch (e) {
      return date.toString();
    }
  }

  String _formatNum(dynamic v) {
    if (v == null) return '0';
    if (v is int) return v.toString();
    if (v is double) {
      return v == v.truncateToDouble()
          ? v.truncate().toString()
          : v.toStringAsFixed(2);
    }
    return v.toString();
  }

  Future<void> _cargarActas() async {
    setState(() => _cargando = true);
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/actas/listar_actas.php'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        setState(() {
          _actas = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _actasFiltradas = _actas;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrarActas(String texto) {
    setState(() {
      _filtroBusqueda = texto.toLowerCase().trim();
      _actasFiltradas = _filtroBusqueda.isEmpty
          ? _actas
          : _actas.where((acta) {
              final numero = (acta['numero_acta'] ?? '').toLowerCase();
              final entregado = (acta['entregado_a'] ?? '').toLowerCase();
              return numero.contains(_filtroBusqueda) ||
                  entregado.contains(_filtroBusqueda);
            }).toList();
    });
  }

  Future<void> _abrirArchivo(String nombreArchivo, String accion) async {
    if (nombreArchivo.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay archivo disponible'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final urlCompleta =
        '$_baseUrl/actas/download_acta.php?file=${Uri.encodeComponent(nombreArchivo)}&action=$accion';
    final uri = Uri.parse(urlCompleta);
    debugPrint('🔗 $accion: $urlCompleta');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo $accion el archivo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ========================================================
  // VISTA PREVIA (estilo copiado de Actas)
  // ========================================================
  Future<void> _verDetalleActa(Map<String, dynamic> acta) async {
    final actaId = acta['id'];
    if (actaId == null) return;

    // Spinner con cierre garantizado en finally
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

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
    } finally {
      if (mounted) Navigator.pop(context);
    }

    if (!mounted) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isMobile = screenWidth < 600;
    final dialogWidth = isMobile ? screenWidth - 32 : 900.0;
    final dialogMaxHeight = screenHeight * 0.85;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: dialogMaxHeight,
          ),
          child: SizedBox(
            width: dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── HEADER ──
                Container(
                  padding: EdgeInsets.all(isMobile ? 14 : 20),
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
                        size: isMobile ? 22 : 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Acta #${acta['numero_acta']}',
                              style: TextStyle(
                                fontSize: isMobile ? 16 : 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                acta['estado']?.toString().toUpperCase() ??
                                    'ACTIVA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── CONTENIDO SCROLLABLE ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildInfoSection('Información General', [
                          _buildInfoRow(
                            'Entregado a:',
                            acta['entregado_a'] ?? 'N/A',
                          ),
                          _buildInfoRow(
                            'Fecha de entrega:',
                            _formatDate(acta['fecha_entrega']),
                          ),
                          _buildInfoRow(
                            'Contrato:',
                            acta['numero_contrato'] ?? 'N/A',
                          ),
                          if (acta['tipo_beneficiario'] != null &&
                              acta['tipo_beneficiario'].toString().isNotEmpty)
                            _buildInfoRow(
                              'Tipo de Beneficiario:',
                              acta['tipo_beneficiario'],
                            ),
                          if (acta['documento_identidad'] != null &&
                              acta['documento_identidad'].toString().isNotEmpty)
                            _buildInfoRow(
                              'Doc. de Identidad / NIT:',
                              acta['documento_identidad'],
                            ),
                          if (acta['telefono'] != null &&
                              acta['telefono'].toString().isNotEmpty)
                            _buildInfoRow('Teléfono:', acta['telefono']),
                          if (acta['zona'] != null &&
                              acta['zona'].toString().isNotEmpty)
                            _buildInfoRow('Zona:', acta['zona']),
                          if (acta['ubicacion'] != null &&
                              acta['ubicacion'].toString().isNotEmpty)
                            _buildInfoRow('Ubicación:', acta['ubicacion']),
                        ]),
                        const SizedBox(height: 20),
                        if (acta['tipo_beneficiario'] ==
                                'Asociación / Organización' ||
                            acta['tipo_beneficiario'] == 'Unidades Productivas')
                          _buildInfoSection('Representante Legal', [
                            if (acta['representante_legal'] != null &&
                                acta['representante_legal']
                                    .toString()
                                    .isNotEmpty)
                              _buildInfoRow(
                                'Nombre:',
                                acta['representante_legal'],
                              ),
                            if (acta['documento_identidad_rl'] != null &&
                                acta['documento_identidad_rl']
                                    .toString()
                                    .isNotEmpty)
                              _buildInfoRow(
                                'Documento:',
                                acta['documento_identidad_rl'],
                              ),
                          ]),
                        const SizedBox(height: 20),
                        if (acta['nombre_entrego'] != null &&
                            acta['nombre_entrego'].toString().isNotEmpty)
                          _buildInfoSection('Quien Entregó', [
                            _buildInfoRow('Nombre:', acta['nombre_entrego']),
                            _buildInfoRow(
                              'Cargo:',
                              acta['cargo_entrego'] ?? 'N/A',
                            ),
                            if (acta['area_dependencia'] != null &&
                                acta['area_dependencia'].toString().isNotEmpty)
                              _buildInfoRow(
                                'Área / Dependencia:',
                                acta['area_dependencia'],
                              ),
                          ]),
                        const SizedBox(height: 20),
                        if (acta['observaciones'] != null &&
                            acta['observaciones'].toString().isNotEmpty)
                          _buildInfoSection('Observaciones', [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  acta['observaciones'],
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ]),
                        const SizedBox(height: 20),
                        if (acta['archivo_justificante'] != null)
                          _buildInfoSection('Archivo Adjunto', [
                            Row(
                              children: [
                                Icon(
                                  Icons.insert_drive_file,
                                  color: Colors.red.shade400,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    acta['archivo_justificante'],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue.shade700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (isMobile)
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _abrirArchivo(
                                        acta['archivo_justificante']
                                                ?.toString() ??
                                            '',
                                        'view',
                                      ),
                                      icon: const Icon(
                                        Icons.visibility,
                                        size: 18,
                                      ),
                                      label: const Text('Ver'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _abrirArchivo(
                                        acta['archivo_justificante']
                                                ?.toString() ??
                                            '',
                                        'download',
                                      ),
                                      icon: const Icon(
                                        Icons.download,
                                        size: 18,
                                      ),
                                      label: const Text('Descargar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _abrirArchivo(
                                        acta['archivo_justificante']
                                                ?.toString() ??
                                            '',
                                        'view',
                                      ),
                                      icon: const Icon(
                                        Icons.visibility,
                                        size: 18,
                                      ),
                                      label: const Text('Ver'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _abrirArchivo(
                                        acta['archivo_justificante']
                                                ?.toString() ??
                                            '',
                                        'download',
                                      ),
                                      icon: const Icon(
                                        Icons.download,
                                        size: 18,
                                      ),
                                      label: const Text('Descargar'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ]),
                        const SizedBox(height: 24),
                        Text(
                          'Items Entregados',
                          style: TextStyle(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isMobile ? 10 : 14),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(9),
                                    topRight: Radius.circular(9),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Item',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                          fontSize: isMobile ? 11 : 13,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Contrato',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                          fontSize: isMobile ? 10 : 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Cantidad',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                          fontSize: isMobile ? 11 : 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (itemsEntregados.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(
                                    child: Text(
                                      'No hay items registrados',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                )
                              else
                                ...itemsEntregados.map((item) {
                                  return Container(
                                    padding: EdgeInsets.all(isMobile ? 8 : 12),
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
                                          flex: 3,
                                          child: Text(
                                            item['nombre_item'] ?? 'Sin nombre',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: isMobile ? 11 : 13,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item['numero_contrato'] ??
                                                item['contrato'] ??
                                                'N/A',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: isMobile ? 10 : 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isMobile ? 6 : 12,
                                              vertical: isMobile ? 4 : 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.green.shade200,
                                              ),
                                            ),
                                            child: Text(
                                              _formatNum(
                                                item['cantidad_entregada'],
                                              ),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: isMobile ? 12 : 14,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(9),
                                    bottomRight: Radius.circular(9),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total de items: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade700,
                                        fontSize: isMobile ? 12 : 13,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade200,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${itemsEntregados.length}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── FOOTER ──
                Container(
                  padding: EdgeInsets.all(isMobile ? 14 : 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: isMobile
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                                label: const Text('Cerrar'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: BorderSide(color: Colors.grey.shade400),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Imprimiendo acta...'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.print),
                                label: const Text('Imprimir'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                                label: const Text('Cerrar'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  side: BorderSide(color: Colors.grey.shade400),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Imprimiendo acta...'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.print),
                                label: const Text('Imprimir'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
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
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF2E7D32);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Scaffold(
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
              child: _buildLista(verde, isMobile),
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
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: verde, size: 28),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Volver al dashboard',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Consultar Actas',
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
            IconButton(
              icon: Icon(Icons.arrow_back, color: verde, size: 30),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Volver al dashboard',
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
                'Consultar Actas',
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

  Widget _buildLista(Color verde, bool isMobile) {
    if (_actas.isEmpty && !_cargando) {
      return Center(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 32 : 48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No hay actas registradas',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: TextField(
            controller: _busquedaController,
            onChanged: _filtrarActas,
            decoration: InputDecoration(
              hintText: 'Buscar por número, nombre o área...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _filtroBusqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _busquedaController.clear();
                        _filtrarActas('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.green, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isMobile ? 10 : 14,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
          child: Row(
            children: [
              Text(
                '${_actasFiltradas.length} de ${_actas.length} actas',
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarActas,
            color: verde,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: 8,
              ),
              itemCount: _actasFiltradas.length,
              itemBuilder: (ctx, i) {
                final acta = _actasFiltradas[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _verDetalleActa(acta),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Acta #${acta['numero_acta']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isMobile ? 12 : 14,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (acta['estado'] ?? 'activa')
                                      .toString()
                                      .toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.green.shade700,
                                size: isMobile ? 24 : 28,
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 8 : 10),
                          Text(
                            'Entregado a: ${acta['entregado_a'] ?? 'N/A'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: isMobile ? 13 : 14,
                            ),
                            maxLines: isMobile ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            children: [
                              Text(
                                'Fecha: ${_formatDate(acta['fecha_entrega'])}',
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                'Contrato: ${acta['numero_contrato'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
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
      ],
    );
  }

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }
}
