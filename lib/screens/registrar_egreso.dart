import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/drawer_menu.dart';

class RegistrarEgresoPage extends StatefulWidget {
  const RegistrarEgresoPage({super.key});

  @override
  State<RegistrarEgresoPage> createState() => _RegistrarEgresoPageState();
}

class _RegistrarEgresoPageState extends State<RegistrarEgresoPage> {
  late String username;
  late int usuarioId;
  late String sector;
  late String rol;

  final _formKey = GlobalKey<FormState>();
  final _numeroEgresoController = TextEditingController();
  final _fechaEgresoController = TextEditingController();
  final _observacionController = TextEditingController();
  final _objetoContratoController = TextEditingController();
  final _searchController = TextEditingController();

  List<TextEditingController> _cantidadControllers = [];

  // Variables para manejo de multiples documentos
  List<PlatformFile> _documentosSeleccionados = [];
  List<Map<String, String>> _documentosExistentes = [];
  bool _cargandoArchivos = false;
  bool _documentosBloqueados = false;

  String? _anioSeleccionado;
  int? _contratoSeleccionado;
  static const int BODEGA_FIJA_ID = 2;
  static const String BODEGA_FIJA_NOMBRE = 'SAMDE';

  List<String> _aniosDisponibles = [];
  List<Map<String, dynamic>> _contratosDisponibles = [];
  List<Map<String, dynamic>> _detallesEgreso = [];
  List<Map<String, dynamic>> _egresos = [];
  List<Map<String, dynamic>> _egresosFiltrados = [];
  String _searchQuery = '';

  bool _cargando = false;
  bool _mostrandoLista = false;
  bool _modoEdicion = false;
  int? _egresoEditandoId;

