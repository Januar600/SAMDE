import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class VistaPreviaContratoPage extends StatefulWidget {
  final int contratoId;

  const VistaPreviaContratoPage({super.key, required this.contratoId});

  @override
  State<VistaPreviaContratoPage> createState() =>
      _VistaPreviaContratoPageState();
}

class _VistaPreviaContratoPageState extends State<VistaPreviaContratoPage> {
  bool _cargando = true;
  String? _errorMensaje;

  Map<String, dynamic>? _contrato;
  List<Map<String, dynamic>> _items = [];

  static const String _baseUrl = 'http://localhost/samde_db/api';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/reportes/obtener_detalles_contrato.php?id=${widget.contratoId}',
            ),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data['success'] == true &&
          data['data'] != null) {
        final itemsList = data['data']['items'];
        final List<Map<String, dynamic>> itemsProcesados = [];

        if (itemsList != null && itemsList is List) {
          for (var item in itemsList) {
            if (item != null && item is Map) {
              itemsProcesados.add(Map<String, dynamic>.from(item));
            }
          }
        }

        if (mounted) {
          setState(() {
            _contrato = data['data']['contrato'] != null
                ? Map<String, dynamic>.from(data['data']['contrato'])
                : null;
            _items = itemsProcesados;
            _cargando = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMensaje = data['message'] ?? 'Error al cargar los datos';
            _cargando = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMensaje = 'Error de conexión: $e';
          _cargando = false;
        });
      }
    }
  }

  String _formatearNumero(dynamic value) {
    if (value == null || value == '0' || value == 0 || value == 'null')
      return '0';
    try {
      final numValue = value is String
          ? double.tryParse(value) ?? 0
          : value.toDouble();
      return numValue
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    } catch (e) {
      return '0';
    }
  }

  String _formatearFecha(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == 'null') return 'N/A';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) return '${parts[2]}/${parts[1]}/${parts[0]}';
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF2E7D32);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: Column(
        children: [
          // ✅ BANNER INSTITUCIONAL
          _buildBanner(verde, isMobile),
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
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    )
                  : _errorMensaje != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _errorMensaje!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 12 : 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSeccionDatos(verde, isMobile),
                              const SizedBox(height: 24),
                              _buildSeccionItems(verde, isMobile),
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

  // ✅ WIDGET DEL BANNER INSTITUCION
  Widget _buildBanner(Color verde, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFB8E6B8), // Verde claro institucional
        border: Border(bottom: BorderSide(color: verde, width: 3)),
      ),
      child: isMobile
          ? Column(
              children: [
                Row(
                  children: [
                    // ✅ BOTÓN VOLVER EN MÓVIL
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: verde, size: 28),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Volver',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Image.asset(
                        'assets/logos/banner_gobernacion.png',
                        height: 60,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Reportes de Contratos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          : Row(
              children: [
                // ✅ BOTÓN VOLVER EN DESKTOP
                IconButton(
                  icon: Icon(Icons.arrow_back, color: verde, size: 30),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Volver a Reportes',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Image.asset(
                  'assets/logos/banner_gobernacion.png',
                  height: 110,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    'Reportes de Contratos',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: verde,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 100), // Espacio para equilibrar
              ],
            ),
    );
  }

  Widget _buildSeccionDatos(Color verde, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assignment, color: verde, size: 20),
            const SizedBox(width: 8),
            Text(
              'Datos del Contrato',
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
          _buildCampo('Proveedor', _contrato?['proveedor'] ?? 'N/A'),
          const SizedBox(height: 14),
          _buildCampo(
            'Número del Contrato',
            _contrato?['numero_contrato'] ?? 'N/A',
          ),
          const SizedBox(height: 14),
          _buildCampo(
            'Fecha Inicio',
            _formatearFecha(_contrato?['fecha_inicio']),
          ),
          const SizedBox(height: 14),
          _buildCampo('Fecha Fin', _formatearFecha(_contrato?['fecha_fin'])),
          const SizedBox(height: 14),
          _buildCampo('Tipo de Contrato', _contrato?['tipo_contrato'] ?? 'N/A'),
          const SizedBox(height: 14),
          _buildCampo(
            'Modalidad de Selección',
            _contrato?['modalidad_seleccion'] ?? 'N/A',
          ),
          const SizedBox(height: 14),
          _buildCampo(
            'Objeto del Contrato',
            _contrato?['objeto_contrato'] ?? 'N/A',
            multiline: true,
          ),
          const SizedBox(height: 14),
          _buildCampo(
            'Valor Total',
            '\$${_formatearNumero(_contrato?['valor_total'])}',
          ),
          const SizedBox(height: 14),
          _buildCampo('Estado', _contrato?['estado'] ?? 'N/A'),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildCampo(
                  'Proveedor',
                  _contrato?['proveedor'] ?? 'N/A',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildCampo(
                  'Número del Contrato',
                  _contrato?['numero_contrato'] ?? 'N/A',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildCampo(
                  'Fecha Inicio',
                  _formatearFecha(_contrato?['fecha_inicio']),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildCampo(
                  'Fecha Fin',
                  _formatearFecha(_contrato?['fecha_fin']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildCampo(
                  'Tipo de Contrato',
                  _contrato?['tipo_contrato'] ?? 'N/A',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildCampo(
                  'Modalidad de Selección',
                  _contrato?['modalidad_seleccion'] ?? 'N/A',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildCampo(
            'Objeto del Contrato',
            _contrato?['objeto_contrato'] ?? 'N/A',
            multiline: true,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildCampo(
                  'Valor Total',
                  '\$${_formatearNumero(_contrato?['valor_total'])}',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildCampo('Estado', _contrato?['estado'] ?? 'N/A'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSeccionItems(Color verde, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shopping_cart, color: verde, size: 20),
            const SizedBox(width: 8),
            Text(
              'Items del Contrato',
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
                color: verde.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_items.length}',
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

        if (_items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'Sin items registrados',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 484),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  physics: const BouncingScrollPhysics(),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                    child: Scrollbar(
                      thumbVisibility: true,
                      thickness: 8,
                      radius: const Radius.circular(8),
                      child: DataTable(
                        columnSpacing: 12,
                        headingRowHeight: 44,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 44,
                        horizontalMargin: 8,
                        headingRowColor: WidgetStateProperty.all(
                          Colors.green.shade50,
                        ),
                        dividerThickness: 1,
                        dataRowColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.hovered)) {
                            return Colors.green.withValues(alpha: 0.03);
                          }
                          return Colors.white;
                        }),
                        border: TableBorder.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        columns: [
                          DataColumn(
                            label: Text(
                              'Código',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: verde,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Item',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: verde,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Unidad',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: verde,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Cant.\nContratada',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: verde,
                                fontSize: 10,
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Cant.\nIngresada',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: verde,
                                fontSize: 10,
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Cant.\nEgresada',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: verde,
                                fontSize: 10,
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Cant.\nEntregada',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: verde,
                                fontSize: 10,
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'V. Unit.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: verde,
                                fontSize: 11,
                              ),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Subtotal',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: verde,
                                fontSize: 11,
                              ),
                            ),
                            numeric: true,
                          ),
                        ],
                        rows: _items.asMap().entries.map((e) {
                          final i = e.key;
                          final item = e.value;

                          final codigo = item['codigo']?.toString() ?? 'N/A';
                          final nombre = item['nombre']?.toString() ?? 'N/A';
                          final unidad = item['unidad']?.toString() ?? 'N/A';
                          final cantContratada =
                              item['cantidad_contratada'] ?? 0;
                          final cantIngresada = item['ingresado'] ?? 0;
                          final cantEgresada = item['egresado'] ?? 0;
                          final cantEntregada = item['entregado'] ?? 0;
                          final valorUnitario = item['valor_unitario'] ?? 0;
                          final subtotal = item['subtotal'] ?? 0;

                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  codigo,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 220,
                                  child: Text(
                                    nombre,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  unidad,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatearNumero(cantContratada),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatearNumero(cantIngresada),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatearNumero(cantEgresada),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatearNumero(cantEntregada),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '\$${_formatearNumero(valorUnitario)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  '\$${_formatearNumero(subtotal)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: verde,
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
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCampo(String label, String value, {bool multiline = false}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        maxLines: multiline ? 3 : 1,
        overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
      ),
    );
  }
}
