import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/drawer_menu.dart';

class RegistrarContratoPage extends StatefulWidget {
  const RegistrarContratoPage({super.key});

  @override
  State<RegistrarContratoPage> createState() => _RegistrarContratoPageState();
}

class _RegistrarContratoPageState extends State<RegistrarContratoPage> {
  late String username;
  late String sector;
  late String rol;

  final _formKey = GlobalKey<FormState>();
  final _proveedorController = TextEditingController();
  final _numeroController = TextEditingController();
  final _objetoController = TextEditingController();
  final _valorTotalController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final _fechaFinController = TextEditingController();

  String _estadoSeleccionado = 'EN EJECUCIÓN';

  // ✅ NUEVOS CAMPOS
  String _tipoContrato = 'Contrato de obra';
  String _modalidadSeleccion = 'Contratación directa';

  final List<Map<String, dynamic>> _items = [];
  final _itemCodigoController = TextEditingController();
  final _itemNombreController = TextEditingController();
  final _itemDescripcionController = TextEditingController();
  final _itemUnidadController = TextEditingController();
  final _itemCantidadController = TextEditingController();
  final _itemValorUnitarioController = TextEditingController();

  bool _cargando = false;
  bool _mostrandoLista = false;
  List<Map<String, dynamic>> _contratos = [];
  List<Map<String, dynamic>> _contratosFiltrados = [];

  final _searchController = TextEditingController();
  String _searchQuery = '';

  int? _editandoId;

