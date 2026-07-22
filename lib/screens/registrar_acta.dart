import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/drawer_menu.dart';

class RegistrarActaPage extends StatefulWidget {
  const RegistrarActaPage({super.key});

  @override
  State<RegistrarActaPage> createState() => _RegistrarActaPageState();
}

class _RegistrarActaPageState extends State<RegistrarActaPage> {
  late String username;
  late int usuarioId;
  late String sector;
  late String rol;

  final _formKey = GlobalKey<FormState>();
  final _numeroActaController = TextEditingController();
  final _fechaController = TextEditingController();
  final _entregadoAController = TextEditingController();

  String? _areaSeleccionada;
  final List<String> _areasDisponibles = [
    'Desarrollo economico',
    'Medio ambiente',
    'Agropecuario',
  ];

  final _docIdentController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _nombreEntregoCtrl = TextEditingController();
  final _cargoEntregoCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  List<Map<String, dynamic>> _todosItemsDisponibles = [];
  List<TextEditingController> _cantidadControllers = [];
  PlatformFile? _archivoSeleccionado;

  bool _cargando = false;
  bool _mostrandoLista = false;

  List<Map<String, dynamic>> _actas = [];
  final _busquedaController = TextEditingController();
  String _filtroBusqueda = '';
  List<Map<String, dynamic>> _actasFiltradas = [];

  List<bool> _erroresCantidad = [];

