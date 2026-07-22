import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ConsultarContratoPage extends StatefulWidget {
  const ConsultarContratoPage({super.key});

  @override
  State<ConsultarContratoPage> createState() => _ConsultarContratoPageState();
}

class _ConsultarContratoPageState extends State<ConsultarContratoPage> {
  late String username;
  late String sector;
  late String rol;

  List<Map<String, dynamic>> _contratos = [];
  List<Map<String, dynamic>> _contratosFiltrados = [];
  bool _cargando = false;
  final _busquedaController = TextEditingController();
  String _filtroBusqueda = '';

  static const String _baseUrl = 'http://localhost/samde_db/api/contratos';

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
    _cargarContratos();
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

  String _formatearConPuntos(dynamic valor) {
    if (valor == null) return '0';
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
      if (contador % 3 == 0 && i != 0) resultado = '.' + resultado;
    }
    if (numero != entero) {
      final decimales = numero.toString().split('.');
      if (decimales.length > 1 && decimales[1].isNotEmpty) {
        resultado += '.${decimales[1]}';
      }
    }
    return resultado;
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toUpperCase()) {
      case 'EN EJECUCIÓN':
      case 'EN EJECUCION':
        return Colors.green;
      case 'FINALIZADO':
        return Colors.blue;
      case 'SUSPENDIDO':
        return Colors.orange;
      case 'CANCELADO':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ── LÓGICA DE DATOS ──────────────────────────────────────────
  Future<void> _cargarContratos() async {
    setState(() => _cargando = true);
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/listar_contrato.php'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        setState(() {
          _contratos = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _contratosFiltrados = _contratos;
        });
      }
    } catch (e) {
      debugPrint('Error cargando contratos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _filtrarContratos(String texto) {
    setState(() {
      _filtroBusqueda = texto.toLowerCase().trim();
      _contratosFiltrados = _filtroBusqueda.isEmpty
          ? _contratos
          : _contratos.where((contrato) {
              final numero = (contrato['numero_contrato'] ?? '').toLowerCase();
              final proveedor = (contrato['proveedor'] ?? '').toLowerCase();
              final objeto = (contrato['objeto_contrato'] ?? '').toLowerCase();
              final estado = (contrato['estado'] ?? '').toLowerCase();
              return numero.contains(_filtroBusqueda) ||
                  proveedor.contains(_filtroBusqueda) ||
                  objeto.contains(_filtroBusqueda) ||
                  estado.contains(_filtroBusqueda);
            }).toList();
    });
  }

  // ── MODAL DE DETALLES PROFESIONAL ────────────────────────────
  Future<void> _verDetalleContrato(Map<String, dynamic> contrato) async {
    final items = contrato['items'] as List? ?? [];
    final valorTotal =
        double.tryParse(contrato['valor_total']?.toString() ?? '0') ?? 0;

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
                      Icons.assignment,
                      color: Colors.green.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contrato #${contrato['numero_contrato']}',
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
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getEstadoColor(
                                contrato['estado'] ?? '',
                              ).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (contrato['estado'] ?? 'N/A').toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getEstadoColor(
                                  contrato['estado'] ?? '',
                                ),
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

              // Contenido Scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection('Información General', [
                        _buildInfoRow(
                          'Proveedor:',
                          contrato['proveedor'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Fecha Inicio:',
                          _formatDate(contrato['fecha_inicio']),
                        ),
                        _buildInfoRow(
                          'Fecha Fin:',
                          _formatDate(contrato['fecha_fin']),
                        ),
                        _buildInfoRow(
                          'Valor Total:',
                          '\$${_formatearConPuntos(valorTotal)}',
                        ),
                        if ((contrato['objeto_contrato'] ?? '')
                            .toString()
                            .isNotEmpty)
                          _buildInfoRow('Objeto:', contrato['objeto_contrato']),
                      ]),
                      const SizedBox(height: 20),

                      // Tabla de Items
                      Text(
                        'Items del Contrato',
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
                                    flex: 2,
                                    child: _buildTableHeader('Código'),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: _buildTableHeader('Item'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildTableHeader('Unidad'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildTableHeader('Cantidad'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildTableHeader('V. Unitario'),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _buildTableHeader('Subtotal'),
                                  ),
                                ],
                              ),
                            ),

                            // Filas de Items
                            if (items.isEmpty)
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
                              ...items.asMap().entries.map((entry) {
                                final index = entry.key;
                                final item = entry.value;
                                final cantidad =
                                    double.tryParse(
                                      item['cantidad']?.toString() ?? '0',
                                    ) ??
                                    0;
                                final valorUnitario =
                                    double.tryParse(
                                      item['valor_unitario']?.toString() ?? '0',
                                    ) ??
                                    0;
                                final subtotal = cantidad * valorUnitario;

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
                                        flex: 2,
                                        child: Text(
                                          item['codigo']?.toString() ?? '-',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item['nombre']?.toString() ?? 'N/A',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item['unidad']?.toString() ?? '-',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 12,
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
                                            _formatearConPuntos(cantidad),
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
                                          '\$${_formatearConPuntos(valorUnitario)}',
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
                                          '\$${_formatearConPuntos(subtotal)}',
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
                              }).toList(),

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
                                      '\$${_formatearConPuntos(valorTotal)}',
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
                              content: Text('Imprimiendo contrato...'),
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
                      'Consultar Contratos',
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
    if (_contratos.isEmpty && !_cargando) {
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
                  'No hay contratos registrados',
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
            onChanged: _filtrarContratos,
            decoration: InputDecoration(
              hintText: 'Buscar por número, proveedor, objeto o estado...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _filtroBusqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _busquedaController.clear();
                        _filtrarContratos('');
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
                '${_contratosFiltrados.length} de ${_contratos.length} contratos',
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
            onRefresh: _cargarContratos,
            color: verde,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _contratosFiltrados.length,
              itemBuilder: (ctx, i) {
                final contrato = _contratosFiltrados[i];
                final items = contrato['items'] as List? ?? [];
                final valorTotal =
                    double.tryParse(
                      contrato['valor_total']?.toString() ?? '0',
                    ) ??
                    0;
                final estado = contrato['estado'] ?? 'N/A';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _verDetalleContrato(contrato),
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
                                      '#${contrato['numero_contrato']}',
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
                                      color: _getEstadoColor(
                                        estado,
                                      ).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      estado.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _getEstadoColor(estado),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                contrato['proveedor'] ?? 'Sin proveedor',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 400,
                                child: Text(
                                  contrato['objeto_contrato'] ?? 'Sin objeto',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    '\$${_formatearConPuntos(valorTotal)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: verde,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Inicio: ${_formatDate(contrato['fecha_inicio'])}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Icons.shopping_bag,
                                    size: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${items.length} items',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
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