  static const String _baseUrl = 'http://localhost/samde_db/api';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
    username = map['username'] ?? 'Usuario';
    usuarioId = map['usuario_id'] ?? 1;
    sector = map['sector'] ?? 'No Asignado';
    rol = map['rol'] ?? 'consulta';
  }

  @override
  void initState() {
    super.initState();
    _cargarAnios();
    _cargarEgresos();
    _searchController.addListener(_filtrarEgresos);
  }

  // =================================================================
  // FUNCIONES PARA MANEJO DE ARCHIVOS
  // =================================================================
  Future<void> _seleccionarMultiplesDocumentos() async {
    setState(() => _cargandoArchivos = true);
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      );

      if (result != null) {
        final archivosValidos = <PlatformFile>[];
        for (var file in result.files) {
          if (file.size > 2 * 1024 * 1024) {
            _snack('⚠️ "${file.name}" excede el limite de 2 MB', Colors.orange);
          } else {
            archivosValidos.add(file);
          }
        }

        if (archivosValidos.isNotEmpty) {
          setState(() {
            _documentosSeleccionados.addAll(archivosValidos);
          });
          _snack(
            '✅ ${archivosValidos.length} documento(s) agregado(s)',
            Colors.green,
          );
        }
      }
    } catch (e) {
      _snack('Error al seleccionar archivos: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargandoArchivos = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    int divisor = 1;
    String suffix = "B";
    if (bytes >= 1073741824) {
      divisor = 1073741824;
      suffix = "GB";
    } else if (bytes >= 1048576) {
      divisor = 1048576;
      suffix = "MB";
    } else if (bytes >= 1024) {
      divisor = 1024;
      suffix = "KB";
    }
    return '${(bytes / divisor).toStringAsFixed(1)} $suffix';
  }

  bool _esImagen(String nombre) {
    final lower = nombre.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  Future<void> _previewDocumento(PlatformFile file) async {
    final esImagen = _esImagen(file.name);

    if (esImagen && file.bytes != null) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => Dialog(
            backgroundColor: Colors.black87,
            child: Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.memory(file.bytes!, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red),
              SizedBox(width: 8),
              Text('Documento'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📄 ${file.name}'),
              const SizedBox(height: 8),
              Text('📦 Tamaño: ${_formatBytes(file.size)}'),
              const SizedBox(height: 16),
              const Text(
                'Este archivo se adjuntará al egreso y podrá visualizarse desde el listado.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _previewDocumentoExistente(String ruta, String nombre) async {
    final esImg = _esImagen(nombre);

    // Usar el PHP intermediario para evitar CORS
    // Si ruta es: /samde_db/api/egresos/uploads/33/doc_xxx.png
    // URL será: http://localhost/samde_db/api/egresos/download_documento.php?file=/samde_db/api/egresos/uploads/33/doc_xxx.png
    final urlCompleta =
        '$_baseUrl/egresos/download_documento.php?file=${Uri.encodeComponent(ruta)}';

    if (esImg) {
      // Mostrar imagen dentro del Dialog (sin abrir otra pestaña)
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => Dialog(
            backgroundColor: Colors.black87,
            child: Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    urlCompleta,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No se pudo cargar la imagen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'URL: $urlCompleta',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      // Para PDFs, abrir en navegador (no se pueden mostrar inline fácilmente)
      final uri = Uri.parse(urlCompleta);
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
  }
  // =================================================================

  void _inicializarControllersCantidad() {
    for (final c in _cantidadControllers) {
      c.dispose();
    }
    _cantidadControllers = _detallesEgreso.map((detalle) {
      final cantidad = _modoEdicion
          ? (detalle['cantidad_adicional'] ?? 0.0)
          : (detalle['cantidad_egresada'] ?? 0.0);
      return TextEditingController(
        text: cantidad == 0.0 ? '' : _formatearNumero(cantidad),
      );
    }).toList();
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

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '').trim()) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString().trim()) ?? 0;
  }

  void _filtrarEgresos() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase().trim();
      _egresosFiltrados = _searchQuery.isEmpty
          ? List.from(_egresos)
          : _egresos.where((e) {
              return (e['numero_egreso'] ?? '').toLowerCase().contains(
                    _searchQuery,
                  ) ||
                  (e['bodega_nombre'] ?? '').toLowerCase().contains(
                    _searchQuery,
                  ) ||
                  (e['usuario_nombre'] ?? '').toLowerCase().contains(
                    _searchQuery,
                  ) ||
                  (e['observacion'] ?? '').toLowerCase().contains(_searchQuery);
            }).toList();
    });
  }

  bool _validarStock() {
    final itemsConCantidad = _detallesEgreso.where((d) {
      final val = _modoEdicion
          ? _toDouble(d['cantidad_adicional'])
          : _toDouble(d['cantidad_egresada']);
      return val > 0;
    }).toList();

    if (itemsConCantidad.isEmpty) {
      _snack('Debe egresar al menos un item con cantidad > 0', Colors.orange);
      return false;
    }

    for (final detalle in itemsConCantidad) {
      final double stock = _toDouble(detalle['stock_disponible']);
      final double baseEgresada = _modoEdicion
          ? _toDouble(detalle['cantidad_egresada'])
          : 0.0;
      final double adicional = _modoEdicion
          ? _toDouble(detalle['cantidad_adicional'])
          : _toDouble(detalle['cantidad_egresada']);
      final double totalProyectado = baseEgresada + adicional;

      if (_modoEdicion) {
        if (adicional > stock) {
          _snack(
            '⚠️ Stock insuficiente en "${detalle['nombre_item']}". Disponible: ${_formatearNumero(stock)}, Solicitado (adicional): ${_formatearNumero(adicional)}',
            Colors.red,
          );
          return false;
        }
      } else {
        if (totalProyectado > stock) {
          _snack(
            '⚠️ Stock insuficiente en "${detalle['nombre_item']}". Disponible: ${_formatearNumero(stock)}, Solicitado: ${_formatearNumero(totalProyectado)}',
            Colors.red,
          );
          return false;
        }
      }
    }
    return true;
  }

  void _cargarAnios() {
    final now = DateTime.now().year;
    _aniosDisponibles = {
      (now - 2).toString(),
      (now - 1).toString(),
      ...List.generate(10, (i) => (now + i).toString()),
    }.toList()..sort();
  }

  Future<void> _cargarContratosPorAnio(String anio) async {
    setState(() {
      _cargando = true;
      _contratosDisponibles = [];
      _detallesEgreso = [];
      _objetoContratoController.clear();
    });
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/contratos/listar_contrato.php'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        final todos = List<Map<String, dynamic>>.from(data['data'] ?? []);
        setState(() {
          _contratosDisponibles = todos
              .where((c) => (c['fecha_inicio'] ?? '').startsWith(anio))
              .toList();
        });
        if (_contratosDisponibles.isEmpty) {
          _snack('No hay contratos para el año $anio', Colors.orange);
        }
      }
    } catch (e) {
      _snack('Error cargando contratos: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cargarTodosLosContratos() async {
    try {
      final r = await http
          .get(Uri.parse('$_baseUrl/contratos/listar_contrato.php'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        setState(() {
          _contratosDisponibles = List<Map<String, dynamic>>.from(
            data['data'] ?? [],
          );
        });
      }
    } catch (e) {
      debugPrint('Error cargando todos los contratos: $e');
    }
  }

  Future<void> _cargarItemsContrato(int contratoId) async {
    setState(() {
      _cargando = true;
      _detallesEgreso = [];
    });

    final contratoObj = _contratosDisponibles.firstWhere(
      (c) => _toInt(c['id']) == contratoId,
      orElse: () => {},
    );
    _objetoContratoController.text =
        contratoObj['objeto_contrato']?.toString() ??
        contratoObj['objeto']?.toString() ??
        'No especificado';

    try {
      final url = '$_baseUrl/egresos/obtener_stock.php?contrato_id=$contratoId';
      final r = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);

      if (r.statusCode == 200 && data['success'] == true) {
        final items = List<Map<String, dynamic>>.from(data['data'] ?? []);
        if (items.isEmpty) {
          _snack('Este contrato no tiene items asociados', Colors.orange);
        } else {
          setState(() {
            _detallesEgreso = items.map((item) {
              final totalIngresadoRaw = item['total_ingresado'];
              final totalIngresado = totalIngresadoRaw is int
                  ? totalIngresadoRaw.toDouble()
                  : totalIngresadoRaw is double
                  ? totalIngresadoRaw
                  : double.tryParse(totalIngresadoRaw.toString()) ?? 0.0;
              final totalEgresadoRaw = item['total_egresado'];
              final totalEgresado = totalEgresadoRaw is int
                  ? totalEgresadoRaw.toDouble()
                  : totalEgresadoRaw is double
                  ? totalEgresadoRaw
                  : double.tryParse(totalEgresadoRaw.toString()) ?? 0.0;

              return {
                'id_item_contrato': _toInt(item['item_contrato_id']),
                'nombre_item': item['nombre']?.toString() ?? '',
                'descripcion': item['descripcion']?.toString() ?? '',
                'cantidad_contratada': _toDouble(item['cantidad_contratada']),
                'total_ingresado': totalIngresado,
                'total_egresado': totalEgresado,
                'stock_disponible': _toDouble(item['stock_disponible']),
                'cantidad_egresada': 0.0,
                'cantidad_adicional': 0.0,
                'precio_unitario': _toDouble(item['precio_unitario']),
              };
            }).toList();
            _inicializarControllersCantidad();
          });
        }
      } else {
        _snack('${data['message'] ?? 'Error al cargar items'}', Colors.red);
      }
    } catch (e) {
      _snack('❌ Error cargando items: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _actualizarCantidad(int index, String valor) {
    final cantidad = double.tryParse(valor) ?? 0;
    final detalle = _detallesEgreso[index];
    final stock = _toDouble(detalle['stock_disponible']);

    setState(() {
      if (_modoEdicion) {
        _detallesEgreso[index]['cantidad_adicional'] = cantidad;
      } else {
        _detallesEgreso[index]['cantidad_egresada'] = cantidad;
      }
    });

    if (_modoEdicion && cantidad > stock && stock >= 0) {
      _snack(
        '⚠️ Excede stock. Disponible: ${_formatearNumero(stock)}',
        Colors.red,
      );
    } else if (!_modoEdicion && cantidad > stock && stock >= 0) {
      _snack(
        '⚠️ Excede stock. Disponible: ${_formatearNumero(stock)}',
        Colors.red,
      );
    }
  }

  // =================================================================
  // REGISTRO CON MULTIPART
  // =================================================================
  Future<void> _registrarEgreso() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contratoSeleccionado == null) {
      _snack('Seleccione un contrato', Colors.orange);
      return;
    }
    if (!_validarStock()) return;

    setState(() => _cargando = true);
    try {
      final uri = Uri.parse('$_baseUrl/egresos/registrar_egreso.php');
      final request = http.MultipartRequest('POST', uri);

      request.fields['contrato_id'] = _contratoSeleccionado.toString();
      request.fields['numero_egreso'] = _numeroEgresoController.text.trim();
      request.fields['id_bodega'] = BODEGA_FIJA_ID.toString();
      request.fields['usuario_id'] = usuarioId.toString();
      request.fields['usuario_registro'] = username;
      request.fields['fecha'] = _fechaEgresoController.text.trim();
      request.fields['observacion'] = _observacionController.text.trim();

      final detallesJson = _detallesEgreso
          .where((d) => _toDouble(d['cantidad_egresada']) > 0)
          .map(
            (d) => {
              'item_contrato_id': d['id_item_contrato'],
              'cantidad': d['cantidad_egresada'],
              'precio_unitario': d['precio_unitario'],
            },
          )
          .toList();
      request.fields['detalles'] = jsonEncode(detallesJson);

      for (var file in _documentosSeleccionados) {
        if (file.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'documentos[]',
              file.bytes!,
              filename: file.name,
            ),
          );
        } else if (file.path != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'documentos[]',
              file.path!,
              filename: file.name,
            ),
          );
        }
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _documentosBloqueados = true; // BLOQUEAR DOCUMENTOS
        });
        _limpiarFormulario();
        _snack('✅ Egreso registrado exitosamente', Colors.green);
        await _cargarEgresos();
        setState(() => _mostrandoLista = true);
      } else {
        _snack('${data['message'] ?? 'Error desconocido'}', Colors.red);
      }
    } catch (e) {
      _snack('❌ Error de red: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // =================================================================
  // ACTUALIZACION CON MULTIPART
  // =================================================================
  Future<void> _actualizarEgreso() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_validarStock()) return;
    setState(() => _cargando = true);
    try {
      final uri = Uri.parse('$_baseUrl/egresos/actualizar_egreso.php');
      final request = http.MultipartRequest('POST', uri);

      request.fields['id'] = _egresoEditandoId.toString();
      request.fields['numero_egreso'] = _numeroEgresoController.text.trim();
      request.fields['id_bodega'] = BODEGA_FIJA_ID.toString();
      request.fields['fecha'] = _fechaEgresoController.text.trim();
      request.fields['observacion'] = _observacionController.text.trim();

      final detallesActualizados = _detallesEgreso
          .where((d) {
            final base = _toDouble(d['cantidad_egresada']);
            final adicional = _toDouble(d['cantidad_adicional']);
            return (base + adicional) > 0;
          })
          .map((d) {
            final base = _toDouble(d['cantidad_egresada']);
            final adicional = _toDouble(d['cantidad_adicional']);
            return {
              'item_contrato_id': d['id_item_contrato'],
              'cantidad': base + adicional,
              'precio_unitario': d['precio_unitario'],
            };
          })
          .toList();
      request.fields['detalles'] = jsonEncode(detallesActualizados);

      for (var file in _documentosSeleccionados) {
        if (file.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'documentos[]',
              file.bytes!,
              filename: file.name,
            ),
          );
        } else if (file.path != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'documentos[]',
              file.path!,
              filename: file.name,
            ),
          );
        }
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _documentosBloqueados = true; // BLOQUEAR DOCUMENTOS
        });
        _limpiarFormulario();
        _snack('✅ Egreso actualizado', Colors.green);
        await _cargarEgresos();
        setState(() => _mostrandoLista = true);
      } else {
        _snack('❌ ${data['message'] ?? 'Error al actualizar'}', Colors.red);
      }
    } catch (e) {
      _snack('❌ Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarEgreso(int id, String numero) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Egreso'),
        content: Text('¿Eliminar egreso #$numero?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cargando = true);
    try {
      final r = await http
          .post(
            Uri.parse('$_baseUrl/egresos/eliminar_egreso.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'id': id}),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        _snack('✅ Egreso eliminado', Colors.green);
        await _cargarEgresos();
      } else {
        _snack('❌ ${data['message'] ?? 'Error al eliminar'}', Colors.red);
      }
    } catch (e) {
      _snack('❌ Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _verDetalle(Map<String, dynamic> egreso) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
      ),
    );
    try {
      final r = await http
          .get(
            Uri.parse(
              '$_baseUrl/egresos/obtener_egreso.php?id=${egreso['id']}',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (mounted) Navigator.pop(context);
      final data = jsonDecode(r.body);
      if (r.statusCode == 200 && data['success'] == true) {
        _mostrarDialogoDetalle(
          data['data']['egreso'],
          List<Map<String, dynamic>>.from(data['data']['detalles']),
        );
      } else {
        _snack('❌ ${data['message'] ?? 'Error'}', Colors.red);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _snack('Error: $e', Colors.red);
    }
  }

  void _mostrarDialogoDetalle(
    Map<String, dynamic> eg,
    List<Map<String, dynamic>> detalles,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Egreso #${eg['numero_egreso'] ?? 'N/A'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
          child: SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Fecha', eg['fecha'] ?? 'N/A'),
                  _infoRow('Bodega', eg['bodega_nombre'] ?? 'N/A'),
                  _infoRow('Usuario', eg['usuario_nombre'] ?? 'N/A'),
                  if ((eg['observacion'] ?? '').toString().trim().isNotEmpty)
                    _infoRow('Obs.', eg['observacion'].toString().trim()),
                  const Divider(height: 24),
                  Text(
                    'Items del Egreso',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (detalles.isEmpty)
                    const Text(
                      'Sin items',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 12,
                        headingRowColor: WidgetStateProperty.all(
                          Colors.green.shade50,
                        ),
                        columns: const [
                          DataColumn(label: Text('#')),
                          DataColumn(label: Text('Item')),
                          DataColumn(label: Text('Cant. Contratada')),
                          DataColumn(label: Text('Cant. Ingresada')),
                          DataColumn(label: Text('Cant. Egresada')),
                          DataColumn(label: Text('Precio Unit.')),
                          DataColumn(label: Text('Subtotal')),
                        ],
                        rows: detalles.asMap().entries.map((e) {
                          final d = e.value;
                          final cantContratada = _toDouble(
                            d['cantidad_contratada'] ?? 0,
                          );
                          final cantIngresada = _toDouble(
                            d['cantidad_ingresada'] ?? cantContratada,
                          );
                          final cant = _toDouble(d['cantidad']);
                          final precio = _toDouble(d['precio_unitario']);

                          return DataRow(
                            cells: [
                              DataCell(Text('${e.key + 1}')),
                              DataCell(
                                Text(
                                  d['nombre_item'] ?? 'N/A',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Center(
                                  child: Text(_formatearNumero(cantContratada)),
                                ),
                              ),
                              DataCell(
                                Center(
                                  child: Text(_formatearNumero(cantIngresada)),
                                ),
                              ),
                              DataCell(
                                Center(child: Text(_formatearNumero(cant))),
                              ),
                              DataCell(
                                Center(
                                  child: Text(_formatearConPuntos(precio)),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatearConPuntos(cant * precio),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  if (detalles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _totalRow(detalles),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
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
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );

  Widget _totalRow(List<Map<String, dynamic>> detalles) {
    final total = detalles.fold(
      0.0,
      (sum, d) =>
          sum + _toDouble(d['cantidad']) * _toDouble(d['precio_unitario']),
    );
    return Container(
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            _formatearConPuntos(total),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cargarEgresoParaEditar(int egresoId) async {
    setState(() => _cargando = true);
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/egresos/obtener_egreso.php?id=$egresoId'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final egresoData = data['data']['egreso'];
        final detallesData = List<Map<String, dynamic>>.from(
          data['data']['detalles'] as List,
        );
        final String fechaRaw = egresoData['fecha'] ?? '';
        final String fechaEgreso = fechaRaw.length >= 10
            ? fechaRaw.substring(0, 10)
            : fechaRaw;

        final String anioContrato = fechaEgreso.length >= 4
            ? fechaEgreso.substring(0, 4)
            : '';

        await _cargarTodosLosContratos();
        final contratoIdDelEgreso =
            int.tryParse(egresoData['contrato_id']?.toString() ?? '0') ?? 0;
        final contratoEncontrado = _contratosDisponibles.firstWhere(
          (c) => _toInt(c['id']) == contratoIdDelEgreso,
          orElse: () => {},
        );

        if (contratoEncontrado.isNotEmpty) {
          await _cargarItemsContrato(contratoIdDelEgreso);
          setState(() {
            _modoEdicion = true;
            _egresoEditandoId = egresoId;
            _numeroEgresoController.text = egresoData['numero_egreso'] ?? '';
            _fechaEgresoController.text = fechaEgreso;
            _observacionController.text = egresoData['observacion'] ?? '';
            _anioSeleccionado = anioContrato;
            _contratoSeleccionado = contratoIdDelEgreso;
            _objetoContratoController.text =
                contratoEncontrado['objeto_contrato']?.toString() ??
                contratoEncontrado['objeto']?.toString() ??
                'No especificado';
            _documentosBloqueados = false; // Permitir edición de documentos

            for (var detalleEgreso in detallesData) {
              final itemId =
                  int.tryParse(
                    detalleEgreso['item_contrato_id']?.toString() ?? '0',
                  ) ??
                  0;
              final cantidadEgresada =
                  double.tryParse(
                    detalleEgreso['cantidad']?.toString() ?? '0',
                  ) ??
                  0.0;
              final index = _detallesEgreso.indexWhere(
                (d) => d['id_item_contrato'] == itemId,
              );
              if (index != -1) {
                _detallesEgreso[index]['cantidad_egresada'] = cantidadEgresada;
                _detallesEgreso[index]['cantidad_adicional'] = 0.0;
              }
            }

            //  CORREGIDO: Manejo seguro de documentos existentes
            if (data['data']['documentos'] != null) {
              final docsList = data['data']['documentos'] as List;
              _documentosExistentes = docsList.map((doc) {
                return {
                  'nombre': doc['nombre']?.toString() ?? '',
                  'ruta': doc['ruta']?.toString() ?? '',
                };
              }).toList();
            }

            _inicializarControllersCantidad();
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ El contrato #$contratoIdDelEgreso no existe'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        setState(() => _mostrandoLista = false);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Error al cargar egreso'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando egreso: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error detallado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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
          _egresosFiltrados = List.from(_egresos);
        });
      }
    } catch (e) {
      debugPrint('Error cargando egresos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _limpiarFormulario() {
    _numeroEgresoController.clear();
    _fechaEgresoController.clear();
    _observacionController.clear();
    _objetoContratoController.clear();
    for (final c in _cantidadControllers) {
      c.dispose();
    }
    _cantidadControllers = [];
    _anioSeleccionado = null;
    _contratoSeleccionado = null;
    _contratosDisponibles = [];
    _detallesEgreso = [];
    _modoEdicion = false;
    _egresoEditandoId = null;

    _documentosSeleccionados.clear();
    _documentosExistentes.clear();
    _documentosBloqueados = false; // DESBLOQUEAR al limpiar
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
    bool alignLabel = false,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    isDense: true,
    alignLabelWithHint: alignLabel,
  );

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
        selectedIndex: 4,
      ),
      body: Column(
        children: [
          _buildResponsiveHeader(verde, isMobile, isTablet),
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
                  ? _buildListaEgresos()
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 12 : 20),
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
                              padding: EdgeInsets.all(isMobile ? 16 : 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSeccionDatos(verde, isMobile),
                                  const SizedBox(height: 24),
                                  _buildSeccionDetalles(verde, isMobile),
                                  const SizedBox(height: 24),
                                  _buildSeccionDocumentos(verde),
                                  const SizedBox(height: 24),
                                  _buildBotones(verde),
                                ],
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

  // =================================================================
  // WIDGETS DE UI
  // =================================================================
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
                  if (!_modoEdicion)
                    Positioned(
                      right: 0,
                      child: SizedBox(
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _mostrandoLista = !_mostrandoLista);
                            if (_mostrandoLista) _cargarEgresos();
                          },
                          icon: Icon(
                            _mostrandoLista ? Icons.add : Icons.list,
                            color: Colors.white,
                            size: 16,
                          ),
                          label: Text(
                            _mostrandoLista ? 'Nuevo' : 'Listado',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mostrandoLista
                                ? verde
                                : Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ),
                  if (_modoEdicion)
                    Positioned(
                      right: 0,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 26,
                        ),
                        onPressed: () {
                          _limpiarFormulario();
                          setState(() => _mostrandoLista = true);
                        },
                        tooltip: 'Cancelar edicion',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _modoEdicion
                  ? 'Editar Egreso #$_egresoEditandoId'
                  : 'Registrar Egresos',
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                height: isTablet ? 100 : 130,
                fit: BoxFit.contain,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _modoEdicion
                    ? 'Editar Egreso #$_egresoEditandoId'
                    : 'Registrar Egresos',
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
                child: !_modoEdicion
                    ? SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _mostrandoLista = !_mostrandoLista);
                            if (_mostrandoLista) _cargarEgresos();
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
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 28,
                        ),
                        onPressed: () {
                          _limpiarFormulario();
                          setState(() => _mostrandoLista = true);
                        },
                        tooltip: 'Cancelar edicion',
                      ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSeccionDatos(Color verde, bool isMobile) {
    final usuarioField = TextFormField(
      initialValue: username,
      readOnly: true,
      enabled: false,
      decoration: InputDecoration(
        labelText: 'Usuario que registra',
        prefixIcon: const Icon(Icons.person, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );

    final numeroField = TextFormField(
      controller: _numeroEgresoController,
      decoration: _deco('Numero de Egreso *', hint: 'Ej: EGR-0001'),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Ingrese numero de egreso' : null,
    );

    final bodegaField = TextFormField(
      initialValue: BODEGA_FIJA_NOMBRE,
      readOnly: true,
      enabled: false,
      decoration: InputDecoration(
        labelText: 'Bodega',
        prefixIcon: const Icon(Icons.store, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        isDense: true,
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );

    final fechaField = TextFormField(
      controller: _fechaEgresoController,
      decoration: _deco('Fecha Egreso *', hint: 'YYYY-MM-DD'),
      readOnly: true,
      onTap: () => _pickDate(_fechaEgresoController),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Ingrese fecha' : null,
    );

    final anioField = DropdownButtonFormField<String>(
      value: _anioSeleccionado,
      hint: const Text('Selecciona año *'),
      isExpanded: true,
      items: _aniosDisponibles
          .map((a) => DropdownMenuItem(value: a, child: Text(a)))
          .toList(),
      onChanged: _modoEdicion
          ? null
          : (v) {
              setState(() {
                _anioSeleccionado = v;
                _contratoSeleccionado = null;
                _contratosDisponibles = [];
                _detallesEgreso = [];
                _objetoContratoController.clear();
              });
              if (v != null) _cargarContratosPorAnio(v);
            },
      decoration: _deco('Año contrato *'),
      validator: (v) => v == null ? 'Selecciona año' : null,
    );

    final contratoField = DropdownButtonFormField<int>(
      value:
          _contratoSeleccionado != null &&
              _contratosDisponibles.any(
                (c) => _toInt(c['id']) == _contratoSeleccionado,
              )
          ? _contratoSeleccionado
          : null,
      hint: const Text('Contrato *'),
      isExpanded: true,
      items: _contratosDisponibles
          .map(
            (c) => DropdownMenuItem<int>(
              value: _toInt(c['id']),
              child: Text(c['numero_contrato'] ?? ''),
            ),
          )
          .toList(),
      onChanged: _modoEdicion
          ? null
          : (v) {
              setState(() {
                _contratoSeleccionado = v;
                _detallesEgreso = [];
                final contratoSeleccionado = _contratosDisponibles.firstWhere(
                  (c) => _toInt(c['id']) == v,
                  orElse: () => {},
                );
                _objetoContratoController.text =
                    contratoSeleccionado['objeto_contrato']?.toString() ??
                    contratoSeleccionado['objeto']?.toString() ??
                    'No especificado';
              });
              if (v != null) _cargarItemsContrato(v);
            },
      decoration: _deco('Contrato *'),
      validator: (v) => v == null ? 'Seleccione contrato' : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: verde, size: 20),
            const SizedBox(width: 8),
            Text(
              'Datos del Egreso',
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
          usuarioField,
          const SizedBox(height: 14),
          numeroField,
          const SizedBox(height: 14),
          bodegaField,
          const SizedBox(height: 14),
          fechaField,
          const SizedBox(height: 14),
          anioField,
          const SizedBox(height: 14),
          contratoField,
        ] else ...[
          Row(
            children: [
              Expanded(child: usuarioField),
              const SizedBox(width: 14),
              Expanded(child: numeroField),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: bodegaField),
              const SizedBox(width: 14),
              Expanded(child: fechaField),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: anioField),
              const SizedBox(width: 14),
              Expanded(child: contratoField),
            ],
          ),
        ],
        const SizedBox(height: 14),
        TextFormField(
          controller: _objetoContratoController,
          readOnly: true,
          maxLines: 2,
          decoration: _deco('Objeto del Contrato', alignLabel: true).copyWith(
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _observacionController,
          maxLines: 3,
          minLines: 2,
          decoration: _deco('Observacion', alignLabel: true),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildSeccionDetalles(Color verde, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.list_alt, color: verde, size: 20),
            const SizedBox(width: 8),
            Text(
              'Detalles de Egreso',
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
                '${_detallesEgreso.length} items',
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
        if (_detallesEgreso.isEmpty)
          Container(
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
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                Text(
                  'Seleccione un contrato para cargar los items',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          )
        else
          isMobile ? _buildDetallesMobile(verde) : _buildDetallesDesktop(verde),
      ],
    );
  }

  Widget _buildDetallesMobile(Color verde) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _detallesEgreso.length,
      itemBuilder: (context, index) {
        final detalle = _detallesEgreso[index];
        final contratada = _toDouble(detalle['cantidad_contratada']);
        final ingresada = _toDouble(detalle['total_ingresado']);
        final baseEgresada = _modoEdicion
            ? _toDouble(detalle['cantidad_egresada'])
            : _toDouble(detalle['total_egresado']);
        final stock = _toDouble(detalle['stock_disponible']);
        final cantidadMostrar = _modoEdicion
            ? _toDouble(detalle['cantidad_adicional'])
            : _toDouble(detalle['cantidad_egresada']);
        final excede = _modoEdicion
            ? (cantidadMostrar > stock && cantidadMostrar > 0)
            : (cantidadMostrar > stock && cantidadMostrar > 0);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: verde.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: verde,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        detalle['nombre_item'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((detalle['descripcion'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      detalle['descripcion'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildBadge(
                      'Contratada',
                      _formatearNumero(contratada),
                      Colors.purple,
                    ),
                    _buildBadge(
                      'Ingresada',
                      _formatearNumero(ingresada),
                      Colors.blue,
                    ),
                    if (_modoEdicion)
                      _buildBadge(
                        'Base egresada',
                        _formatearNumero(baseEgresada),
                        Colors.orange,
                      ),
                    _buildBadge(
                      'Stock',
                      _formatearNumero(stock),
                      stock > 0 ? Colors.green : Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _modoEdicion ? 'Cantidad adicional:' : 'Cantidad a egresar:',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _cantidadControllers.length > index
                      ? _cantidadControllers[index]
                      : null,
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    fontSize: 13,
                    color: excede ? Colors.red.shade700 : Colors.black,
                  ),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    isDense: true,
                    filled: excede,
                    fillColor: excede ? Colors.red.shade50 : null,
                    errorText: excede ? 'Excede stock' : null,
                    errorStyle: const TextStyle(fontSize: 10),
                  ),
                  onChanged: (v) {
                    _actualizarCantidad(index, v);
                    setState(() {});
                  },
                ),
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

  Widget _buildDetallesDesktop(Color verde) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 12,
          headingRowHeight: 36,
          headingRowColor: WidgetStateProperty.all(Colors.green.shade50),
          columns: [
            DataColumn(
              label: Text(
                '#',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Item',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Cant. Contratada',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Cant. Ingresada',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Cant. Egresada (Base)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Stock Gobernacion',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
            ),
            DataColumn(
              label: Text(
                _modoEdicion ? 'Cant. Adicional *' : 'Cant. a Egresar *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
            ),
          ],
          rows: _detallesEgreso.asMap().entries.map((entry) {
            final i = entry.key;
            final detalle = entry.value;
            final contratada = _toDouble(detalle['cantidad_contratada']);
            final ingresada = _toDouble(detalle['total_ingresado']);
            final baseEgresada = _modoEdicion
                ? _toDouble(detalle['cantidad_egresada'])
                : _toDouble(detalle['total_egresado']);
            final adicional = _toDouble(detalle['cantidad_adicional']);
            final stock = _toDouble(detalle['stock_disponible']);
            final cantidadMostrar = _modoEdicion
                ? adicional
                : _toDouble(detalle['cantidad_egresada']);
            final excede = _modoEdicion
                ? (adicional > stock && adicional > 0)
                : (cantidadMostrar > stock && cantidadMostrar > 0);

            return DataRow(
              cells: [
                DataCell(
                  Text('${i + 1}', style: const TextStyle(fontSize: 12)),
                ),
                DataCell(
                  Text(
                    detalle['nombre_item'] ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Text(
                      _formatearNumero(contratada),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      _formatearNumero(ingresada),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _modoEdicion
                          ? Colors.orange.shade100
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _modoEdicion
                            ? Colors.orange.shade300
                            : Colors.orange.shade200,
                      ),
                    ),
                    child: Text(
                      _formatearNumero(baseEgresada),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: stock > 0
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: stock > 0
                            ? Colors.green.shade200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Text(
                      _formatearNumero(stock),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: stock > 0
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _cantidadControllers.length > i
                          ? _cantidadControllers[i]
                          : null,
                      keyboardType: TextInputType.number,
                      style: TextStyle(
                        fontSize: 12,
                        color: excede ? Colors.red.shade700 : Colors.black,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        isDense: true,
                        filled: excede,
                        fillColor: excede ? Colors.red.shade50 : null,
                        errorText: excede ? 'Excede' : null,
                        errorStyle: const TextStyle(fontSize: 9),
                      ),
                      onChanged: (v) => _actualizarCantidad(i, v),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBotones(Color verde) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _cargando
                ? null
                : () => _modoEdicion ? _actualizarEgreso() : _registrarEgreso(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _modoEdicion ? Colors.orange.shade700 : verde,
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
                    _modoEdicion ? 'ACTUALIZAR EGRESO' : 'REGISTRAR EGRESO',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
        if (_modoEdicion) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () {
                _limpiarFormulario();
                setState(() => _mostrandoLista = true);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cancelar Edicion',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildListaEgresos() {
    const Color verde = Color(0xFF2E7D32);
    if (_egresos.isEmpty && !_cargando) {
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
                  'No hay egresos registrados',
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
                  label: const Text('Nuevo Egreso'),
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
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: ' Buscar por numero, bodega, usuario...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filtrarEgresos();
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Total: ${_egresosFiltrados.length} egresos',
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ..._egresosFiltrados.map(
            (egreso) => InkWell(
              onTap: () => _verDetalle(egreso),
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
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Contrato: ${egreso['numero_contrato'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          // ✅ CORREGIDO: Mostrar solo la fecha sin la hora
                          Text(
                            (egreso['fecha'] ?? '').toString().split(' ')[0],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.store,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Bodega: ${egreso['bodega_nombre'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
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
                            'Items: ${egreso['total_items'] ?? 0}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Usuario: ${egreso['usuario_nombre'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _cargarEgresoParaEditar(_toInt(egreso['id'])),
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
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (rol == 'administrador' || rol == 'administrativo')
                            TextButton.icon(
                              onPressed: () => _eliminarEgreso(
                                _toInt(egreso['id']),
                                egreso['numero_egreso'] ?? '',
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
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
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
                _limpiarFormulario();
                setState(() => _mostrandoLista = false);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Volver al Formulario',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // SECCION DE DOCUMENTOS
  Widget _buildSeccionDocumentos(Color verde) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file, color: verde, size: 22),
            const SizedBox(width: 8),
            Text(
              'Documentos Justificantes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const Spacer(),
            Text(
              'Max. 2 MB por archivo',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Divider(height: 24),

        // 1. Archivos existentes (Modo Edicion)
        if (_documentosExistentes.isNotEmpty) ...[
          Text(
            'Archivos actuales registrados:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ..._documentosExistentes.map(
            (doc) => _buildFileCard(
              nombre: doc['nombre'] ?? 'Archivo',
              tamano: null,
              esNuevo: false,
              color: Colors.blue,
              rutaArchivo: doc['ruta'], // 🆕 PASAR LA RUTA PARA VISUALIZAR
              puedeEliminar:
                  (rol == 'administrador' || rol == 'administrativo'),
              onRemove: () {
                setState(() => _documentosExistentes.remove(doc));
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 2. Archivos nuevos seleccionados
        if (_documentosSeleccionados.isNotEmpty) ...[
          Text(
            'Nuevos archivos a subir:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          ..._documentosSeleccionados.asMap().entries.map((entry) {
            final index = entry.key;
            final file = entry.value;
            return _buildFileCard(
              nombre: file.name,
              tamano: file.size,
              esNuevo: true,
              color: Colors.green,
              fileData: file,
              puedeEliminar: !_documentosBloqueados,
              onRemove: () =>
                  setState(() => _documentosSeleccionados.removeAt(index)),
            );
          }),
          const SizedBox(height: 16),
        ],

        SizedBox(
          width: double.infinity,
          child: _cargandoArchivos
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: _seleccionarMultiplesDocumentos,
                  icon: const Icon(Icons.add_link),
                  label: const Text('Adjuntar documentos (PDF, JPG, PNG, DOC)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: verde),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
        ),

        if (_documentosSeleccionados.isEmpty &&
            _documentosExistentes.isEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_file, color: Colors.grey.shade400, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sin documentos adjuntos (opcional)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFileCard({
    required String nombre,
    required int? tamano,
    required bool esNuevo,
    required Color color,
    required VoidCallback onRemove,
    required bool puedeEliminar,
    PlatformFile? fileData,
    String? rutaArchivo,
  }) {
    final esImg = _esImagen(nombre);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              esImg ? Icons.image : Icons.picture_as_pdf,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  tamano != null
                      ? _formatBytes(tamano)
                      : 'Archivo registrado en sistema',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // 👁️ BOTON DE VISTA PREVIA (para nuevos)
          if (esNuevo && fileData != null)
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.blue, size: 22),
              onPressed: () => _previewDocumento(fileData),
              tooltip: 'Vista previa',
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          // 👁️ BOTON DE VISTA PREVIA (para existentes)
          if (!esNuevo && rutaArchivo != null)
            IconButton(
              icon: const Icon(Icons.visibility, color: Colors.blue, size: 22),
              onPressed: () => _previewDocumentoExistente(rutaArchivo, nombre),
              tooltip: 'Vista previa',
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          if (puedeEliminar) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red.shade400, size: 20),
              onPressed: onRemove,
              tooltip: 'Quitar archivo',
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _numeroEgresoController.dispose();
    _fechaEgresoController.dispose();
    _observacionController.dispose();
    _objetoContratoController.dispose();
    _searchController.dispose();
    for (final c in _cantidadControllers) {
      c.dispose();
    }
    super.dispose();
  }
}
