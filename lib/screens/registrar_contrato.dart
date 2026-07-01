import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/drawer_menu.dart';
import '../services/storage_service.dart';

class RegistrarContratoPage extends StatefulWidget {
  const RegistrarContratoPage({super.key});

  @override
  State<RegistrarContratoPage> createState() => _RegistrarContratoPageState();
}

class _RegistrarContratoPageState extends State<RegistrarContratoPage> {
  // ✅ FIX: GlobalKey como campo de clase (no dentro de build), está bien aquí
  // pero usamos Builder para el drawer igual que en MenuNavegacion
  late String username;
  late String sector;
  late String rol;

  // ============================================
  // CONTROLADORES DEL FORMULARIO
  // ============================================
  final _formKey = GlobalKey<FormState>();
  final _proveedorController = TextEditingController();
  final _numeroController = TextEditingController();
  final _objetoController = TextEditingController();
  final _valorTotalController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final _fechaFinController = TextEditingController();

  // ✅ FIX: estados en MAYÚSCULAS para coincidir con el PHP y la BD
  String _estadoSeleccionado = 'EN EJECUCIÓN';

  // ============================================
  // VARIABLES PARA ITEMS
  // ============================================
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

  // ============================================
  // URL BASE — cambia localhost por tu IP si
  // pruebas en dispositivo físico (ej: 192.168.x.x)
  // ============================================
  static const String _baseUrl = 'http://localhost/samde_db/api/contratos';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Object? argumentosRaw = ModalRoute.of(context)!.settings.arguments;
    final Map<String, dynamic> argumentos =
        (argumentosRaw is Map<String, dynamic>) ? argumentosRaw : {};

