import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';
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
  final _representanteLegalController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _docIdentRLController = TextEditingController();

  String? _tipoBeneficiarioSeleccionado;
  final List<String> _tiposBeneficiario = [
    'Asociación / Organización',
    'Pequeño Productor',
    'Unidades Productivas',
  ];

  String? _zonaSeleccionada;
  final List<String> _zonasDisponibles = ['Urbana', 'Rural'];

  String? _areaSeleccionada;
  final List<String> _areasDisponibles = [
    'Sector Desarrollo Económico',
    'Sector Medio Ambiente',
    'Sector Agropecuario',
    'Administrativo',
  ];

  String? _cargoSeleccionado;
  final List<String> _cargosDisponibles = [
    'Apoyo a la Gestión',
    'Profesional de apoyo',
    'Coordinador (a)',
    'Secretario (a) Despacho SAMDE',
  ];

  String? _nombreEntregoSeleccionado;
  final List<String> _nombresEntregaDisponibles = [
    'NORMA MILENA VALENCIA ROA',
    'ALEYDA CALERO CAYOPARE',
    'YADY MERCEDES JASPE',
    'ADOLFO RODRIGUEZ NUÑEZ',
    'DARWIN FERNANDO SOLANO HERNANDEZ',
    'SANLY NATHALIA NUÑEZ GARCIA',
    'ANA MILENA MERCADO GARRIDO',
    'RONALD ANDRES SANDOVAL GOMEZ',
    'WILLINTON CORREAL CABARTE',
    'YADY MERCEDES JASPE VACA',
    'YENIFER PAOLA DURAN',
    'YUBER STIVEN TORRES MESA',
    'MAIBETH MELISSA MORENO MORENO',
    'STIVEN LEONEL HERNÁNDEZ MORA',
    'TIANNA KATHERINE SUÁREZ MEDINA',
    'EDER RESTREPO CANO',
    'CARLOS ANDRES PANIAGUA',
    'JHON FABER PILOTO GARCIA',
    'JHON JAIDHER ESCOBAR MEDINA',
    'YANIER YESID ESCOBAR MUÑOZ',
  ];

  final _docIdentController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  List<Map<String, dynamic>> _todosItemsDisponibles = [];
  List<TextEditingController> _cantidadControllers = [];
  List<TextEditingController> _cantidadAdicionalControllers = [];
  PlatformFile? _archivoSeleccionado;
  String? _archivoExistenteRuta;

  bool _cargando = false;
  bool _mostrandoLista = false;
  bool _modoEdicion = false;
  int? _actaEditandoId;

  List<Map<String, dynamic>> _detallesActaEditando = [];
  List<Map<String, dynamic>> _actas = [];
  final _busquedaController = TextEditingController();
  String _filtroBusqueda = '';
  List<Map<String, dynamic>> _actasFiltradas = [];

  List<bool> _erroresCantidad = [];
  Map<int, double> _cantidadesOriginales = {};

  http.Client? _clienteUpload;
  static const int _maxArchivoBytes = 10 * 1024 * 1024;
  static const String _baseUrl = 'http://192.168.10.64/samde_db/api';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};

    final idRecibido = map['usuario_id'];
    final idParseado = int.tryParse(idRecibido?.toString() ?? '');

    if (idParseado == null || idParseado <= 1) {
      StorageService().obtenerUsuario().then((data) {
        setState(() {
          usuarioId = data['usuarioId'] ?? 2;
        });
      });
    } else {
      usuarioId = idParseado;
    }

    username = map['username'] ?? 'Usuario';
    sector = map['sector'] ?? 'No Asignado';
    rol = map['rol'] ?? 'consulta';
  }

  @override
  void initState() {
    super.initState();
    _cargarItemsDisponibles();
    _cargarActas();
    _cargarEstadoGuardado();
  }

  Future<void> _cargarEstadoGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    final mostrandoListaGuardado = prefs.getBool('mostrando_lista') ?? false;
    setState(() {
      _mostrandoLista = mostrandoListaGuardado;
    });
  }

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

  String _formatNum(dynamic v) {
    final n = _toDouble(v);
    return n == n.truncateToDouble()
        ? n.truncate().toString()
        : n.toStringAsFixed(2);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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

  Future<bool> _cargarItemsDisponibles() async {
    setState(() => _cargando = true);
    try {
      final url = _modoEdicion
          ? '$_baseUrl/items/obtener_items_disponibles.php?mostrar_todos=1'
          : '$_baseUrl/items/obtener_items_disponibles.php';
      final r = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        final lista = List<Map<String, dynamic>>.from(data['data'] ?? []);
        if (_modoEdicion) {
          final idsDelActa = _idsDeActaEditando();
          lista.removeWhere((e) {
            final id = int.tryParse(e['id']?.toString() ?? '0') ?? 0;
            return _toDouble(e['cantidad_disponible']) <= 0 &&
                !idsDelActa.contains(id);
          });
          _ordenarItemsEditando(lista, idsDelActa);
        }
        setState(() {
          _todosItemsDisponibles = lista;
          _erroresCantidad = List<bool>.filled(lista.length, false);
        });
        _inicializarControllers();
        if (_modoEdicion) _restaurarValoresEdicion();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error cargando items: $e');
      return false;
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Set<int> _idsDeActaEditando() {
    final ids = <int>{};
    for (final d in _detallesActaEditando) {
      final id =
          int.tryParse(
            d['item_contrato_id']?.toString() ??
                d['id_item']?.toString() ??
                '0',
          ) ??
          0;
      if (id > 0) ids.add(id);
    }
    return ids;
  }

  void _ordenarItemsEditando(
    List<Map<String, dynamic>> lista, [
    Set<int>? ids,
  ]) {
    final idsDelActa = ids ?? _idsDeActaEditando();
    if (idsDelActa.isEmpty) return;
    lista.sort((a, b) {
      final idA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
      final idB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
      return (idsDelActa.contains(idA) ? 0 : 1).compareTo(
        idsDelActa.contains(idB) ? 0 : 1,
      );
    });
  }

  void _restaurarValoresEdicion() {
    for (
      int i = 0;
      i < _todosItemsDisponibles.length && i < _cantidadControllers.length;
      i++
    ) {
      final id =
          int.tryParse(_todosItemsDisponibles[i]['id']?.toString() ?? '0') ?? 0;
      final orig = _cantidadesOriginales[id];
      _cantidadControllers[i].text = orig != null ? _formatNum(orig) : '0';
      if (i < _cantidadAdicionalControllers.length) {
        _cantidadAdicionalControllers[i].text = '0';
      }
    }
  }

  void _inicializarControllers() {
    for (final c in _cantidadControllers) {
      c.dispose();
    }
    for (final c in _cantidadAdicionalControllers) {
      c.dispose();
    }
    _cantidadControllers = _todosItemsDisponibles
        .map((_) => TextEditingController())
        .toList();
    _cantidadAdicionalControllers = _todosItemsDisponibles
        .map((_) => TextEditingController())
        .toList();
  }

  void _validarCantidad(int index, String valor) {
    final item = _todosItemsDisponibles[index];
    final disponible = _toDouble(item['cantidad_disponible']);
    final cantidadIngresada = _toDouble(valor);
    setState(() {
      _erroresCantidad[index] = cantidadIngresada > disponible;
    });
  }

  void _validarAdicional(int index, String valor) {
    final item = _todosItemsDisponibles[index];
    final itemId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
    final original = _cantidadesOriginales[itemId] ?? 0.0;
    final disponible = _toDouble(item['cantidad_disponible']);
    final adicional = _toDouble(valor);
    final nuevoTotal = original + adicional;
    setState(() {
      final bool hayError = adicional > disponible || nuevoTotal < 0;
      _erroresCantidad[index] = hayError;
      if (!hayError) {
        _cantidadControllers[index].text = _formatNum(nuevoTotal);
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
      final file = result.files.first;
      if (file.size > _maxArchivoBytes) {
        _snack(
          '⚠️ El archivo pesa ${_formatBytes(file.size)} y el máximo permitido es 10 MB',
          Colors.red,
        );
        return;
      }
      setState(() => _archivoSeleccionado = file);
    }
  }

  Future<void> _adjuntarArchivo(http.MultipartRequest request) async {
    final f = _archivoSeleccionado;
    if (f == null) return;
    if (f.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('archivo', f.bytes!, filename: f.name),
      );
    }
  }

  Future<void> _cargarActaParaEditar(int actaId) async {
    setState(() => _cargando = true);
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/actas/obtener_acta.php?id=$actaId'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final actaData = data['data'];
        final detalles = List<Map<String, dynamic>>.from(
          actaData['detalles'] ?? [],
        );

        setState(() {
          _modoEdicion = true;
          _actaEditandoId = actaId;
          _detallesActaEditando = detalles;
          _numeroActaController.text = actaData['numero_acta'] ?? '';
          _fechaController.text = actaData['fecha_entrega'] ?? '';
          _entregadoAController.text = actaData['entregado_a'] ?? '';
          _areaSeleccionada = actaData['area_dependencia'];
          _docIdentController.text = actaData['documento_identidad'] ?? '';
          _telefonoController.text = actaData['telefono'] ?? '';
          _nombreEntregoSeleccionado = actaData['nombre_entrego'];
          _cargoSeleccionado = actaData['cargo_entrego'];
          _observacionesCtrl.text = actaData['observaciones'] ?? '';
          _archivoExistenteRuta = actaData['archivo_justificante'];
          _archivoSeleccionado = null;
          _cantidadesOriginales = {};
          _tipoBeneficiarioSeleccionado = actaData['tipo_beneficiario'];
          _zonaSeleccionada = actaData['zona'];
          _representanteLegalController.text =
              actaData['representante_legal'] ?? '';
          _ubicacionController.text = actaData['ubicacion'] ?? '';
          _docIdentRLController.text = actaData['documento_identidad_rl'] ?? '';
        });

        final bool exitoCarga = await _cargarItemsDisponibles();
        if (!exitoCarga || !mounted) {
          _snack('❌ No se pudieron cargar los items para editar', Colors.red);
          return;
        }

        final Map<int, double> cantidadesPorItem = {};
        for (final d in detalles) {
          final idStr =
              d['item_contrato_id']?.toString() ??
              d['id_item']?.toString() ??
              '0';
          final id = int.tryParse(idStr) ?? 0;
          final cantidad =
              double.tryParse(d['cantidad_entregada'].toString()) ?? 0.0;
          if (id > 0 && cantidad > 0) {
            cantidadesPorItem[id] = cantidad;
          }
        }

        setState(() {
          if (_cantidadControllers.length != _todosItemsDisponibles.length) {
            _inicializarControllers();
            _erroresCantidad = List<bool>.filled(
              _todosItemsDisponibles.length,
              false,
            );
          }

          for (int i = 0; i < _todosItemsDisponibles.length; i++) {
            final itemId =
                int.tryParse(
                  _todosItemsDisponibles[i]['id']?.toString() ?? '0',
                ) ??
                0;
            if (cantidadesPorItem.containsKey(itemId)) {
              final cantOriginal = cantidadesPorItem[itemId]!;
              _cantidadesOriginales[itemId] = cantOriginal;
              _cantidadControllers[i].text = _formatNum(cantOriginal);
              _cantidadAdicionalControllers[i].text = '0';
            } else {
              _cantidadControllers[i].text = '0';
              _cantidadAdicionalControllers[i].text = '0';
            }
          }
          _mostrandoLista = false;
        });
      } else {
        _snack('${data['message'] ?? 'Error al cargar acta'}', Colors.red);
      }
    } catch (e) {
      _snack('Error de conexión: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarActa(int actaId, String numeroActa) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Acta'),
        content: Text(
          '¿Estás seguro de eliminar el acta #$numeroActa? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _cargando = true);
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/actas/eliminar_acta.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': actaId}),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _snack('✅ Acta eliminada', Colors.green);
        await _cargarActas();
      } else {
        _snack('❌ ${data['message'] ?? 'Error al eliminar'}', Colors.red);
      }
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _registrarActa() async {
    if (!_formKey.currentState!.validate()) return;
    if (_archivoSeleccionado == null) {
      _snack('⚠️ Debe seleccionar el archivo del acta', Colors.red);
      return;
    }
    if (_erroresCantidad.contains(true)) {
      _snack(
        '⚠️ Hay items con cantidad superior al stock disponible',
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
          'id_item': item['id'] ?? 0,
          'id_egreso': item['id_egreso'] ?? 0,
          'cantidad_entregada': cantidad,
          'nombre_item': item['nombre_items'],
          'precio_unitario': _toDouble(
            item['precio_unitario'] ?? item['valor_unitario'],
          ),
        });
      }
    }

    if (itemsConCantidad.isEmpty) {
      _snack('Ingrese al menos un item', Colors.orange);
      return;
    }

    bool cancelado = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Guardando Acta...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Subiendo archivo y registrando datos'),
              const SizedBox(height: 8),
              Text(
                'Archivo: ${_archivoSeleccionado!.name} (${_formatBytes(_archivoSeleccionado!.size)})',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelado = true;
                _clienteUpload?.close();
                Navigator.pop(ctx);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );

    setState(() => _cargando = true);
    final cliente = http.Client();
    _clienteUpload = cliente;
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
      request.fields['nombre_entrego'] =
          _nombreEntregoSeleccionado?.trim() ?? '';
      request.fields['cargo_entrego'] = _cargoSeleccionado?.trim() ?? '';
      request.fields['observaciones'] = _observacionesCtrl.text.trim();
      request.fields['tipo_beneficiario'] =
          _tipoBeneficiarioSeleccionado?.trim() ?? '';
      request.fields['zona'] = _zonaSeleccionada?.trim() ?? '';
      request.fields['representante_legal'] = _representanteLegalController.text
          .trim();
      request.fields['ubicacion'] = _ubicacionController.text.trim();
      request.fields['documento_identidad_rl'] = _docIdentRLController.text
          .trim();
      request.fields['usuario_registro'] = usuarioId.toString();
      request.fields['detalles'] = jsonEncode(itemsConCantidad);

      await _adjuntarArchivo(request);

      final streamed = await cliente
          .send(request)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw Exception(
              'Tiempo de espera agotado (60s). El archivo puede ser muy grande o la conexión lenta.',
            ),
          );

      if (cancelado) return;

      final body = await streamed.stream.bytesToString();
      final data = jsonDecode(body);

      if (!mounted) return;
      Navigator.pop(context);

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
      if (!mounted) return;
      if (cancelado) {
        _snack('⚠️ Registro cancelado', Colors.orange);
      } else {
        Navigator.pop(context);
        _snack('❌ Error: $e', Colors.red);
        debugPrint('Error detallado: $e');
      }
    } finally {
      cliente.close();
      _clienteUpload = null;
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _actualizarActa() async {
    if (!_formKey.currentState!.validate()) return;
    if (_erroresCantidad.contains(true)) {
      _snack(
        '⚠️ Hay items con cantidad adicional superior al stock disponible',
        Colors.red,
      );
      return;
    }

    final itemsConCantidad = <Map<String, dynamic>>[];
    for (int i = 0; i < _todosItemsDisponibles.length; i++) {
      final item = _todosItemsDisponibles[i];
      final itemId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
      final original = _cantidadesOriginales[itemId] ?? 0.0;
      final adicional = _toDouble(_cantidadAdicionalControllers[i].text);
      final disponible = _toDouble(item['cantidad_disponible']);

      if (adicional > disponible || original + adicional < 0) {
        _snack('Stock insuficiente: ${item['nombre_items']}', Colors.red);
        return;
      }

      final cantidadTotal = original + adicional;
      if (cantidadTotal > 0) {
        if (item['id_egreso'] == null) {
          _snack('Item "${item['nombre_items']}" sin egreso', Colors.red);
          return;
        }
        itemsConCantidad.add({
          'id_item': item['id'] ?? 0,
          'id_egreso': item['id_egreso'] ?? 0,
          'cantidad_entregada': cantidadTotal,
          'nombre_item': item['nombre_items'],
          'precio_unitario': _toDouble(
            item['precio_unitario'] ?? item['valor_unitario'],
          ),
        });
      }
    }

    if (itemsConCantidad.isEmpty) {
      _snack('Ingrese al menos un item', Colors.orange);
      return;
    }

    bool cancelado = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Actualizando Acta...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Procesando cambios'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelado = true;
                _clienteUpload?.close();
                Navigator.pop(ctx);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );

    setState(() => _cargando = true);
    final cliente = http.Client();
    _clienteUpload = cliente;
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/actas/actualizar_acta.php'),
      );
      request.fields['id'] = _actaEditandoId.toString();
      request.fields['numero_acta'] = _numeroActaController.text.trim();
      request.fields['fecha_entrega'] = _fechaController.text.trim();
      request.fields['entregado_a'] = _entregadoAController.text.trim();
      request.fields['area_dependencia'] = _areaSeleccionada?.trim() ?? '';
      request.fields['documento_identidad'] = _docIdentController.text.trim();
      request.fields['telefono'] = _telefonoController.text.trim();
      request.fields['nombre_entrego'] =
          _nombreEntregoSeleccionado?.trim() ?? '';
      request.fields['cargo_entrego'] = _cargoSeleccionado?.trim() ?? '';
      request.fields['observaciones'] = _observacionesCtrl.text.trim();
      request.fields['tipo_beneficiario'] =
          _tipoBeneficiarioSeleccionado?.trim() ?? '';
      request.fields['zona'] = _zonaSeleccionada?.trim() ?? '';
      request.fields['representante_legal'] = _representanteLegalController.text
          .trim();
      request.fields['ubicacion'] = _ubicacionController.text.trim();
      request.fields['documento_identidad_rl'] = _docIdentRLController.text
          .trim();
      request.fields['usuario_registro'] = usuarioId.toString();
      request.fields['detalles'] = jsonEncode(itemsConCantidad);

      await _adjuntarArchivo(request);

      final streamed = await cliente
          .send(request)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw Exception('Tiempo de espera agotado (60s).'),
          );

      if (cancelado) return;

      final body = await streamed.stream.bytesToString();
      final data = jsonDecode(body);

      if (!mounted) return;
      Navigator.pop(context);

      if (streamed.statusCode == 200 && data['success'] == true) {
        _limpiarFormulario();
        _snack('✅ Acta actualizada', Colors.green);
        await _cargarItemsDisponibles();
        await _cargarActas();
        setState(() => _mostrandoLista = true);
      } else {
        _snack('❌ ${data['message'] ?? 'Error al actualizar'}', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      if (cancelado) {
        _snack('⚠️ Actualización cancelada', Colors.orange);
      } else {
        Navigator.pop(context);
        _snack('❌ Error: $e', Colors.red);
      }
    } finally {
      cliente.close();
      _clienteUpload = null;
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
    _docIdentController.clear();
    _telefonoController.clear();
    _observacionesCtrl.clear();
    _representanteLegalController.clear();
    _ubicacionController.clear();
    _docIdentRLController.clear();

    setState(() {
      _areaSeleccionada = null;
      _cargoSeleccionado = null;
      _nombreEntregoSeleccionado = null;
      _modoEdicion = false;
      _actaEditandoId = null;
      _archivoExistenteRuta = null;
      _archivoSeleccionado = null;
      _cantidadesOriginales = {};
      _detallesActaEditando = [];
      _tipoBeneficiarioSeleccionado = null;
      _zonaSeleccionada = null;
    });

    for (final c in _cantidadControllers) {
      c.clear();
    }
    for (final c in _cantidadAdicionalControllers) {
      c.clear();
    }
    _erroresCantidad = List<bool>.filled(_cantidadControllers.length, false);
  }

  Widget _buildZonaDropdown() {
    return DropdownButtonFormField<String>(
      value: _zonaSeleccionada,
      decoration: _deco('Zona', obligatorio: true),
      hint: const Text('Seleccione zona'),
      isExpanded: true,
      items: _zonasDisponibles
          .map(
            (zona) => DropdownMenuItem<String>(value: zona, child: Text(zona)),
          )
          .toList(),
      onChanged: (String? newValue) =>
          setState(() => _zonaSeleccionada = newValue),
      validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF2E7D32);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Scaffold(
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        usuarioId: usuarioId,
        selectedIndex: 1,
      ),
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
              child: _mostrandoLista
                  ? _buildLista(verde)
                  : _buildFormulario(verde, isMobile),
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
                    child: Builder(
                      builder: (ctx) => IconButton(
                        icon: Icon(Icons.menu, color: verde, size: 28),
                        onPressed: () => Scaffold.of(ctx).openDrawer(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ),
                  if (!_mostrandoLista && !_modoEdicion)
                    Positioned(
                      right: 0,
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _mostrandoLista = true);
                            _guardarEstado(true);
                            _cargarActas();
                          },
                          icon: const Icon(
                            Icons.list,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: const Text(
                            'Listado',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_mostrandoLista)
                    Positioned(
                      right: 0,
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _mostrandoLista = false);
                            _guardarEstado(false);
                          },
                          icon: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: const Text(
                            'Nuevo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: verde,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_modoEdicion)
                    Positioned(
                      right: 0,
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _limpiarFormulario();
                            setState(() => _mostrandoLista = true);
                          },
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _modoEdicion
                  ? 'Editar Acta #$_actaEditandoId'
                  : 'Actas de Entrega',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: verde,
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
              child: Text(
                _modoEdicion
                    ? 'Editar Acta #$_actaEditandoId'
                    : 'Actas de Entrega',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isTablet ? 22 : 26,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: !_mostrandoLista && !_modoEdicion
                    ? SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _mostrandoLista = true);
                            _guardarEstado(true);
                            _cargarActas();
                          },
                          icon: const Icon(
                            Icons.list,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Ver Listado',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      )
                    : _mostrandoLista
                    ? SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _mostrandoLista = false);
                            _guardarEstado(false);
                          },
                          icon: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Nuevo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: verde,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _limpiarFormulario();
                            setState(() => _mostrandoLista = true);
                          },
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'Cancelar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
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
  }

  Widget _buildFormulario(Color verde, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSeccionDatos(verde, isMobile),
                    SizedBox(height: isMobile ? 24 : 32),
                    _buildSeccionItems(verde, isMobile),
                    SizedBox(height: isMobile ? 24 : 32),
                    _buildSeccionArchivo(verde),
                    const SizedBox(height: 32),
                    _buildBotones(verde),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionDatos(Color verde, bool isMobile) {
    final esAsociacion =
        _tipoBeneficiarioSeleccionado == 'Asociación / Organización' ||
        _tipoBeneficiarioSeleccionado == 'Unidades Productivas';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.assignment, color: verde, size: isMobile ? 20 : 24),
            const SizedBox(width: 8),
            Text(
              'Datos del Acta',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
          ],
        ),
        Divider(height: isMobile ? 24 : 32),
        if (isMobile) ...[
          TextFormField(
            controller: _numeroActaController,
            decoration: _deco('Número del Acta', obligatorio: true),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fechaController,
            decoration: _deco('Fecha de Entrega', obligatorio: true),
            readOnly: true,
            onTap: _pickDate,
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _tipoBeneficiarioSeleccionado,
            decoration: _deco('Tipo de Beneficiario', obligatorio: true),
            hint: const Text('Seleccione tipo'),
            isExpanded: true,
            items: _tiposBeneficiario
                .map(
                  (tipo) =>
                      DropdownMenuItem<String>(value: tipo, child: Text(tipo)),
                )
                .toList(),
            onChanged: (String? newValue) {
              setState(() {
                _tipoBeneficiarioSeleccionado = newValue;
                if (newValue != 'Asociación / Organización' &&
                    newValue != 'Unidades Productivas') {
                  _representanteLegalController.clear();
                  _docIdentRLController.clear();
                }
              });
            },
            validator: (value) =>
                value == null || value.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _entregadoAController,
            decoration: _deco('Entregado a', obligatorio: true),
            validator: (v) => v!.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _docIdentController,
            decoration: _deco(
              'Documento de Identidad / NIT',
              obligatorio: esAsociacion,
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (esAsociacion && v!.isEmpty)
                return 'Requerido para este tipo de beneficiario';
              return null;
            },
          ),
          const SizedBox(height: 16),
          if (esAsociacion) ...[
            TextFormField(
              controller: _representanteLegalController,
              decoration: _deco('Representante Legal', obligatorio: true),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _docIdentRLController,
              decoration: _deco('Documento Identidad RL', obligatorio: true),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
          ] else
            _buildZonaDropdown(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _ubicacionController,
            decoration: _deco('Ubicación'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _telefonoController,
            decoration: _deco('Teléfono'),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _nombreEntregoSeleccionado,
            decoration: _deco('Nombre quien entregó', obligatorio: true),
            hint: const Text('Seleccione un nombre'),
            isExpanded: true,
            items: _nombresEntregaDisponibles
                .map(
                  (String nombre) => DropdownMenuItem<String>(
                    value: nombre,
                    child: Text(nombre, style: const TextStyle(fontSize: 13)),
                  ),
                )
                .toList(),
            onChanged: (String? newValue) =>
                setState(() => _nombreEntregoSeleccionado = newValue),
            validator: (value) =>
                value == null || value.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _areaSeleccionada,
            decoration: _deco('Área / Dependencia', obligatorio: true),
            hint: const Text('Seleccione un área'),
            isExpanded: true,
            items: _areasDisponibles
                .map(
                  (String area) =>
                      DropdownMenuItem<String>(value: area, child: Text(area)),
                )
                .toList(),
            onChanged: (String? newValue) =>
                setState(() => _areaSeleccionada = newValue),
            validator: (value) =>
                value == null || value.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _cargoSeleccionado,
            decoration: _deco('Cargo'),
            hint: const Text('Seleccione un cargo'),
            isExpanded: true,
            items: _cargosDisponibles
                .map(
                  (String cargo) => DropdownMenuItem<String>(
                    value: cargo,
                    child: Text(cargo),
                  ),
                )
                .toList(),
            onChanged: (String? newValue) =>
                setState(() => _cargoSeleccionado = newValue),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _numeroActaController,
                  decoration: _deco('Número del Acta', obligatorio: true),
                  validator: (v) => v!.isEmpty ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _fechaController,
                  decoration: _deco('Fecha de Entrega', obligatorio: true),
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
                child: DropdownButtonFormField<String>(
                  value: _tipoBeneficiarioSeleccionado,
                  decoration: _deco('Tipo de Beneficiario', obligatorio: true),
                  hint: const Text('Seleccione tipo'),
                  isExpanded: true,
                  items: _tiposBeneficiario
                      .map(
                        (tipo) => DropdownMenuItem<String>(
                          value: tipo,
                          child: Text(tipo),
                        ),
                      )
                      .toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _tipoBeneficiarioSeleccionado = newValue;
                      if (newValue != 'Asociación / Organización' &&
                          newValue != 'Unidades Productivas') {
                        _representanteLegalController.clear();
                        _docIdentRLController.clear();
                      }
                    });
                  },
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _entregadoAController,
                  decoration: _deco('Entregado a', obligatorio: true),
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
                  controller: _docIdentController,
                  decoration: _deco(
                    'Documento de Identidad / NIT',
                    obligatorio: esAsociacion,
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (esAsociacion && v!.isEmpty)
                      return 'Requerido para este tipo de beneficiario';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: esAsociacion
                    ? TextFormField(
                        controller: _representanteLegalController,
                        decoration: _deco(
                          'Representante Legal',
                          obligatorio: true,
                        ),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      )
                    : _buildZonaDropdown(),
              ),
            ],
          ),
          if (esAsociacion) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _docIdentRLController,
                    decoration: _deco(
                      'Documento Identidad RL',
                      obligatorio: true,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildZonaDropdown()),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ubicacionController,
                  decoration: _deco('Ubicación'),
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
                child: DropdownButtonFormField<String>(
                  value: _nombreEntregoSeleccionado,
                  decoration: _deco('Nombre quien entregó', obligatorio: true),
                  hint: const Text('Seleccione un nombre'),
                  isExpanded: true,
                  items: _nombresEntregaDisponibles
                      .map(
                        (String nombre) => DropdownMenuItem<String>(
                          value: nombre,
                          child: Text(
                            nombre,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (String? newValue) =>
                      setState(() => _nombreEntregoSeleccionado = newValue),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Requerido' : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _areaSeleccionada,
                  decoration: _deco('Área / Dependencia', obligatorio: true),
                  hint: const Text('Seleccione un área'),
                  isExpanded: true,
                  items: _areasDisponibles
                      .map(
                        (String area) => DropdownMenuItem<String>(
                          value: area,
                          child: Text(area),
                        ),
                      )
                      .toList(),
                  onChanged: (String? newValue) =>
                      setState(() => _areaSeleccionada = newValue),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Requerido' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _cargoSeleccionado,
                  decoration: _deco('Cargo'),
                  hint: const Text('Seleccione un cargo'),
                  isExpanded: true,
                  items: _cargosDisponibles
                      .map(
                        (String cargo) => DropdownMenuItem<String>(
                          value: cargo,
                          child: Text(cargo),
                        ),
                      )
                      .toList(),
                  onChanged: (String? newValue) =>
                      setState(() => _cargoSeleccionado = newValue),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
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
            Icon(Icons.table_view, color: verde, size: isMobile ? 20 : 24),
            const SizedBox(width: 8),
            Text(
              'Items a Entregar',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
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
        Divider(height: isMobile ? 24 : 32),
        isMobile ? _buildItemsMobile(verde) : _buildItemsDesktop(verde),
      ],
    );
  }

  Widget _buildItemsMobile(Color verde) {
    final bool hayItemsVisibles = _modoEdicion
        ? _todosItemsDisponibles.isNotEmpty
        : _todosItemsDisponibles.any(
            (e) => _toDouble(e['cantidad_disponible']) > 0,
          );

    if (!hayItemsVisibles && !_cargando) {
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

    if (_cantidadControllers.length != _todosItemsDisponibles.length ||
        _cantidadAdicionalControllers.length != _todosItemsDisponibles.length) {
      return Container(
        padding: const EdgeInsets.all(60),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _todosItemsDisponibles
          .where(
            (item) => _modoEdicion
                ? true
                : _toDouble(item['cantidad_disponible']) > 0,
          )
          .length,
      itemBuilder: (context, index) {
        final item = _todosItemsDisponibles
            .where(
              (item) => _modoEdicion
                  ? true
                  : _toDouble(item['cantidad_disponible']) > 0,
            )
            .toList()[index];
        final i = _todosItemsDisponibles.indexOf(item);
        final disponible = _toDouble(item['cantidad_disponible']);
        final contratadaRaw = item['cantidad_contratada'];
        final entregadaRaw = item['cantidad_total_entregada'];
        final tieneStock = disponible > 0;
        final hayErrorEntregar =
            !_modoEdicion &&
            (i < _erroresCantidad.length && _erroresCantidad[i]);
        final hayErrorAdicional =
            _modoEdicion &&
            (i < _erroresCantidad.length && _erroresCantidad[i]);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['nombre_items'] ?? 'Sin nombre',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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
                      'Contrato',
                      item['numero_contrato'] ?? 'N/A',
                      Colors.purple,
                    ),
                    _buildBadge(
                      'Contratada',
                      contratadaRaw == null
                          ? '—'
                          : _formatNum(_toDouble(contratadaRaw)),
                      Colors.blue,
                    ),
                    _buildBadge(
                      'Entregada',
                      entregadaRaw == null
                          ? '—'
                          : _formatNum(_toDouble(entregadaRaw)),
                      Colors.orange,
                    ),
                    _buildBadge(
                      'Stock Bodega',
                      _formatNum(disponible),
                      disponible > 5
                          ? Colors.green
                          : (disponible > 0 ? Colors.deepOrange : Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _modoEdicion ? 'Total entregado:' : 'Cantidad a entregar:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _cantidadControllers[i],
                  keyboardType: TextInputType.number,
                  readOnly: _modoEdicion,
                  enabled: _modoEdicion || tieneStock,
                  onChanged: (valor) {
                    if (!_modoEdicion) _validarCantidad(i, valor);
                  },
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: hayErrorEntregar
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: _modoEdicion
                        ? Colors.grey.shade100
                        : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: hayErrorEntregar
                            ? Colors.red
                            : Colors.green.shade400,
                      ),
                    ),
                  ),
                ),
                if (_modoEdicion) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Cantidad adicional:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _cantidadAdicionalControllers[i],
                    keyboardType: TextInputType.numberWithOptions(signed: true),
                    onChanged: (valor) => _validarAdicional(i, valor),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: hayErrorAdicional
                          ? Colors.red.shade700
                          : Colors.green.shade700,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(
                          color: hayErrorAdicional
                              ? Colors.red
                              : Colors.green.shade400,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
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

  Widget _buildItemsDesktop(Color verde) {
    final bool hayItemsVisibles = _modoEdicion
        ? _todosItemsDisponibles.isNotEmpty
        : _todosItemsDisponibles.any(
            (e) => _toDouble(e['cantidad_disponible']) > 0,
          );

    if (!hayItemsVisibles && !_cargando) {
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

    if (_cantidadControllers.length != _todosItemsDisponibles.length ||
        _cantidadAdicionalControllers.length != _todosItemsDisponibles.length) {
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
            decoration: const BoxDecoration(
              color: Color(0xFFC8E6C9),
              borderRadius: BorderRadius.only(
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
                  flex: 1,
                  child: Text(
                    'Contrato',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                      fontSize: 11,
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
                    'Cant. Entregada',
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
                    'Cant. Bod. SAMDE',
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
                    _modoEdicion ? 'Total Entregado' : 'Cant. a Entregar *',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                      fontSize: 11,
                    ),
                  ),
                ),
                if (_modoEdicion)
                  Expanded(
                    child: Text(
                      'Cant. Adicional *',
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._todosItemsDisponibles
                      .asMap()
                      .entries
                      .where((entry) {
                        if (_modoEdicion) return true;
                        return _toDouble(entry.value['cantidad_disponible']) >
                            0;
                      })
                      .map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        final disponible = _toDouble(
                          item['cantidad_disponible'],
                        );
                        final contratadaRaw = item['cantidad_contratada'];
                        final entregadaRaw = item['cantidad_total_entregada'];
                        final tieneStock = disponible > 0;
                        final hayErrorEntregar =
                            !_modoEdicion &&
                            (i < _erroresCantidad.length &&
                                _erroresCantidad[i]);
                        final hayErrorAdicional =
                            _modoEdicion &&
                            (i < _erroresCantidad.length &&
                                _erroresCantidad[i]);
                        final bool stockCero = _modoEdicion && disponible <= 0;
                        final bool stockBajo =
                            _modoEdicion && !stockCero && disponible <= 5;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 3,
                          ),
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
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
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
                                      fontSize: 11,
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
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    contratadaRaw == null
                                        ? '—'
                                        : _formatNum(_toDouble(contratadaRaw)),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
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
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    entregadaRaw == null
                                        ? '—'
                                        : _formatNum(_toDouble(entregadaRaw)),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
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
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: stockCero
                                        ? Colors.red.shade50
                                        : (stockBajo
                                              ? Colors.deepOrange.shade50
                                              : Colors.green.shade50),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: stockCero
                                          ? Colors.red.shade300
                                          : (stockBajo
                                                ? Colors.deepOrange.shade400
                                                : Colors.green.shade200),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    _formatNum(disponible),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: stockCero
                                          ? Colors.red.shade700
                                          : (stockBajo
                                                ? Colors.deepOrange.shade700
                                                : Colors.green.shade700),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: TextFormField(
                                    controller: _cantidadControllers[i],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    textAlignVertical: TextAlignVertical.center,
                                    readOnly: _modoEdicion,
                                    enabled: _modoEdicion || tieneStock,
                                    onChanged: (valor) {
                                      if (!_modoEdicion)
                                        _validarCantidad(i, valor);
                                    },
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: hayErrorEntregar
                                          ? Colors.red.shade700
                                          : Colors.green.shade700,
                                    ),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: _modoEdicion
                                          ? Colors.grey.shade100
                                          : Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 0,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: hayErrorEntregar
                                              ? Colors.red
                                              : Colors.green.shade400,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: hayErrorEntregar
                                              ? Colors.red
                                              : Colors.green.shade400,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: hayErrorEntregar
                                              ? Colors.red
                                              : Colors.green.shade700,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_modoEdicion) ...[
                                const SizedBox(width: 4),
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: TextFormField(
                                      controller:
                                          _cantidadAdicionalControllers[i],
                                      keyboardType:
                                          TextInputType.numberWithOptions(
                                            signed: true,
                                          ),
                                      textAlign: TextAlign.center,
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      onChanged: (valor) =>
                                          _validarAdicional(i, valor),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: hayErrorAdicional
                                            ? Colors.red.shade700
                                            : Colors.green.shade700,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 0,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: hayErrorAdicional
                                                ? Colors.red
                                                : Colors.green.shade400,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: hayErrorAdicional
                                                ? Colors.red
                                                : Colors.green.shade400,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: hayErrorAdicional
                                                ? Colors.red
                                                : Colors.green.shade700,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionArchivo(Color verde) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file, color: verde, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Archivo del Acta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
            const Text(
              ' *',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        InkWell(
          onTap: _seleccionarArchivo,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _archivoSeleccionado != null
                  ? Colors.green.shade50
                  : (_archivoExistenteRuta != null
                        ? Colors.blue.shade50
                        : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _archivoSeleccionado != null
                    ? Colors.green.shade300
                    : (_archivoExistenteRuta != null
                          ? Colors.blue.shade300
                          : Colors.green.shade300),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _archivoSeleccionado != null
                      ? Icons.check_circle
                      : (_archivoExistenteRuta != null
                            ? Icons.cloud_done
                            : Icons.upload_file),
                  color: _archivoSeleccionado != null
                      ? Colors.green.shade600
                      : (_archivoExistenteRuta != null
                            ? Colors.blue.shade600
                            : Colors.red.shade500),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _archivoSeleccionado != null
                            ? '${_archivoSeleccionado!.name} (${_formatBytes(_archivoSeleccionado!.size)})'
                            : (_archivoExistenteRuta != null
                                  ? ' Archivo actual: ${_archivoExistenteRuta!.split('/').last}'
                                  : 'Toca para subir el archivo del acta'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _archivoSeleccionado != null
                              ? Colors.green.shade700
                              : (_archivoExistenteRuta != null
                                    ? Colors.blue.shade700
                                    : Colors.green.shade600),
                        ),
                      ),
                      Text(
                        _archivoSeleccionado != null
                            ? 'PDF, JPG o PNG (Máx. 10MB) *'
                            : (_archivoExistenteRuta != null
                                  ? 'Toca para cambiar el archivo'
                                  : 'PDF, JPG o PNG (Máx. 10MB) *'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_archivoExistenteRuta != null &&
                    _archivoSeleccionado == null)
                  IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.blue),
                    onPressed: () =>
                        _abrirArchivoJustificante(_archivoExistenteRuta),
                    tooltip: 'Ver archivo actual',
                  ),
                if (_archivoSeleccionado != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () =>
                        setState(() => _archivoSeleccionado = null),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBotones(Color verde) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _cargando
                ? null
                : () => _modoEdicion ? _actualizarActa() : _registrarActa(),
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
                : Text(
                    _modoEdicion ? 'ACTUALIZAR ACTA' : 'GUARDAR REGISTRO',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (!_modoEdicion) ...[
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
      ],
    );
  }

  Future<void> _abrirArchivoJustificante(String? archivo) async {
    if (archivo == null || archivo.toString().trim().isEmpty) {
      _snack('No hay archivo disponible', Colors.orange);
      return;
    }
    final uri = Uri.parse(
      '$_baseUrl/actas/download_acta.php?file=${Uri.encodeComponent(archivo.toString())}',
    );
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _snack('No se pudo abrir el archivo', Colors.red);
      }
    } catch (e) {
      if (mounted) _snack('Error: $e', Colors.red);
    }
  }

  Future<void> _verDetalleActa(Map<String, dynamic> acta) async {
    final actaId = acta['id'];
    if (actaId == null) return;

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
    final dialogWidth = screenWidth < 600 ? screenWidth - 32 : 900.0;
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
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(screenWidth < 600 ? 16 : 24),
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
                                IconButton(
                                  icon: const Icon(
                                    Icons.visibility,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'Ver archivo',
                                  onPressed: () => _abrirArchivoJustificante(
                                    acta['archivo_justificante']?.toString(),
                                  ),
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
                          width: double.infinity,
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
                                ...itemsEntregados.map((item) {
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
                  child: SizedBox(
                    width: double.infinity,
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.green, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
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
                      child: Column(
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
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  Icons.visibility_outlined,
                                  color: Colors.blue.shade700,
                                  size: 22,
                                ),
                                tooltip: 'Vista previa',
                                onPressed: () => _verDetalleActa(acta),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
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
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _cargarActaParaEditar(
                                  int.parse(acta['id'].toString()),
                                ),
                                icon: Icon(
                                  Icons.edit,
                                  color: Colors.blue.shade600,
                                  size: 18,
                                ),
                                label: Text(
                                  'Editar',
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (rol == 'administrador' ||
                                  rol == 'administrativo')
                                TextButton.icon(
                                  onPressed: () => _eliminarActa(
                                    int.parse(acta['id'].toString()),
                                    acta['numero_acta'] ?? '',
                                  ),
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.red.shade600,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Eliminar',
                                    style: TextStyle(
                                      color: Colors.red.shade600,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
    _numeroActaController.dispose();
    _fechaController.dispose();
    _entregadoAController.dispose();
    _docIdentController.dispose();
    _telefonoController.dispose();
    _observacionesCtrl.dispose();
    _busquedaController.dispose();
    _representanteLegalController.dispose();
    _ubicacionController.dispose();
    _docIdentRLController.dispose();
    for (final c in _cantidadControllers) {
      c.dispose();
    }
    for (final c in _cantidadAdicionalControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