  static const String _baseUrl = 'http://localhost/samde_db/api/contratos';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
    username = map['username'] ?? 'Usuario';
    sector = map['sector'] ?? 'No Asignado';
    rol = map['rol'] ?? 'consulta';
  }

  @override
  void initState() {
    super.initState();
    _cargarContratos();
    _searchController.addListener(_filtrarContratos);

    _valorTotalController.addListener(
      () => _formatearMiles(_valorTotalController),
    );
    _itemValorUnitarioController.addListener(
      () => _formatearMiles(_itemValorUnitarioController),
    );
  }

  void _formatearMiles(TextEditingController controller) {
    if (_formateando) return;
    final texto = controller.text;
    if (texto.isEmpty) return;

    final soloNumeros = texto.replaceAll('.', '');
    if (soloNumeros.isEmpty || double.tryParse(soloNumeros) == null) return;

    final numero = double.tryParse(soloNumeros) ?? 0;
    final parteEntera = numero.truncate().toString();
    final parteDecimal = numero.toString().contains('.')
        ? numero.toString().split('.')[1]
        : '';

    String resultado = '';
    int contador = 0;
    for (int i = parteEntera.length - 1; i >= 0; i--) {
      resultado = parteEntera[i] + resultado;
      contador++;
      if (contador % 3 == 0 && i != 0) {
        resultado = '.$resultado';
      }
    }

    if (parteDecimal.isNotEmpty) {
      resultado += '.$parteDecimal';
    }

    _formateando = true;
    controller.text = resultado;
    controller.selection = TextSelection.collapsed(offset: resultado.length);
    _formateando = false;
  }

  bool _formateando = false;

  void _filtrarContratos() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      if (_searchQuery.isEmpty) {
        _contratosFiltrados = List.from(_contratos);
      } else {
        _contratosFiltrados = _contratos.where((contrato) {
          final proveedor = (contrato['proveedor'] ?? '').toLowerCase();
          final numero = (contrato['numero_contrato'] ?? '').toLowerCase();
          final objeto = (contrato['objeto_contrato'] ?? '').toLowerCase();
          final estado = (contrato['estado'] ?? '').toLowerCase();
          return proveedor.contains(_searchQuery) ||
              numero.contains(_searchQuery) ||
              objeto.contains(_searchQuery) ||
              estado.contains(_searchQuery);
        }).toList();
      }
    });
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
      if (contador % 3 == 0 && i != 0) {
        resultado = '.$resultado';
      }
    }

    if (numero != entero) {
      final decimales = numero.toString().split('.')[1];
      if (decimales.isNotEmpty) resultado += '.$decimales';
    }
    return resultado;
  }

  void _mostrarVistaPrevia(Map<String, dynamic> contrato) {
    final items = contrato['items'] as List? ?? [];
    final String numero = contrato['numero_contrato'] ?? 'N/A';
    final String proveedor = contrato['proveedor'] ?? 'N/A';
    final String objeto = contrato['objeto_contrato'] ?? 'N/A';
    final String tipoContrato = contrato['tipo_contrato'] ?? 'N/A';
    final String modalidad = contrato['modalidad_seleccion'] ?? 'N/A';
    final String fechaInicio = contrato['fecha_inicio'] ?? 'N/A';
    final String fechaFin = contrato['fecha_fin'] ?? 'N/A';
    final String estado = contrato['estado'] ?? 'N/A';
    final double valorTotal =
        double.tryParse(contrato['valor_total']?.toString() ?? '0') ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.assignment, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Detalle del Contrato #$numero',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Proveedor', proveedor),
                  _buildInfoRow('Número', numero),
                  _buildInfoRow('Tipo Contrato', tipoContrato),
                  _buildInfoRow('Modalidad', modalidad),
                  _buildInfoRow('Fecha Inicio', fechaInicio),
                  _buildInfoRow('Fecha Fin', fechaFin),
                  _buildInfoRow('Objeto del Contrato', objeto),
                  _buildInfoRow(
                    'Valor Total',
                    '\$${_formatearConPuntos(valorTotal)}',
                  ),
                  _buildInfoRow(
                    'Estado',
                    estado,
                    color: _getEstadoColor(estado),
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Items del Contrato',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (items.isEmpty)
                    const Text(
                      'No hay items registrados',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: 12,
                          headingRowHeight: 36,
                          headingRowColor: WidgetStateProperty.all(
                            Colors.green.shade50,
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                '#',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Código',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Item',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Descripción',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Unidad',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Cantidad',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'V. Unitario',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Subtotal',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          rows: items.asMap().entries.map((entry) {
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

                            return DataRow(
                              cells: [
                                DataCell(Text('${index + 1}')),
                                DataCell(
                                  Text(
                                    item['codigo']?.toString() ?? '-',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item['nombre']?.toString() ?? 'N/A',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 120,
                                    child: Text(
                                      item['descripcion']?.toString() ?? '-',
                                      style: const TextStyle(fontSize: 11),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    item['unidad']?.toString() ?? '-',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _formatearConPuntos(cantidad),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '\$${_formatearConPuntos(valorUnitario)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '\$${_formatearConPuntos(subtotal)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  if (items.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'TOTAL: ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${_formatearConPuntos(valorTotal)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(': ', style: TextStyle(color: Colors.grey.shade600)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w500, color: color),
            ),
          ),
        ],
      ),
    );
  }

  void _agregarItem() {
    if (_itemNombreController.text.isEmpty ||
        _itemCantidadController.text.isEmpty ||
        _itemValorUnitarioController.text.isEmpty) {
      _snack(
        'Nombre, cantidad y valor unitario son obligatorios',
        Colors.orange,
      );
      return;
    }

    final cantidadTexto = _itemCantidadController.text.replaceAll('.', '');
    final valorTexto = _itemValorUnitarioController.text.replaceAll('.', '');

    final double cant = double.tryParse(cantidadTexto) ?? 0;
    final double valor = double.tryParse(valorTexto) ?? 0;

    setState(() {
      _items.add({
        'codigo': _itemCodigoController.text.isNotEmpty
            ? _itemCodigoController.text
            : (_items.length + 1).toString(),
        'nombre': _itemNombreController.text,
        'descripcion': _itemDescripcionController.text,
        'unidad': _itemUnidadController.text.isNotEmpty
            ? _itemUnidadController.text
            : 'Unidad',
        'cantidad': cant,
        'valor_unitario': valor,
        'subtotal': cant * valor,
      });
      _itemCodigoController.clear();
      _itemNombreController.clear();
      _itemDescripcionController.clear();
      _itemUnidadController.clear();
      _itemCantidadController.clear();
      _itemValorUnitarioController.clear();
    });
  }

  void _eliminarItem(int index) => setState(() => _items.removeAt(index));

  Future<void> _registrarContrato() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      _snack('Debes agregar al menos un item', Colors.orange);
      return;
    }
    setState(() => _cargando = true);

    final url = Uri.parse('$_baseUrl/registrar_contrato.php');
    final data = _buildPayload();

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );
      final res = jsonDecode(response.body);

      if (response.statusCode == 201 && res['success'] == true) {
        _limpiarFormulario();
        _snack('✅ Contrato registrado exitosamente', Colors.green);
        await _cargarContratos();
        if (mounted) setState(() => _mostrandoLista = true);
      } else {
        _snack('❌ ${res['message'] ?? 'Error al registrar'}', Colors.red);
      }
    } catch (e) {
      _snack('❌ Error de conexión: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _prepararEdicion(Map<String, dynamic> contrato) {
    _editandoId = contrato['id'] is int
        ? contrato['id']
        : int.tryParse(contrato['id'].toString()) ?? 0;

    _proveedorController.text = contrato['proveedor'] ?? '';
    _numeroController.text = contrato['numero_contrato'] ?? '';
    _objetoController.text = contrato['objeto_contrato'] ?? '';
    _valorTotalController.text = _formatearConPuntos(contrato['valor_total']);
    _fechaInicioController.text = contrato['fecha_inicio'] ?? '';
    _fechaFinController.text = contrato['fecha_fin'] ?? '';

    _estadoSeleccionado = contrato['estado'] ?? 'EN EJECUCIÓN';
    _tipoContrato = contrato['tipo_contrato'] ?? 'Contrato de obra';
    _modalidadSeleccion =
        contrato['modalidad_seleccion'] ?? 'Contratación directa';

    _items.clear();
    final rawItems = contrato['items'] as List? ?? [];
    for (final item in rawItems) {
      final cant = double.tryParse(item['cantidad'].toString()) ?? 0;
      final valor = double.tryParse(item['valor_unitario'].toString()) ?? 0;
      _items.add({
        'codigo': item['codigo'] ?? '',
        'nombre': item['nombre'] ?? '',
        'descripcion': item['descripcion'] ?? '',
        'unidad': item['unidad'] ?? '',
        'cantidad': cant,
        'valor_unitario': valor,
        'subtotal': cant * valor,
      });
    }

    setState(() => _mostrandoLista = false);
  }

  Future<void> _guardarEdicion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      _snack('Debes agregar al menos un item', Colors.orange);
      return;
    }
    setState(() => _cargando = true);

    final url = Uri.parse('$_baseUrl/editar_contrato.php');
    final data = {'id': _editandoId, ..._buildPayload()};

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );
      final res = jsonDecode(response.body);

      if (response.statusCode == 200 && res['success'] == true) {
        _limpiarFormulario();
        _snack('✅ Contrato actualizado correctamente', Colors.green);
        await _cargarContratos();
        if (mounted) setState(() => _mostrandoLista = true);
      } else {
        _snack('❌ ${res['message'] ?? 'Error al actualizar'}', Colors.red);
      }
    } catch (e) {
      _snack('❌ Error de conexión: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarContrato(int id, String numero) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Contrato'),
        content: Text(
          '¿Seguro que deseas eliminar el contrato #$numero?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => _cargando = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/eliminar_contrato.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      );
      final res = jsonDecode(response.body);

      if (response.statusCode == 200 && res['success'] == true) {
        _snack('✅ Contrato eliminado correctamente', Colors.green);
        await _cargarContratos();
      } else {
        _snack('❌ ${res['message'] ?? 'Error al eliminar'}', Colors.red);
      }
    } catch (e) {
      _snack('❌ Error de conexión: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarContratos() async {
    setState(() => _cargando = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/listar_contrato.php'),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _contratos = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _contratosFiltrados = List.from(_contratos);
        });
      }
    } catch (e) {
      debugPrint('Error cargando contratos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    final valorTotalTexto = _valorTotalController.text.replaceAll('.', '');

    return {
      'numero_contrato': _numeroController.text.trim(),
      'objeto_contrato': _objetoController.text.trim(),
      'proveedor': _proveedorController.text.trim(),
      'fecha_inicio': _fechaInicioController.text.trim(),
      'fecha_fin': _fechaFinController.text.trim(),
      'valor_total': double.tryParse(valorTotalTexto) ?? 0,
      'estado': _estadoSeleccionado,
      'tipo_contrato': _tipoContrato,
      'modalidad_seleccion': _modalidadSeleccion,
      'items': _items
          .map(
            (item) => {
              'codigo': item['codigo'],
              'nombre': item['nombre'],
              'descripcion': item['descripcion'],
              'unidad': item['unidad'],
              'cantidad': item['cantidad'],
              'valor_unitario': item['valor_unitario'],
            },
          )
          .toList(),
    };
  }

  void _limpiarFormulario() {
    _proveedorController.clear();
    _numeroController.clear();
    _objetoController.clear();
    _valorTotalController.clear();
    _fechaInicioController.clear();
    _fechaFinController.clear();
    _items.clear();
    _editandoId = null;
    setState(() {
      _estadoSeleccionado = 'EN EJECUCIÓN';
      _tipoContrato = 'Contrato de obra';
      _modalidadSeleccion = 'Contratación directa';
    });
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
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

  Future<void> _pickDate(TextEditingController ctrl) async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (fecha != null) ctrl.text = fecha.toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    _proveedorController.dispose();
    _numeroController.dispose();
    _objetoController.dispose();
    _valorTotalController.dispose();
    _fechaInicioController.dispose();
    _fechaFinController.dispose();
    _itemCodigoController.dispose();
    _itemNombreController.dispose();
    _itemDescripcionController.dispose();
    _itemUnidadController.dispose();
    _itemCantidadController.dispose();
    _itemValorUnitarioController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF2E7D32);
    final bool modoEdicion = _editandoId != null;

    return Scaffold(
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 2,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 192, 231, 195),
              border: Border(bottom: BorderSide(color: verde, width: 4)),
            ),
            child: Row(
              children: [
                Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: verde, size: 30),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/logos/banner_gobernacion.png',
                  height: 110,
                  fit: BoxFit.contain,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      modoEdicion ? 'Editar Contrato' : 'Registrar Contratos',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                  ),
                ),
                if (!modoEdicion)
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _mostrandoLista = !_mostrandoLista);
                        if (_mostrandoLista) _cargarContratos();
                      },
                      icon: Icon(
                        _mostrandoLista ? Icons.add : Icons.list,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        _mostrandoLista ? 'Nuevo' : 'Ver Listado',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mostrandoLista
                            ? verde
                            : Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),
                if (modoEdicion)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 28),
                    onPressed: () {
                      _limpiarFormulario();
                      setState(() => _mostrandoLista = true);
                    },
                    tooltip: 'Cancelar edición',
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.green.shade50, Colors.white],
                ),
              ),
              child: _mostrandoLista
                  ? _buildListaContratos(verde)
                  : Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1000),
                          child: Form(
                            key: _formKey,
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (modoEdicion)
                                      Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange.shade300,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit,
                                              color: Colors.orange.shade700,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Editando contrato #${_numeroController.text}',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    _buildSeccionDatos(verde),
                                    const SizedBox(height: 24),
                                    _buildSeccionItems(verde),
                                    const SizedBox(height: 20),
                                    _buildBotones(verde, modoEdicion),
                                  ],
                                ),
                              ),
                            ),
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

  Widget _buildSeccionDatos(Color verde) {
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
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _proveedorController,
                decoration: _deco('Proveedor *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese el proveedor'
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _numeroController,
                decoration: _deco(
                  'Número del Contrato *',
                  hint: 'Ej: 001-2026',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese el número'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _fechaInicioController,
                decoration: _deco('Fecha Inicio *', hint: 'YYYY-MM-DD'),
                readOnly: true,
                onTap: () => _pickDate(_fechaInicioController),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese fecha inicio'
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _fechaFinController,
                decoration: _deco('Fecha Fin *', hint: 'YYYY-MM-DD'),
                readOnly: true,
                onTap: () => _pickDate(_fechaFinController),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese fecha fin'
                    : null,
              ),
            ),
          ],
        ),

        // ✅ NUEVOS CAMPOS ANTES DE OBJETO
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _tipoContrato,
                decoration: _deco('Tipo de Contrato *'),
                isDense: true,
                items:
                    const [
                          'Contrato de obra',
                          'Contrato de prestación de servicios',
                          'Contrato de consultoría',
                          'Contrato de suministro',
                          'Contrato de interventoría',
                          'Contrato de compraventa',
                          'Contrato de arrendamiento',
                        ]
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (val) => setState(() => _tipoContrato = val!),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _modalidadSeleccion,
                decoration: _deco('Modalidad de Selección *'),
                isDense: true,
                items:
                    const [
                          'Mínima Cuantía',
                          'Menor Cuantía',
                          'Contratación directa',
                          'Licitación pública',
                          'Subasta Inversa',
                          'Concurso de méritos',
                        ]
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (val) => setState(() => _modalidadSeleccion = val!),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),
        TextFormField(
          controller: _objetoController,
          maxLines: 2,
          decoration: _deco('Objeto del Contrato *', alignLabel: true),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Ingrese el objeto' : null,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _valorTotalController,
                decoration: _deco('Valor Total *', prefix: '\$ '),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final valorLimpio = (v ?? '').replaceAll('.', '');
                  return (valorLimpio.isEmpty ||
                          double.tryParse(valorLimpio) == null)
                      ? 'Ingrese el valor total'
                      : null;
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _estadoSeleccionado,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    items: const [
                      DropdownMenuItem(
                        value: 'EN EJECUCIÓN',
                        child: Text('EN EJECUCIÓN'),
                      ),
                      DropdownMenuItem(
                        value: 'FINALIZADO',
                        child: Text('FINALIZADO'),
                      ),
                      DropdownMenuItem(
                        value: 'SUSPENDIDO',
                        child: Text('SUSPENDIDO'),
                      ),
                      DropdownMenuItem(
                        value: 'CANCELADO',
                        child: Text('CANCELADO'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _estadoSeleccionado = v!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeccionItems(Color verde) {
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
                color: verde.withOpacity(0.1),
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
        _items.isEmpty
            ? Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox, size: 40, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text(
                      'Sin items',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 10,
                    headingRowHeight: 36,
                    dataRowMinHeight: 38,
                    headingRowColor: WidgetStateProperty.all(
                      Colors.green.shade50,
                    ),
                    columns:
                        [
                              '#',
                              'Código',
                              'Nombre',
                              'Descripción',
                              'Unidad',
                              'Cant.',
                              'V. Unit.',
                              'Subtotal',
                              '',
                            ]
                            .map(
                              (l) => DataColumn(
                                label: Text(
                                  l,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: verde,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                    rows: _items.asMap().entries.map((e) {
                      final i = e.key;
                      final item = e.value;
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '${i + 1}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['codigo'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['nombre'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['descripcion'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              item['unidad'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              _formatearConPuntos(item['cantidad']),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              '\$${_formatearConPuntos(item['valor_unitario'])}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              '\$${_formatearConPuntos(item['subtotal'])}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: verde,
                              ),
                            ),
                          ),
                          DataCell(
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade400,
                                size: 18,
                              ),
                              onPressed: () => _eliminarItem(i),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_circle, color: verde, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Agregar Item',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: verde,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _itemCodigoController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Código',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        isDense: true,
                        errorStyle: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (!RegExp(r'^\d+$').hasMatch(value)) {
                          return 'solo caracteres numéricos';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        final soloNumeros = value.replaceAll(
                          RegExp(r'[^\d]'),
                          '',
                        );
                        if (soloNumeros != value) {
                          _itemCodigoController.text = soloNumeros;
                          _itemCodigoController.selection =
                              TextSelection.collapsed(
                                offset: soloNumeros.length,
                              );
                          _snack('solo caracteres numéricos', Colors.orange);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _itemField(_itemNombreController, 'Nombre *'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _itemField(
                      _itemDescripcionController,
                      'Descripción',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: _itemField(_itemUnidadController, 'Unidad'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _itemField(
                      _itemCantidadController,
                      'Cantidad *',
                      kb: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _itemValorUnitarioController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Valor Unitario *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _agregarItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.add, size: 18),
                          SizedBox(width: 4),
                          Text('Agregar', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBotones(Color verde, bool modoEdicion) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _cargando
                ? null
                : (modoEdicion ? _guardarEdicion : _registrarContrato),
            style: ElevatedButton.styleFrom(
              backgroundColor: modoEdicion ? Colors.orange.shade700 : verde,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _cargando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    modoEdicion ? 'GUARDAR CAMBIOS' : 'REGISTRAR CONTRATO',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildListaContratos(Color verde) {
    final listaMostrar = _searchQuery.isEmpty
        ? _contratos
        : _contratosFiltrados;
    final bool esAdmin = rol == 'administrador';

    if (_contratos.isEmpty && !_cargando) {
      return Center(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox, size: 56, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No hay contratos registrados',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _mostrandoLista = false),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nuevo Contrato'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarContratos,
      color: verde,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: ' Buscar por proveedor o codigo de contrato',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: verde, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _filtrarContratos();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _filtrarContratos(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  'Total: ${listaMostrar.length} contratos',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (_cargando)
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: verde,
                    ),
                  ),
              ],
            ),
          ),
          ...listaMostrar.map((contrato) {
            final estado = contrato['estado'] ?? '';
            final items = contrato['items'] as List? ?? [];
            final id = contrato['id'] is int
                ? contrato['id'] as int
                : int.tryParse(contrato['id'].toString()) ?? 0;
            final numero = contrato['numero_contrato'] ?? 'N/A';
            final valorTotal =
                double.tryParse(contrato['valor_total']?.toString() ?? '0') ??
                0;

            return InkWell(
              onTap: () => _mostrarVistaPrevia(contrato),
              borderRadius: BorderRadius.circular(10),
              child: Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: verde.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#$numero',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: verde,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _getEstadoColor(estado).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              estado,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getEstadoColor(estado),
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            tooltip: 'Editar contrato',
                            onPressed: () {
                              _prepararEdicion(contrato);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          if (esAdmin) ...[
                            const SizedBox(width: 2),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade400,
                                size: 20,
                              ),
                              tooltip: 'Eliminar contrato',
                              onPressed: () {
                                _eliminarContrato(id, numero);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        contrato['proveedor'] ?? 'Sin proveedor',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        contrato['objeto_contrato'] ?? 'Sin objeto',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
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
                          const SizedBox(width: 8),
                          Text(
                            contrato['fecha_inicio'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.shopping_bag,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${items.length} items',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  InputDecoration _deco(
    String label, {
    String? hint,
    String? prefix,
    bool alignLabel = false,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    isDense: true,
    alignLabelWithHint: alignLabel,
  );

  Widget _itemField(
    TextEditingController ctrl,
    String label, {
    TextInputType? kb,
  }) => TextField(
    controller: ctrl,
    keyboardType: kb,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      isDense: true,
    ),
  );
}
