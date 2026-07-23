import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/drawer_menu.dart';

class RegistrarActaPage extends StatefulWidget {
  const RegistrarActaPage({super.key});

  @override
  State<RegistrarActaPage> createState() => _RegistrarActaPageState();
}

class _RegistrarActaPageState extends State<RegistrarActaPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;
  bool _mostrandoFormulario = true;

  // Controladores para el formulario
  final _idActaController = TextEditingController();
  final _consecutivoController = TextEditingController();
  final _fechaActaController = TextEditingController();
  final _responsableController = TextEditingController();
  final _recibeController = TextEditingController();
  final _observacionesController = TextEditingController();

  // Detalles de entrega
  List<Map<String, dynamic>> _detalles = [];
  final _idDetalleController = TextEditingController();
  final _nombreItemController = TextEditingController();
  final _cantidadEntregaController = TextEditingController();
  final _cantidadDisponibleController = TextEditingController();
  final _cantidadContratadaController = TextEditingController();
  final _cantidadYaEntregadaController = TextEditingController();

  late String username;
  late String sector;
  late String rol;

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

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() {
        _fechaActaController.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  void _agregarDetalle() {
    if (_nombreItemController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese el nombre del ítem'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _detalles.add({
        'idDetalleActa': _idDetalleController.text.trim() ?? '(Nuevo)',
        'nombreItem': _nombreItemController.text.trim(),
        'idActa': _idActaController.text.trim(),
        'cantidadEntrega': int.tryParse(_cantidadEntregaController.text) ?? 0,
        'cantidadDisponible':
            int.tryParse(_cantidadDisponibleController.text) ?? 0,
        'cantidadContratada':
            int.tryParse(_cantidadContratadaController.text) ?? 0,
        'cantidadYaEntregada':
            int.tryParse(_cantidadYaEntregadaController.text) ?? 0,
      });
    });

    // Limpiar campos de detalle
    _idDetalleController.clear();
    _nombreItemController.clear();
    _cantidadEntregaController.clear();
    _cantidadDisponibleController.clear();
    _cantidadContratadaController.clear();
    _cantidadYaEntregadaController.clear();
  }

  void _eliminarDetalle(int index) {
    setState(() {
      _detalles.removeAt(index);
    });
  }

  Future<void> _guardarEntrega() async {
    if (_idActaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese el ID del Acta'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_detalles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agregue al menos un detalle de entrega'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    final url = Uri.parse(
      'http://localhost/samde_db/api/registrar_entrega.php',
    );

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'idActa': _idActaController.text.trim(),
          'consecutivoActa': _consecutivoController.text.trim(),
          'fechaActa': _fechaActaController.text.trim(),
          'responsable': _responsableController.text.trim(),
          'recibe': _recibeController.text.trim(),
          'observaciones': _observacionesController.text.trim(),
          'detalles': _detalles,
          'usuario_registro': username,
          'sector': sector,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _limpiarFormulario();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Entrega registrada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['mensaje'] ?? 'Error al registrar entrega'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _limpiarFormulario() {
    _idActaController.clear();
    _consecutivoController.clear();
    _fechaActaController.clear();
    _responsableController.clear();
    _recibeController.clear();
    _observacionesController.clear();
    _detalles.clear();
    _idDetalleController.clear();
    _nombreItemController.clear();
    _cantidadEntregaController.clear();
    _cantidadDisponibleController.clear();
    _cantidadContratadaController.clear();
    _cantidadYaEntregadaController.clear();
  }

  @override
  void dispose() {
    _idActaController.dispose();
    _consecutivoController.dispose();
    _fechaActaController.dispose();
    _responsableController.dispose();
    _recibeController.dispose();
    _observacionesController.dispose();
    _idDetalleController.dispose();
    _nombreItemController.dispose();
    _cantidadEntregaController.dispose();
    _cantidadDisponibleController.dispose();
    _cantidadContratadaController.dispose();
    _cantidadYaEntregadaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);

    return Scaffold(
      key: _scaffoldKey,
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 5,
      ),
      body: Column(
        children: [
          // ============================================
          // BANNER INSTITUCIONAL (SIN CAMBIOS)
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
                IconButton(
                  icon: Icon(Icons.menu, color: verdeInstitucional, size: 30),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                  tooltip: 'Abrir menú',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                      'Entrega de Actas',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // ============================================
                    // FORMULARIO PRINCIPAL - ESTILO IMAGEN
                    // ============================================
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Título
                              Row(
                                children: [
                                  Icon(
                                    Icons.assignment,
                                    color: verdeInstitucional,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Registrar Entrega de Acta',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: verdeInstitucional,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              // Campos principales
                              _buildCampoTexto(
                                'IdActa (Nuevo)',
                                controller: _idActaController,
                                hint: 'Nuevo',
                              ),
                              const SizedBox(height: 12),

                              _buildCampoConBoton(
                                'ConsecutivoActa',
                                controller: _consecutivoController,
                                hint: 'Cargar Acta de Entrega',
                              ),
                              const SizedBox(height: 12),

                              _buildCampoFecha(
                                'FechaActa',
                                controller: _fechaActaController,
                              ),
                              const SizedBox(height: 12),

                              _buildCampoTexto(
                                'ResponsableEntrega',
                                controller: _responsableController,
                              ),
                              const SizedBox(height: 12),

                              _buildCampoTexto(
                                'Recibe',
                                controller: _recibeController,
                              ),
                              const SizedBox(height: 12),

                              _buildCampoTexto(
                                'Observaciones',
                                controller: _observacionesController,
                                maxLines: 2,
                              ),
                              const SizedBox(height: 12),

                              // Fecha de creación automática
                              Row(
                                children: [
                                  const Text(
                                    'FechaCreacion',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '25/06/2026',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ============================================
                    // SECCIÓN DETALLES DE ENTREGA
                    // ============================================
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Detalles de Entrega',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: verdeInstitucional,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Tabla de detalles
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  // Encabezados
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        topRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildHeaderCell(
                                          'IdDetalleActa',
                                          flex: 1,
                                        ),
                                        _buildHeaderCell(
                                          'Nombre Item',
                                          flex: 2,
                                        ),
                                        _buildHeaderCell('IdActa', flex: 1),
                                        _buildHeaderCell(
                                          'Cant. Entrega',
                                          flex: 1,
                                        ),
                                        _buildHeaderCell(
                                          'Cant. Disponible',
                                          flex: 1,
                                        ),
                                        _buildHeaderCell(
                                          'Cant. Contratada',
                                          flex: 1,
                                        ),
                                        _buildHeaderCell(
                                          'Cant. ya Entregada',
                                          flex: 1,
                                        ),
                                        const SizedBox(width: 30),
                                      ],
                                    ),
                                  ),
                                  // Filas de detalles
                                  ..._detalles.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    var detalle = entry.value;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildCell(
                                            detalle['idDetalleActa'] ??
                                                '(Nuevo)',
                                            flex: 1,
                                          ),
                                          _buildCell(
                                            detalle['nombreItem'] ?? '',
                                            flex: 2,
                                          ),
                                          _buildCell(
                                            detalle['idActa'] ?? '',
                                            flex: 1,
                                          ),
                                          _buildCell(
                                            detalle['cantidadEntrega']
                                                    ?.toString() ??
                                                '0',
                                            flex: 1,
                                          ),
                                          _buildCell(
                                            detalle['cantidadDisponible']
                                                    ?.toString() ??
                                                '0',
                                            flex: 1,
                                          ),
                                          _buildCell(
                                            detalle['cantidadContratada']
                                                    ?.toString() ??
                                                '0',
                                            flex: 1,
                                          ),
                                          _buildCell(
                                            detalle['cantidadYaEntregada']
                                                    ?.toString() ??
                                                '0',
                                            flex: 1,
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: Colors.red.shade300,
                                              size: 18,
                                            ),
                                            onPressed: () =>
                                                _eliminarDetalle(index),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  if (_detalles.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 20,
                                      ),
                                      child: Text(
                                        'No hay detalles registrados',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                  // Registro y búsqueda
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      border: Border(
                                        top: BorderSide(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'Registro: ${_detalles.length} de ${_detalles.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Text(
                                          'Sin filtro',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Buscar',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Campos para agregar nuevo detalle
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Agregar Detalle',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: verdeInstitucional,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: _buildDetalleField(
                                          'IdDetalle',
                                          _idDetalleController,
                                          hint: '(Nuevo)',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: _buildDetalleField(
                                          'Nombre Item',
                                          _nombreItemController,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: _buildDetalleField(
                                          'Cant. Entrega',
                                          _cantidadEntregaController,
                                          isNumber: true,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: _buildDetalleField(
                                          'Cant. Disponible',
                                          _cantidadDisponibleController,
                                          isNumber: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: _buildDetalleField(
                                          'Cant. Contratada',
                                          _cantidadContratadaController,
                                          isNumber: true,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: _buildDetalleField(
                                          'Cant. ya Entregada',
                                          _cantidadYaEntregadaController,
                                          isNumber: true,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: _agregarDetalle,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: verdeInstitucional,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text('Agregar'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Botones Guardar y Volver
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _cargando
                                        ? null
                                        : _guardarEntrega,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: verdeInstitucional,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
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
                                            'GUARDAR ENTREGA',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/menu',
                                        arguments: {
                                          'username': username,
                                          'sector': sector,
                                          'rol': rol,
                                        },
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade300,
                                      foregroundColor: Colors.black87,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Volver al Menú',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // WIDGETS AUXILIARES
  // ============================================

  Widget _buildCampoTexto(
    String label, {
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
    );
  }

  Widget _buildCampoConBoton(
    String label, {
    required TextEditingController controller,
    String? hint,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            // Acción para cargar acta de entrega
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cargar Acta de Entrega'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade300,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: const Text('Cargar'),
        ),
      ],
    );
  }

  Widget _buildCampoFecha(
    String label, {
    required TextEditingController controller,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today, size: 20),
                onPressed: () => _seleccionarFecha(context),
              ),
            ),
            readOnly: true,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Seleccione fecha' : null,
            onTap: () => _seleccionarFecha(context),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDetalleField(
    String label,
    TextEditingController controller, {
    String? hint,
    bool isNumber = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        isDense: true,
      ),
      style: const TextStyle(fontSize: 12),
    );
  }
}
