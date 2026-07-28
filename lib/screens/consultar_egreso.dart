import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ConsultarEgresoPage extends StatefulWidget {
  const ConsultarEgresoPage({super.key});

  @override
  State<ConsultarEgresoPage> createState() => _ConsultarEgresoPageState();
}

class _ConsultarEgresoPageState extends State<ConsultarEgresoPage> {
  late String username;
  late String sector;
  late String rol;

  List<Map<String, dynamic>> _egresos = [];
  List<Map<String, dynamic>> _egresosFiltrados = [];
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
    _cargarEgresos();
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

  String _formatearNumero(dynamic valor) {
    if (valor == null) return '0';
    final double n = valor is double
        ? valor
        : double.tryParse(valor.toString()) ?? 0;
    return n == n.truncateToDouble()
        ? n.truncate().toString()
        : n.toStringAsFixed(2);
  }

  String _formatearConPuntos(dynamic valor) {
    if (valor == null) return '0';
    final double n = valor is double
        ? valor
        : double.tryParse(valor.toString()) ?? 0;
    final String s = n.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  Future<void> _cargarEgresos() async {
    setState(() => _cargando = true);
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/egresos/listar_egresos.php'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        setState(() {
          _egresos = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _egresosFiltrados = _egresos;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrarEgresos(String texto) {
    setState(() {
      _filtroBusqueda = texto.toLowerCase().trim();
      _egresosFiltrados = _filtroBusqueda.isEmpty
          ? _egresos
          : _egresos.where((egreso) {
              final numero = (egreso['numero_egreso'] ?? '').toLowerCase();
              final bodega = (egreso['bodega_nombre'] ?? '').toLowerCase();
              final usuario = (egreso['usuario_nombre'] ?? '').toLowerCase();
              return numero.contains(_filtroBusqueda) ||
                  bodega.contains(_filtroBusqueda) ||
                  usuario.contains(_filtroBusqueda);
            }).toList();
    });
  }

  // ✅ MODAL PROFESIONAL DE DETALLES
  Future<void> _verDetalleEgreso(Map<String, dynamic> egreso) async {
    // Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    // Cargar los items del egreso
    List<Map<String, dynamic>> itemsEgreso = [];
    try {
      final egresoId = egreso['id'];
      final response = await http
          .get(Uri.parse('$_baseUrl/egresos/obtener_egreso.php?id=$egresoId'))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        itemsEgreso = List<Map<String, dynamic>>.from(
          data['data']['detalles'] ?? [],
        );
      }
    } catch (e) {
      debugPrint('Error cargando items: $e');
    } finally {
      if (mounted) Navigator.pop(context);
    }

    // Calcular total
    double total = 0.0;
    for (var item in itemsEgreso) {
      final cantidad =
          double.tryParse(item['cantidad']?.toString() ?? '0') ?? 0;
      final precio =
          double.tryParse(item['precio_unitario']?.toString() ?? '0') ?? 0;
      total += cantidad * precio;
    }

    // Mostrar modal de detalles profesional
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
                      Icons.inventory_2_outlined,
                      color: Colors.green.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Egreso #${egreso['numero_egreso']}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bodega: ${egreso['bodega_nombre'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.green.shade700,
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
                        _buildInfoRow('Fecha:', _formatDate(egreso['fecha'])),
                        _buildInfoRow(
                          'Bodega:',
                          egreso['bodega_nombre'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Usuario:',
                          egreso['usuario_nombre'] ?? 'N/A',
                        ),
                        if (egreso['observacion'] != null &&
                            egreso['observacion'].toString().isNotEmpty)
                          _buildInfoRow('Observación:', egreso['observacion']),
                      ]),
                      const SizedBox(height: 20),

                      // ITEMS DEL EGRESO - TABLA PROFESIONAL
                      Text(
                        'Items del Egreso',
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
                                    flex: 1,
                                    child: Text(
                                      '#',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
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
                                      'Cantidad',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Precio Unit.',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Subtotal',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Items
                            if (itemsEgreso.isEmpty)
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
                              ...itemsEgreso.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                final cantidad =
                                    double.tryParse(
                                      item['cantidad']?.toString() ?? '0',
                                    ) ??
                                    0;
                                final precio =
                                    double.tryParse(
                                      item['precio_unitario']?.toString() ??
                                          '0',
                                    ) ??
                                    0;
                                final subtotal = cantidad * precio;

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
                                        flex: 1,
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
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
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            _formatearNumero(cantidad),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _formatearConPuntos(precio),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          _formatearConPuntos(subtotal),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
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
                                    'TOTAL: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green.shade300,
                                      ),
                                    ),
                                    child: Text(
                                      _formatearConPuntos(total),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
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
                              content: Text('Imprimiendo egreso...'),
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

  // Helper para secciones de información
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

  // Helper para filas de información
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
                // Botón para volver al dashboard
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
                      'Consultar Egreso',
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
    if (_egresos.isEmpty && !_cargando) {
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
                  'No hay egresos registrados',
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
            onChanged: _filtrarEgresos,
            decoration: InputDecoration(
              hintText: 'Buscar por número, bodega, usuario...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _filtroBusqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _busquedaController.clear();
                        _filtrarEgresos('');
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
                '${_egresosFiltrados.length} de ${_egresos.length} egresos',
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
            onRefresh: _cargarEgresos,
            color: verde,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _egresosFiltrados.length,
              itemBuilder: (ctx, i) {
                final egreso = _egresosFiltrados[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      _verDetalleEgreso(egreso);
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
                                      '${egreso['numero_egreso']}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Bodega: ${egreso['bodega_nombre'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Usuario: ${egreso['usuario_nombre'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fecha: ${_formatDate(egreso['fecha'])}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Items: ${egreso['total_items'] ?? '0'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Icon(
                            Icons.visibility_outlined,
                            color: Colors.blue.shade700,
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
