import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ConsultarIngresoPage extends StatefulWidget {
  const ConsultarIngresoPage({super.key});

  @override
  State<ConsultarIngresoPage> createState() => _ConsultarIngresoPageState();
}

class _ConsultarIngresoPageState extends State<ConsultarIngresoPage> {
  late String username;
  late String sector;
  late String rol;

  List<Map<String, dynamic>> _ingresos = [];
  List<Map<String, dynamic>> _ingresosFiltrados = [];
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
    _cargarIngresos();
  }

  // ── HELPERS DE FORMATO ───────────────────────────────────────
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

  String _formatearNumero(dynamic valor) {
    if (valor == null) return '0';
    final double n = valor is double
        ? valor
        : double.tryParse(valor.toString()) ?? 0;
    return n == n.truncateToDouble()
        ? n.truncate().toString()
        : n.toStringAsFixed(2);
  }

  String _formatearPrecio(dynamic valor) {
    if (valor == null) return '\$0';
    final double numero = valor is double
        ? valor
        : double.tryParse(valor.toString()) ?? 0;
    final int entero = numero.round();
    final String numeroStr = entero.toString();
    String resultado = '';
    int contador = 0;
    for (int i = numeroStr.length - 1; i >= 0; i--) {
      resultado = numeroStr[i] + resultado;
      contador++;
      if (contador % 3 == 0 && i != 0) resultado = '.$resultado';
    }
    return '\$$resultado';
  }

  double _convertirADouble(dynamic valor) {
    if (valor == null) return 0.0;
    if (valor is double) return valor;
    if (valor is int) return valor.toDouble();
    if (valor is String) {
      final limpio = valor.replaceAll(',', '').replaceAll(' ', '').trim();
      return double.tryParse(limpio) ?? 0.0;
    }
    return 0.0;
  }

  // ── LÓGICA DE DATOS ──────────────────────────────────────────
  Future<void> _cargarIngresos() async {
    setState(() => _cargando = true);
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/ingresos/listar_ingresos.php'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        setState(() {
          _ingresos = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _ingresosFiltrados = _ingresos;
        });
      }
    } catch (e) {
      debugPrint('Error cargando ingresos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrarIngresos(String texto) {
    setState(() {
      _filtroBusqueda = texto.toLowerCase().trim();
      _ingresosFiltrados = _filtroBusqueda.isEmpty
          ? _ingresos
          : _ingresos.where((ingreso) {
              final numero = (ingreso['numero_ingreso'] ?? '').toLowerCase();
              final contrato = (ingreso['numero_contrato'] ?? '').toLowerCase();
              final bodega = (ingreso['bodega'] ?? '').toLowerCase();
              final usuario = (ingreso['usuario_registro'] ?? '').toLowerCase();
              return numero.contains(_filtroBusqueda) ||
                  contrato.contains(_filtroBusqueda) ||
                  bodega.contains(_filtroBusqueda) ||
                  usuario.contains(_filtroBusqueda);
            }).toList();
    });
  }

  // ── MODAL DE DETALLES PROFESIONAL ────────────────────────────
  Future<void> _verDetalleIngreso(Map<String, dynamic> ingreso) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    List<Map<String, dynamic>> detalles = [];
    try {
      final ingresoId = ingreso['id'];
      final response = await http
          .get(
            Uri.parse('$_baseUrl/ingresos/obtener_ingreso.php?id=$ingresoId'),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        detalles = List<Map<String, dynamic>>.from(
          data['data']['detalles'] ?? [],
        );
      }
    } catch (e) {
      debugPrint('Error cargando detalles: $e');
    } finally {
      if (mounted) Navigator.pop(context);
    }

    // Calcular total
    double total = 0.0;
    for (var item in detalles) {
      final cantidad = _convertirADouble(item['cantidad_ingresada']);
      final precio = _convertirADouble(
        item['precio_unitario'] ?? item['valor_unitario'],
      );
      total += cantidad * precio;
    }

    final usuarioMostrar =
        ingreso['usuario_nombre'] ?? ingreso['usuario_registro'] ?? 'N/A';

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
              // Header
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
                      Icons.inventory_2,
                      color: Colors.green.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ingreso #${ingreso['numero_ingreso']}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Contrato: ${ingreso['numero_contrato'] ?? 'N/A'}',
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

              // Contenido Scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection('Información General', [
                        _buildInfoRow(
                          'Fecha:',
                          _formatDate(
                            ingreso['fecha_ingreso'] ?? ingreso['fecha'],
                          ),
                        ),
                        _buildInfoRow('Bodega:', ingreso['bodega'] ?? 'N/A'),
                        _buildInfoRow('Usuario:', usuarioMostrar),
                        if ((ingreso['observacion'] ?? '')
                            .toString()
                            .trim()
                            .isNotEmpty)
                          _buildInfoRow(
                            'Observación:',
                            ingreso['observacion'].toString().trim(),
                          ),
                      ]),
                      const SizedBox(height: 20),

                      // Tabla de Items
                      Text(
                        'Items del Ingreso',
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
                            // Header Tabla
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
                                    child: _buildTableHeader('#'),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: _buildTableHeader('Item'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildTableHeader(
                                      'Cant. Contratada',
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildTableHeader('Cant. Ingresada'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildTableHeader('Precio Unit.'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildTableHeader('Subtotal'),
                                  ),
                                ],
                              ),
                            ),

                            // Filas de Items
                            if (detalles.isEmpty)
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
                              ...detalles.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                final cantIngresada = _convertirADouble(
                                  item['cantidad_ingresada'],
                                );
                                final precio = _convertirADouble(
                                  item['precio_unitario'] ??
                                      item['valor_unitario'],
                                );
                                final subtotal = cantIngresada * precio;

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
                                          style: const TextStyle(fontSize: 13),
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
                                        flex: 2,
                                        child: Text(
                                          _formatearNumero(
                                            item['cantidad_contratada'],
                                          ),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.green.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            _formatearNumero(cantIngresada),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _formatearPrecio(precio),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _formatearPrecio(subtotal),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                            // Footer Total
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
                                      _formatearPrecio(total),
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

              // Botones de Acción
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
                              content: Text('Imprimiendo ingreso...'),
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

  Widget _buildTableHeader(String text) => Text(
    text,
    style: TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.green.shade800,
      fontSize: 12,
    ),
    textAlign: TextAlign.center,
  );

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

  // ── UI PRINCIPAL ─────────────────────────────────────────────
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
                  onPressed: () => Navigator.pop(context),
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
                      'Consultar Ingresos',
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
    if (_ingresos.isEmpty && !_cargando) {
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
                  'No hay ingresos registrados',
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
            onChanged: _filtrarIngresos,
            decoration: InputDecoration(
              hintText: 'Buscar por número, contrato, bodega o usuario...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _filtroBusqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _busquedaController.clear();
                        _filtrarIngresos('');
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
                '${_ingresosFiltrados.length} de ${_ingresos.length} ingresos',
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
            onRefresh: _cargarIngresos,
            color: verde,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _ingresosFiltrados.length,
              itemBuilder: (ctx, i) {
                final ingreso = _ingresosFiltrados[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _verDetalleIngreso(ingreso),
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
                                      '${ingreso['numero_ingreso']}',
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
                                'Contrato: ${ingreso['numero_contrato'] ?? 'N/A'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bodega: ${ingreso['bodega'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Usuario: ${ingreso['usuario_registro'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fecha: ${_formatDate(ingreso['fecha_ingreso'] ?? ingreso['fecha'])}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Items: ${ingreso['total_items'] ?? '0'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.visibility_outlined,
                            color: Colors.blue,
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