    username = argumentos['username'] ?? 'Usuario';
    sector = argumentos['sector'] ?? 'No Asignado';
    rol = argumentos['rol'] ?? 'consulta';
  }

  @override
  void initState() {
    super.initState();
    _cargarContratos();
  }

  // ============================================
  // AGREGAR ITEM
  // ============================================
  void _agregarItem() {
    if (_itemNombreController.text.isEmpty ||
        _itemCantidadController.text.isEmpty ||
        _itemValorUnitarioController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre, cantidad y valor unitario son obligatorios'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final double cantidad = double.tryParse(_itemCantidadController.text) ?? 0;
    final double valorUnitario =
        double.tryParse(_itemValorUnitarioController.text) ?? 0;

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
        'cantidad': cantidad,
        'valor_unitario': valorUnitario,
        'subtotal': cantidad * valorUnitario,
      });

      _itemCodigoController.clear();
      _itemNombreController.clear();
      _itemDescripcionController.clear();
      _itemUnidadController.clear();
      _itemCantidadController.clear();
      _itemValorUnitarioController.clear();
    });
  }

  void _eliminarItem(int index) {
    setState(() => _items.removeAt(index));
  }

  // ============================================
  // REGISTRAR CONTRATO
  // ============================================
  Future<void> _registrarContrato() async {
    if (!_formKey.currentState!.validate()) return;

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes agregar al menos un item al contrato'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    final url = Uri.parse('$_baseUrl/registrar_contrato.php');

    try {
      final Map<String, dynamic> data = {
        'numero_contrato': _numeroController.text.trim(),
        'objeto_contrato': _objetoController.text.trim(),
        'proveedor': _proveedorController.text.trim(),
        'fecha_inicio': _fechaInicioController.text.trim(),
        'fecha_fin': _fechaFinController.text.trim(),
        // ✅ FIX: enviar como número, no como string
        'valor_total': double.tryParse(_valorTotalController.text.trim()) ?? 0,
        'estado': _estadoSeleccionado,
        'items': _items.map((item) {
          return {
            'codigo': item['codigo'] ?? '',
            'nombre': item['nombre'] ?? '',
            'descripcion': item['descripcion'] ?? '',
            'unidad': item['unidad'] ?? 'Unidad',
            // ✅ FIX: enviar como número, no como string
            'cantidad': item['cantidad'],
            'valor_unitario': item['valor_unitario'],
          };
        }).toList(),
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(data),
      );

      final responseData = jsonDecode(response.body);

      // ✅ FIX: PHP devuelve {'success': true}, no {'status': 'success'}
      if (response.statusCode == 201 && responseData['success'] == true) {
        _limpiarFormulario();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Contrato registrado exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          await _cargarContratos();
          setState(() => _mostrandoLista = true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ ${responseData['message'] ?? 'Error al registrar contrato'}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ============================================
  // CARGAR CONTRATOS
  // ============================================
  Future<void> _cargarContratos() async {
    setState(() => _cargando = true);

    final url = Uri.parse('$_baseUrl/listar_contrato.php');

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      // ✅ FIX: PHP devuelve {'success': true}, no {'status': 'success'}
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _contratos = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      } else {
        debugPrint('Error al cargar contratos: ${data['message']}');
      }
    } catch (e) {
      debugPrint('Error cargando contratos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ============================================
  // CAMBIAR ESTADO DEL CONTRATO
  // ============================================
  Future<void> _cambiarEstadoContrato(
    int contratoId,
    String nuevoEstado,
  ) async {
    setState(() => _cargando = true);

    final url = Uri.parse('$_baseUrl/estado_contrato.php');

    try {
      // ✅ FIX: era http.patch — el PHP solo acepta POST
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': contratoId, 'estado': nuevoEstado}),
      );

      final data = jsonDecode(response.body);

      // ✅ FIX: PHP devuelve {'success': true}
      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Estado actualizado a: $nuevoEstado'),
              backgroundColor: Colors.green,
            ),
          );
          await _cargarContratos();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '❌ ${data['message'] ?? 'Error al actualizar estado'}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ============================================
  // LIMPIAR FORMULARIO
  // ============================================
  void _limpiarFormulario() {
    _proveedorController.clear();
    _numeroController.clear();
    _objetoController.clear();
    _valorTotalController.clear();
    _fechaInicioController.clear();
    _fechaFinController.clear();
    _items.clear();
    setState(() => _estadoSeleccionado = 'EN EJECUCIÓN');
  }

  // ============================================
  // CIERRE DE SESIÓN
  // ============================================
  void _confirmarCerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final storage = StorageService();
                await storage.cerrarSesion();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  Navigator.pushReplacementNamed(dialogContext, '/');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);

    return Scaffold(
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 2,
      ),
      body: Column(
        children: [
          // ============================================
          // BANNER INSTITUCIONAL
          // ============================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 192, 231, 195),
              border: Border(
                bottom: BorderSide(color: verdeInstitucional, width: 4),
              ),
            ),
            child: Row(
              children: [
                // ✅ FIX: Builder para abrir drawer sin GlobalKey
                Builder(
                  builder: (innerContext) => IconButton(
                    icon: const Icon(
                      Icons.menu,
                      color: verdeInstitucional,
                      size: 30,
                    ),
                    onPressed: () => Scaffold.of(innerContext).openDrawer(),
                    tooltip: 'Abrir menú',
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
                const Expanded(
                  child: Center(
                    child: Text(
                      'Registrar Contratos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _mostrandoLista ? Icons.add : Icons.list,
                    color: verdeInstitucional,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() => _mostrandoLista = !_mostrandoLista);
                    if (_mostrandoLista) _cargarContratos();
                  },
                  tooltip: _mostrandoLista ? 'Nuevo registro' : 'Ver listado',
                ),
              ],
            ),
          ),

          // ============================================
          // CONTENIDO
          // ============================================
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
                  ? _buildListaContratos()
                  : Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
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
                                    _buildSeccionDatosContrato(
                                      verdeInstitucional,
                                    ),
                                    const SizedBox(height: 24),
                                    _buildSeccionItems(verdeInstitucional),
                                    const SizedBox(height: 20),
                                    _buildBotones(verdeInstitucional),
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

  // ============================================
  // SECCIÓN 1: DATOS DEL CONTRATO
  // ============================================
  Widget _buildSeccionDatosContrato(Color verde) {
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

        TextFormField(
          controller: _proveedorController,
          decoration: _inputDeco('Proveedor *'),
          style: const TextStyle(fontSize: 14),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Ingrese el proveedor' : null,
        ),
        const SizedBox(height: 14),

        TextFormField(
          controller: _numeroController,
          decoration: _inputDeco('Número del Contrato *', hint: 'Ej: 001-2026'),
          style: const TextStyle(fontSize: 14),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Ingrese el número del contrato'
              : null,
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _fechaInicioController,
                decoration: _inputDeco('Fecha Inicio *', hint: 'YYYY-MM-DD'),
                style: const TextStyle(fontSize: 14),
                // ✅ Selector de fecha para evitar errores de formato
                readOnly: true,
                onTap: () async {
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (fecha != null) {
                    _fechaInicioController.text = fecha
                        .toIso8601String()
                        .substring(0, 10);
                  }
                },
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese fecha inicio'
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextFormField(
                controller: _fechaFinController,
                decoration: _inputDeco('Fecha Fin *', hint: 'YYYY-MM-DD'),
                style: const TextStyle(fontSize: 14),
                readOnly: true,
                onTap: () async {
                  final fecha = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (fecha != null) {
                    _fechaFinController.text = fecha
                        .toIso8601String()
                        .substring(0, 10);
                  }
                },
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese fecha fin'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        TextFormField(
          controller: _objetoController,
          maxLines: 2,
          decoration: _inputDeco('Objeto del Contrato *', alignLabel: true),
          style: const TextStyle(fontSize: 14),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Ingrese el objeto' : null,
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _valorTotalController,
                decoration: _inputDeco('Valor Total *', prefix: '\$ '),
                style: const TextStyle(fontSize: 14),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese el valor total'
                    : null,
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
                    // ✅ FIX: valores en MAYÚSCULAS, igual que la BD
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
                    onChanged: (value) =>
                        setState(() => _estadoSeleccionado = value!),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================
  // SECCIÓN 2: ITEMS
  // ============================================
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
                    Text(
                      'Agrega items usando el formulario inferior',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
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
                    headingRowColor: MaterialStateProperty.all(
                      Colors.green.shade50,
                    ),
                    columns: [
                      _buildDataColumn('#', verde),
                      _buildDataColumn('Código', verde),
                      _buildDataColumn('Nombre', verde),
                      _buildDataColumn('Descripción', verde),
                      _buildDataColumn('Unidad', verde),
                      _buildDataColumn('Cant.', verde),
                      _buildDataColumn('V. Unit.', verde),
                      _buildDataColumn('Subtotal', verde),
                      _buildDataColumn('', verde),
                    ],
                    rows: _items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '${index + 1}',
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
                              item['cantidad'].toString(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              '\$${(item['valor_unitario'] as double).toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          DataCell(
                            Text(
                              '\$${(item['subtotal'] as double).toStringAsFixed(0)}',
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
                              onPressed: () => _eliminarItem(index),
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

        // Formulario agregar item
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
                    child: _buildItemField(
                      controller: _itemCodigoController,
                      label: 'Código',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildItemField(
                      controller: _itemNombreController,
                      label: 'Nombre *',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildItemField(
                      controller: _itemDescripcionController,
                      label: 'Descripción',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: _buildItemField(
                      controller: _itemUnidadController,
                      label: 'Unidad',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildItemField(
                      controller: _itemCantidadController,
                      label: 'Cantidad *',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildItemField(
                      controller: _itemValorUnitarioController,
                      label: 'Valor Unitario *',
                      keyboardType: TextInputType.number,
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

  // ============================================
  // WIDGETS REUTILIZABLES
  // ============================================
  InputDecoration _inputDeco(
    String label, {
    String? hint,
    String? prefix,
    bool alignLabel = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      isDense: true,
      alignLabelWithHint: alignLabel,
    );
  }

  DataColumn _buildDataColumn(String label, Color verde) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: verde,
        ),
      ),
    );
  }

  Widget _buildItemField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        isDense: true,
      ),
    );
  }

  // ============================================
  // BOTONES DE ACCIÓN
  // ============================================
  Widget _buildBotones(Color verde) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _cargando ? null : _registrarContrato,
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
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
                : const Text(
                    'REGISTRAR CONTRATO',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(
                context,
                '/menu',
                arguments: {'username': username, 'sector': sector, 'rol': rol},
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade400),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Volver al Menú Principal',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // LISTA DE CONTRATOS
  // ============================================
  Widget _buildListaContratos() {
    const Color verde = Color(0xFF2E7D32);

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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Total: ${_contratos.length} contratos',
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
                      color: verde,
                    ),
                  ),
              ],
            ),
          ),
          ..._contratos.map((contrato) {
            final estado = contrato['estado'] ?? '';
            final estadoColor = _getEstadoColor(estado);
            final items = contrato['items'] as List? ?? [];

            return Card(
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
                            '#${contrato['numero_contrato'] ?? 'N/A'}',
                            style: const TextStyle(
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
                            color: estadoColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            estado,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: estadoColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          contrato['fecha_inicio'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
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
                        const Text(
                          '\$',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: verde,
                          ),
                        ),
                        Text(
                          '${contrato['valor_total'] ?? '0'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: verde,
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
            );
          }),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () => setState(() => _mostrandoLista = false),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Volver al Formulario',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIX: maneja mayúsculas que devuelve la BD
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
}
