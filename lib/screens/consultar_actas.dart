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

  static const String _baseUrl = 'http://localhost/samde_db/api';

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
        if (parts.length == 3) {
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
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

  // ✅ FUNCIÓN PARA VER O DESCARGAR ARCHIVO
  Future<void> _abrirArchivo(String nombreArchivo, String accion) async {
    if (nombreArchivo.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay archivo disponible'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Construir URL con parámetro action (view o download)
    final urlCompleta =
        '$_baseUrl/actas/download_acta.php?file=$nombreArchivo&action=$accion';
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

  Future<void> _verDetalleActa(Map<String, dynamic> acta) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    List<Map<String, dynamic>> itemsEntregados = [];
    try {
      final actaId = acta['id'];
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

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 900,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header profesional
              Container(
                padding: const EdgeInsets.all(20),
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
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Acta #${acta['numero_acta']}',
                            style: TextStyle(
                              fontSize: 20,
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
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),

              // Contenido scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información general
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
                        if (acta['documento_identidad'] != null &&
                            acta['documento_identidad'].toString().isNotEmpty)
                          _buildInfoRow(
                            'Documento:',
                            acta['documento_identidad'],
                          ),
                        if (acta['telefono'] != null &&
                            acta['telefono'].toString().isNotEmpty)
                          _buildInfoRow('Teléfono:', acta['telefono']),
                      ]),
                      const SizedBox(height: 20),

                      // Quien entregó
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

                      // Observaciones
                      if (acta['observaciones'] != null &&
                          acta['observaciones'].toString().isNotEmpty)
                        _buildInfoSection('Observaciones', [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              acta['observaciones'],
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ]),
                      const SizedBox(height: 20),

                      // ✅ ARCHIVO ADJUNTO CON DOS BOTONES (VER Y DESCARGAR)
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
                          Row(
                            children: [
                              // ✅ BOTÓN VER
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final archivo =
                                        acta['archivo_justificante']
                                            ?.toString() ??
                                        '';
                                    _abrirArchivo(archivo, 'view');
                                  },
                                  icon: const Icon(Icons.visibility, size: 18),
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
                              // ✅ BOTÓN DESCARGAR
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final archivo =
                                        acta['archivo_justificante']
                                            ?.toString() ??
                                        '';
                                    _abrirArchivo(archivo, 'download');
                                  },
                                  icon: const Icon(Icons.download, size: 18),
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

                      // Items entregados - Tabla profesional
                      Text(
                        'Items Entregados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green.shade200),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            // Header de la tabla
                            Container(
                              padding: const EdgeInsets.all(14),
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
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Contrato',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Cantidad',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Items
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
                              ...itemsEntregados.asMap().entries.map((entry) {
                                final item = entry.value;
                                return Container(
                                  padding: const EdgeInsets.all(12),
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
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          item['numero_contrato'] ??
                                              item['contrato'] ??
                                              'N/A',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                              fontSize: 14,
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

                            // Footer con total
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

              // Botones de acción profesionales
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text('Cerrar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF2E7D32);

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            height: 130,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 192, 231, 195),
              border: Border(bottom: BorderSide(color: verde, width: 4)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: verde, size: 30),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  tooltip: 'Volver al dashboard',
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
                      'Consultar Actas',
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

          // Contenido
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
              child: _buildLista(verde),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(Color verde) {
    if (_actas.isEmpty && !_cargando) {
      return Center(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Padding(
            padding: EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
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
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _busquedaController,
            onChanged: _filtrarActas,
            decoration: InputDecoration(
              hintText: 'Buscar por número, nombre, área o contrato...',
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),

        // Contador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
        const SizedBox(height: 12),

        // Lista
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargarActas,
            color: verde,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    onTap: () {
                      _verDetalleActa(acta);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Acta #${acta['numero_acta']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
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
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Entregado a: ${acta['entregado_a'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fecha: ${_formatDate(acta['fecha_entrega'])}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Contrato: ${acta['numero_contrato'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.green.shade700,
                            size: 28,
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