  static const String _baseUrl = 'http://localhost/samde_db/api';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
    username = map['username'] ?? 'Usuario';
    usuarioId = map['usuario_id'] ?? 1;
    sector = map['sector'] ?? 'No Asignado';
    rol = map['rol'] ?? 'consulta';
  }

  @override
  void initState() {
    super.initState();
    _cargarItemsDisponibles();
    _cargarActas();
    // CORRECCIÓN 1: Cargar el estado guardado al iniciar
    _cargarEstadoGuardado();
  }

  // CORRECCIÓN 2: Función para cargar el estado desde SharedPreferences
  Future<void> _cargarEstadoGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final mostrandoListaGuardado = prefs.getBool('mostrando_lista') ?? false;
    setState(() {
      _mostrandoLista = mostrandoListaGuardado;
    });
  }

  // CORRECCIÓN 3: Función para guardar el estado
  Future<void> _guardarEstado(bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mostrando_lista', valor);
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  String _formatNum(dynamic v) {
    final n = _toDouble(v);
    return n == n.truncateToDouble()
        ? n.truncate().toString()
        : n.toStringAsFixed(2);
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  InputDecoration _deco(
    String label, {
    String? hint,
    bool obligatorio = false,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    isDense: true,
    suffixText: obligatorio ? '*' : null,
    suffixStyle: const TextStyle(
      color: Colors.red,
      fontWeight: FontWeight.bold,
    ),
  );

  Future<void> _pickDate() async {
    final f = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (f != null) _fechaController.text = f.toIso8601String().substring(0, 10);
  }

  Future<void> _cargarItemsDisponibles() async {
    setState(() => _cargando = true);
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/items/obtener_items_disponibles.php'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        setState(() {
          _todosItemsDisponibles = List<Map<String, dynamic>>.from(
            data['data'] ?? [],
          );
          _erroresCantidad = List<bool>.filled(
            _todosItemsDisponibles.length,
            false,
          );
        });
        _inicializarControllers();
      }
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _inicializarControllers() {
    for (final c in _cantidadControllers) c.dispose();
    _cantidadControllers = _todosItemsDisponibles
        .map((_) => TextEditingController())
        .toList();
  }

  void _validarCantidad(int index, String valor) {
    final item = _todosItemsDisponibles[index];
    final disponible = _toDouble(item['cantidad_disponible']);
    final cantidadIngresada = _toDouble(valor);

    setState(() {
      if (cantidadIngresada > disponible) {
        _erroresCantidad[index] = true;
      } else {
        _erroresCantidad[index] = false;
      }
    });
  }

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _archivoSeleccionado = result.files.first);
    }
  }

  Future<void> _registrarActa() async {
    if (!_formKey.currentState!.validate()) return;

    // CORRECCIÓN 4: Validar que se haya seleccionado un archivo
    if (_archivoSeleccionado == null) {
      _snack('⚠️ Debe seleccionar el archivo del acta', Colors.red);
      return;
    }

    if (_erroresCantidad.contains(true)) {
      _snack(
        '️ Hay items con cantidad superior al stock disponible',
        Colors.red,
      );
      return;
    }

    final itemsConCantidad = <Map<String, dynamic>>[];
    for (int i = 0; i < _todosItemsDisponibles.length; i++) {
      final cantidad = _toDouble(_cantidadControllers[i].text);
      if (cantidad > 0) {
        final item = _todosItemsDisponibles[i];
        if (item['id_egreso'] == null) {
          _snack('Item "${item['nombre_items']}" sin egreso', Colors.red);
          return;
        }
        final disponible = _toDouble(item['cantidad_disponible']);
        if (cantidad > disponible) {
          _snack('Stock insuficiente: ${item['nombre_items']}', Colors.red);
          return;
        }
        itemsConCantidad.add({
          'id_item': item['id'],
          'id_egreso': item['id_egreso'],
          'cantidad_entregada': cantidad,
          'nombre_item': item['nombre_items'],
        });
      }
    }

    if (itemsConCantidad.isEmpty) {
      _snack('Ingrese al menos un item', Colors.orange);
      return;
    }

    setState(() => _cargando = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/actas/registrar_acta.php'),
      );
      request.fields['numero_acta'] = _numeroActaController.text.trim();
      request.fields['fecha_entrega'] = _fechaController.text.trim();
      request.fields['entregado_a'] = _entregadoAController.text.trim();
      request.fields['area_dependencia'] = _areaSeleccionada?.trim() ?? '';
      request.fields['documento_identidad'] = _docIdentController.text.trim();
      request.fields['telefono'] = _telefonoController.text.trim();
      request.fields['nombre_entrego'] = _nombreEntregoCtrl.text.trim();
      request.fields['cargo_entrego'] = _cargoEntregoCtrl.text.trim();
      request.fields['observaciones'] = _observacionesCtrl.text.trim();
      request.fields['usuario_registro'] = usuarioId.toString();
      request.fields['detalles'] = jsonEncode(itemsConCantidad);

      if (_archivoSeleccionado != null && _archivoSeleccionado!.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'archivo',
            _archivoSeleccionado!.bytes!,
            filename: _archivoSeleccionado!.name,
          ),
        );
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final body = await streamed.stream.bytesToString();
      final data = jsonDecode(body);

      if (streamed.statusCode == 201 && data['success'] == true) {
        _limpiarFormulario();
        _snack('✅ Acta registrada', Colors.green);
        await _cargarItemsDisponibles();
        await _cargarActas();
        setState(() => _mostrandoLista = true);
        _guardarEstado(true);
      } else {
        final mensaje = data['message'] ?? 'Error';
        if (mensaje.contains('Stock insuficiente')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('⚠️ Stock Actualizado'),
              content: Text(mensaje),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _cargarItemsDisponibles();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recargar'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ],
            ),
          );
        } else {
          _snack('❌ $mensaje', Colors.red);
        }
      }
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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

  void _limpiarFormulario() {
    _numeroActaController.clear();
    _fechaController.clear();
    _entregadoAController.clear();
    setState(() {
      _areaSeleccionada = null;
    });
    _docIdentController.clear();
    _telefonoController.clear();
    _nombreEntregoCtrl.clear();
    _cargoEntregoCtrl.clear();
    _observacionesCtrl.clear();
    for (final c in _cantidadControllers) c.dispose();
    _cantidadControllers = [];
    _erroresCantidad = [];
    setState(() => _archivoSeleccionado = null);
  }

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF2E7D32);

    return Scaffold(
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 1,
      ),
      body: Column(
        children: [
          Container(
            height: 130,
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
                const Expanded(
                  child: Center(
                    child: Text(
                      'Actas de Entrega',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: verde,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _mostrandoLista ? Icons.add : Icons.list,
                    color: verde,
                    size: 28,
                  ),
                  onPressed: () {
                    setState(() => _mostrandoLista = !_mostrandoLista);
                    _guardarEstado(
                      _mostrandoLista,
                    ); // CORRECCIÓN 5: Guardar estado
                    if (_mostrandoLista) _cargarActas();
                  },
                  tooltip: _mostrandoLista ? 'Nueva acta' : 'Ver listado',
                ),
              ],
            ),
          ),
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
              child: _mostrandoLista
                  ? _buildLista(verde)
                  : _buildFormulario(verde),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulario(Color verde) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment, color: verde, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Datos del Acta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: verde,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _numeroActaController,
                            decoration: _deco(
                              'Número del Acta',
                              obligatorio: true,
                            ),
                            validator: (v) => v!.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _fechaController,
                            decoration: _deco(
                              'Fecha de Entrega',
                              obligatorio: true,
                            ),
                            readOnly: true,
                            onTap: _pickDate,
                            validator: (v) => v!.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _entregadoAController,
                            decoration: _deco('Entregado a', obligatorio: true),
                            validator: (v) => v!.isEmpty ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _areaSeleccionada,
                            decoration: _deco(
                              'Área / Dependencia',
                              obligatorio: true,
                            ),
                            items: _areasDisponibles.map((String area) {
                              return DropdownMenuItem<String>(
                                value: area,
                                child: Text(area),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _areaSeleccionada = newValue;
                              });
                            },
                            validator: (value) => value == null || value.isEmpty
                                ? 'Requerido'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _docIdentController,
                            decoration: _deco('Documento de Identidad'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _telefonoController,
                            decoration: _deco('Teléfono'),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nombreEntregoCtrl,
                            decoration: _deco('Nombre quien entregó'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _cargoEntregoCtrl,
                            decoration: _deco('Cargo'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _observacionesCtrl,
                      decoration: _deco('Observaciones'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Icon(Icons.table_view, color: verde, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Items a Entregar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: verde,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.green),
                          onPressed: _cargarItemsDisponibles,
                          tooltip: 'Actualizar stock',
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    _buildTablaItems(),
                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Icon(Icons.attach_file, color: verde, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Archivo del Acta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: verde,
                          ),
                        ),
                        const Text(
                          ' *',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    InkWell(
                      onTap: _seleccionarArchivo,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _archivoSeleccionado != null
                              ? Colors.green.shade50
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _archivoSeleccionado != null
                                ? Colors.green.shade300
                                : Colors
                                      .green
                                      .shade300, // CORRECCIÓN 6: Borde rojo si no hay archivo
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _archivoSeleccionado != null
                                  ? Icons.check_circle
                                  : Icons.upload_file,
                              color: _archivoSeleccionado != null
                                  ? Colors.green.shade600
                                  : Colors.red.shade500,
                              size: 32,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _archivoSeleccionado != null
                                        ? _archivoSeleccionado!.name
                                        : 'Toca para subir el archivo del acta',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _archivoSeleccionado != null
                                          ? Colors.green.shade700
                                          : Colors.green.shade600,
                                    ),
                                  ),
                                  Text(
                                    'PDF, JPG o PNG (Máx. 10MB) *',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_archivoSeleccionado != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    setState(() => _archivoSeleccionado = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _cargando ? null : _registrarActa,
                        icon: _cargando
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save, size: 20),
                        label: _cargando
                            ? const Text('Guardando...')
                            : const Text(
                                'GUARDAR REGISTRO',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: verde,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _limpiarFormulario,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Limpiar Formulario',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTablaItems() {
    if (_todosItemsDisponibles.isEmpty && !_cargando) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No hay items disponibles con stock',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_cargando) {
      return Container(
        padding: const EdgeInsets.all(60),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.table_view_rounded,
                  color: Colors.green.shade800,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Items a Entregar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade200.withOpacity(0.6),
              border: Border(bottom: BorderSide(color: Colors.green.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Nombre Item',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Contrato',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Cant. Contratada',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Cant. Egresada',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Cant. Disponible',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                      fontSize: 11,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Cant. a Entregar *',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),

          ..._todosItemsDisponibles.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final disponible = _toDouble(item['cantidad_disponible']);
            final contratada = _toDouble(item['cantidad_contratada']);
            final egresada = _toDouble(item['cantidad_total_egresada']);
            final tieneStock = disponible > 0;
            final hayError = i < _erroresCantidad.length && _erroresCantidad[i];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.green.shade200),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['nombre_items'] ?? 'Sin nombre',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        item['numero_contrato'] ?? 'N/A',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _formatNum(contratada),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.orange.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _formatNum(egresada),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _formatNum(disponible),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: hayError
                              ? Colors.red.shade500
                              : (tieneStock
                                    ? Colors.green.shade400
                                    : Colors.grey.shade300),
                          width: hayError ? 2.5 : 2,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color: hayError ? Colors.red.shade50 : Colors.white,
                      ),
                      child: TextField(
                        controller: _cantidadControllers.length > i
                            ? _cantidadControllers[i]
                            : TextEditingController(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        enabled: tieneStock,
                        onChanged: (valor) => _validarCantidad(i, valor),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: hayError
                              ? Colors.red.shade700
                              : (tieneStock
                                    ? Colors.green.shade700
                                    : Colors.grey.shade400),
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          suffixIcon: hayError
                              ? Icon(
                                  Icons.warning,
                                  color: Colors.red.shade600,
                                  size: 18,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
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
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 900,
          constraints: const BoxConstraints(maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoSection('Información General', [
                        _buildInfoRow(
                          'Entregado a:',
                          acta['entregado_a'] ?? 'N/A',
                        ),
                        _buildInfoRow(
                          'Área / Dependencia:',
                          acta['area_dependencia'] ?? 'N/A',
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

                      if (acta['nombre_entrego'] != null &&
                          acta['nombre_entrego'].toString().isNotEmpty)
                        _buildInfoSection('Quien Entregó', [
                          _buildInfoRow('Nombre:', acta['nombre_entrego']),
                          _buildInfoRow(
                            'Cargo:',
                            acta['cargo_entrego'] ?? 'N/A',
                          ),
                        ]),
                      const SizedBox(height: 20),

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
                              IconButton(
                                icon: const Icon(
                                  Icons.download,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  _snack('Descargando archivo...', Colors.blue);
                                },
                              ),
                            ],
                          ),
                        ]),
                      const SizedBox(height: 24),

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
                                final index = entry.key;
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
                                          item['numero_contrato'] ?? 'N/A',
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
                              }).toList(),

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
                          _snack('Imprimiendo acta...', Colors.green);
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
                SizedBox(height: 24),
                Icon(Icons.arrow_upward, color: Colors.green),
                SizedBox(height: 8),
                Text(
                  'Crea una nueva acta',
                  style: TextStyle(color: Colors.grey),
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
                    onTap: () => _verDetalleActa(acta),
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
                                'Área: ${acta['area_dependencia'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
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
    _numeroActaController.dispose();
    _fechaController.dispose();
    _entregadoAController.dispose();
    _docIdentController.dispose();
    _telefonoController.dispose();
    _nombreEntregoCtrl.dispose();
    _cargoEntregoCtrl.dispose();
    _observacionesCtrl.dispose();
    _busquedaController.dispose();
    for (final c in _cantidadControllers) c.dispose();
    super.dispose();
  }
}
