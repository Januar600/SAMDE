import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/drawer_menu.dart';

class ReporteProveedorHistorialPage extends StatefulWidget {
  const ReporteProveedorHistorialPage({super.key});

  @override
  State<ReporteProveedorHistorialPage> createState() =>
      _ReporteProveedorHistorialPageState();
}

class _ReporteProveedorHistorialPageState
    extends State<ReporteProveedorHistorialPage> {
  late String username;
  late String sector;
  late String rol;

  final TextEditingController _proveedorCtrl = TextEditingController();
  final TextEditingController _fechaInicioCtrl = TextEditingController();
  final TextEditingController _fechaFinCtrl = TextEditingController();

  String? _estadoSeleccionado;
  String? _rangoSeleccionado;

  final List<String> _estadosContrato = [
    'Todos los estados',
    'Activo',
    'Finalizado',
    'Suspendido',
  ];

  bool _cargando = false;
  bool _reporteGenerado = false;
  String? _errorMensaje;

  List<Map<String, dynamic>> _proveedores = [];
  Map<String, dynamic>? _resumen;

  static const String _baseUrl = 'http://localhost/samde_db/api';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
    username = map['username'] ?? 'Usuario';
    sector = map['sector'] ?? 'No Asignado';
    rol = map['rol'] ?? 'consulta';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generarReporte();
    });
  }

  @override
  void dispose() {
    _proveedorCtrl.dispose();
    _fechaInicioCtrl.dispose();
    _fechaFinCtrl.dispose();
    super.dispose();
  }

  void _establecerRangoRapido(String tipo) {
    final ahora = DateTime.now();
    DateTime inicio;
    DateTime fin;

    switch (tipo) {
      case 'hoy':
        inicio = DateTime(ahora.year, ahora.month, ahora.day);
        fin = ahora;
        break;
      case 'mes_actual':
        inicio = DateTime(ahora.year, ahora.month, 1);
        fin = ahora;
        break;
      case 'mes_anterior':
        inicio = DateTime(ahora.year, ahora.month - 1, 1);
        fin = DateTime(ahora.year, ahora.month, 0);
        break;
      case 'anio_actual':
        inicio = DateTime(ahora.year, 1, 1);
        fin = ahora;
        break;
      default:
        return;
    }

    setState(() {
      _rangoSeleccionado = tipo;
      _fechaInicioCtrl.text = inicio.toIso8601String().substring(0, 10);
      _fechaFinCtrl.text = fin.toIso8601String().substring(0, 10);
    });
  }

  Future<void> _generarReporte() async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
      _reporteGenerado = false;
    });

    try {
      String url = '$_baseUrl/reportes/reporte_proveedor_historial.php?';

      if (_proveedorCtrl.text.isNotEmpty) {
        url += 'busqueda=${Uri.encodeComponent(_proveedorCtrl.text)}&';
      }

      if (_estadoSeleccionado != null &&
          _estadoSeleccionado != 'Todos los estados') {
        url += 'estado=${Uri.encodeComponent(_estadoSeleccionado!)}&';
      }

      if (_fechaInicioCtrl.text.isNotEmpty && _fechaFinCtrl.text.isNotEmpty) {
        url +=
            'fecha_inicio=${_fechaInicioCtrl.text}&fecha_fin=${_fechaFinCtrl.text}&';
      }

      if (url.endsWith('&')) url = url.substring(0, url.length - 1);

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _proveedores = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _resumen = data['resumen'];
          _reporteGenerado = true;
        });
      } else {
        setState(() {
          _errorMensaje = data['message'] ?? 'Error al generar el reporte';
        });
      }
    } catch (e) {
      setState(() {
        _errorMensaje = 'Error de conexión: $e';
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'N/A';
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
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return Scaffold(
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 11,
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
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12 : 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFiltros(verde, isMobile),
                        const SizedBox(height: 24),
                        _buildContenido(verde, isMobile),
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
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Historial por Proveedor',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
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
              child: const Text(
                'Historial por Proveedor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
            const Expanded(flex: 2, child: SizedBox()),
          ],
        ),
      );
    }
  }

  Widget _buildFiltros(Color verde, bool isMobile) {
    // ✅ Campo de búsqueda con autocompletado
    final proveedorField = Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) async {
        final query = textEditingValue.text.trim();
        if (query.length < 2) return const Iterable<String>.empty();

        try {
          final response = await http
              .get(
                Uri.parse(
                  '$_baseUrl/reportes/obtener_proveedores.php?q=${Uri.encodeComponent(query)}',
                ),
              )
              .timeout(const Duration(seconds: 5));
          final data = jsonDecode(response.body);

          if (data['success'] == true) {
            final List<dynamic> proveedores = data['data'] ?? [];
            return proveedores.map((p) => p.toString());
          }
        } catch (e) {
          debugPrint('Error en autocompletado: $e');
        }

        return const Iterable<String>.empty();
      },
      onSelected: (String selection) {
        _proveedorCtrl.text = selection;
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Buscar Proveedor (Opcional)',
            hintText: 'Escribe el nombre del proveedor',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      controller.clear();
                      _proveedorCtrl.clear();
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (value) {
            _proveedorCtrl.text = value;
          },
          onFieldSubmitted: (value) {
            _proveedorCtrl.text = value;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: SizedBox(
                      height: 50,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(Icons.business, color: verde, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
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
        );
      },
    );

    final estadoField = DropdownButtonFormField<String>(
      value: _estadoSeleccionado ?? 'Todos los estados',
      decoration: const InputDecoration(
        labelText: 'Estado del Contrato (Opcional)',
        hintText: 'Todos los estados',
        suffixIcon: Icon(Icons.track_changes),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      isExpanded: true,
      items: _estadosContrato
          .map(
            (String estado) =>
                DropdownMenuItem<String>(value: estado, child: Text(estado)),
          )
          .toList(),
      onChanged: (String? newValue) =>
          setState(() => _estadoSeleccionado = newValue),
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: verde, size: isMobile ? 22 : 28),
                const SizedBox(width: 12),
                Text(
                  'Filtros de Búsqueda',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: verde,
                  ),
                ),
              ],
            ),
            Divider(height: isMobile ? 24 : 32),
            if (isMobile) ...[
              proveedorField,
              const SizedBox(height: 16),
              estadoField,
            ] else ...[
              Row(
                children: [
                  Expanded(flex: 2, child: proveedorField),
                  const SizedBox(width: 16),
                  Expanded(child: estadoField),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Rangos rápidos:',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (isMobile)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildRangoButton('Hoy', 'hoy', isMobile),
                  _buildRangoButton('Este Mes', 'mes_actual', isMobile),
                  _buildRangoButton('Mes Anterior', 'mes_anterior', isMobile),
                  _buildRangoButton('Este Año', 'anio_actual', isMobile),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: _buildRangoButton('Hoy', 'hoy', isMobile)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRangoButton(
                      'Este Mes',
                      'mes_actual',
                      isMobile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRangoButton(
                      'Mes Anterior',
                      'mes_anterior',
                      isMobile,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRangoButton(
                      'Este Año',
                      'anio_actual',
                      isMobile,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            if (isMobile) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cargando ? null : _generarReporte,
                  icon: _cargando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.filter_alt, size: 20),
                  label: const Text(
                    'FILTRAR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verde,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _proveedorCtrl.clear();
                      _fechaInicioCtrl.clear();
                      _fechaFinCtrl.clear();
                      _estadoSeleccionado = null;
                      _rangoSeleccionado = null;
                    });
                    _generarReporte();
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _cargando ? null : _generarReporte,
                      icon: _cargando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.filter_alt, size: 20),
                      label: const Text(
                        'FILTRAR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _proveedorCtrl.clear();
                          _fechaInicioCtrl.clear();
                          _fechaFinCtrl.clear();
                          _estadoSeleccionado = null;
                          _rangoSeleccionado = null;
                        });
                        _generarReporte();
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpiar'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangoButton(String label, String tipo, bool isMobile) {
    final bool seleccionado = _rangoSeleccionado == tipo;
    const Color verde = Color(0xFF2E7D32);
    return OutlinedButton(
      onPressed: () => _establecerRangoRapido(tipo),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 8 : 8,
          horizontal: isMobile ? 12 : 0,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        backgroundColor: seleccionado ? verde : Colors.white,
        foregroundColor: seleccionado ? Colors.white : Colors.grey.shade700,
        side: BorderSide(
          color: seleccionado ? verde : Colors.grey.shade400,
          width: seleccionado ? 2 : 1,
        ),
        elevation: seleccionado ? 2 : 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (seleccionado) ...[
            const Icon(Icons.check, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido(Color verde, bool isMobile) {
    if (_cargando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: Colors.green),
        ),
      );
    }

    if (_errorMensaje != null) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMensaje!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_reporteGenerado) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Cargando historial...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_resumen != null) ...[
          if (isMobile) ...[
            _buildResumenCard(
              'Total Proveedores',
              '${_resumen!['total_proveedores']}',
              Icons.business,
              Colors.blue,
              isMobile,
            ),
            const SizedBox(height: 12),
            _buildResumenCard(
              'Total Actas',
              '${_resumen!['total_actas']}',
              Icons.description,
              Colors.orange,
              isMobile,
            ),
            const SizedBox(height: 12),
            _buildResumenCard(
              'Total Items',
              '${_resumen!['total_items']}',
              Icons.inventory_2,
              Colors.green,
              isMobile,
            ),
          ] else
            Row(
              children: [
                _buildResumenCard(
                  'Total Proveedores',
                  '${_resumen!['total_proveedores']}',
                  Icons.business,
                  Colors.blue,
                  isMobile,
                ),
                const SizedBox(width: 16),
                _buildResumenCard(
                  'Total Actas',
                  '${_resumen!['total_actas']}',
                  Icons.description,
                  Colors.orange,
                  isMobile,
                ),
                const SizedBox(width: 16),
                _buildResumenCard(
                  'Total Items',
                  '${_resumen!['total_items']}',
                  Icons.inventory_2,
                  Colors.green,
                  isMobile,
                ),
              ],
            ),
          const SizedBox(height: 24),
        ],
        if (_proveedores.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No se encontraron actas con estos filtros',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _buildListaProveedores(verde, isMobile),
      ],
    );
  }

  Widget _buildListaProveedores(Color verde, bool isMobile) {
    return Column(
      children: _proveedores.map((proveedor) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.grey.shade50,
            leading: CircleAvatar(
              backgroundColor: verde.withValues(alpha: 0.1),
              child: Icon(Icons.history, color: verde, size: 24),
            ),
            title: Text(
              proveedor['proveedor'] ?? 'N/A',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: verde,
                fontSize: isMobile ? 14 : 16,
              ),
            ),
            subtitle: Text(
              '${proveedor['total_actas']} actas · ${proveedor['total_items']} items',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  children: (proveedor['actas'] as List).map((acta) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Acta #${acta['numero_acta']} (Contrato ${acta['numero_contrato']})',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDate(acta['fecha_entrega']),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Entregado a: ${acta['entregado_a'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Área: ${acta['area_dependencia'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                size: 16,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${acta['total_items']} items · Cant: ${acta['total_cantidad']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResumenCard(
    String titulo,
    String valor,
    IconData icono,
    Color color,
    bool isMobile,
  ) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 10 : 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: color, size: isMobile ? 24 : 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valor,
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
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
}
