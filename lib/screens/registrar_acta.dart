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
  // ✅ CORRECCIÓN: GlobalKey para controlar el Scaffold y abrir el drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;
  bool _mostrandoLista = false;
  List<Map<String, dynamic>> _actas = [];

  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _numeroActaController = TextEditingController();
  final _fechaController = TextEditingController();
  final _responsableController = TextEditingController();

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

  // ============================================
  // MÉTODOS (registrar, cargar, eliminar, etc.)
  // ============================================
  Future<void> _registrarActa() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    final url = Uri.parse('http://localhost/samde_db/api/registrar_acta.php');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'numero_acta': _numeroActaController.text.trim(),
          'titulo': _tituloController.text.trim(),
          'descripcion': _descripcionController.text.trim(),
          'fecha': _fechaController.text.trim(),
          'responsable': _responsableController.text.trim(),
          'usuario_registro': username,
          'sector': sector,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _limpiarFormulario();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Acta registrada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        await _cargarActas();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['mensaje'] ?? 'Error al registrar acta'),
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

  Future<void> _cargarActas() async {
    setState(() => _cargando = true);
    final url = Uri.parse('http://localhost/samde_db/api/listar_actas.php');

    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          _actas = List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
      }
    } catch (e) {
      print('Error cargando actas: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _limpiarFormulario() {
    _tituloController.clear();
    _descripcionController.clear();
    _numeroActaController.clear();
    _fechaController.clear();
    _responsableController.clear();
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
        _fechaController.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  Future<void> _eliminarActa(int id) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar Acta'),
          content: const Text(
            '¿Estás seguro de que deseas eliminar esta acta?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                final url = Uri.parse(
                  'http://localhost/samde_db/api/eliminar_acta.php',
                );
                try {
                  final response = await http.post(
                    url,
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({'id': id}),
                  );
                  final data = jsonDecode(response.body);
                  if (response.statusCode == 200 &&
                      data['status'] == 'success') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Acta eliminada'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _cargarActas();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error de conexión: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================
  // CONFIRMAR CIERRE DE SESIÓN
  // ============================================

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    _numeroActaController.dispose();
    _fechaController.dispose();
    _responsableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);

    return Scaffold(
      // ✅ CORRECCIÓN: key asignada al Scaffold
      key: _scaffoldKey,
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
                // ✅ CORRECCIÓN: usa _scaffoldKey igual que menu_navegacion.dart
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
                // Logo
                Image.asset(
                  'assets/logos/banner_gobernacion.png',
                  height: 110,
                  fit: BoxFit.contain,
                ),
                // Título centrado
                const Expanded(
                  child: Center(
                    child: Text(
                      'Registrar Actas',
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
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _mostrandoLista ? _buildListaActas() : _buildFormulario(),
                      const SizedBox(height: 16),

                      // ============================================
                      // BOTÓN VOLVER
                      // ============================================
                      SizedBox(
                        width: double.infinity,
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Volver al Menú Principal',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
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
  // CONSTRUIR FORMULARIO
  // ============================================
  Widget _buildFormulario() {
    const Color verdeInstitucional = Color(0xFF2E7D32);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.description, color: verdeInstitucional, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Registrar Acta de Entrega',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: verdeInstitucional,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              TextFormField(
                controller: _numeroActaController,
                decoration: const InputDecoration(
                  labelText: 'Número de Acta',
                  prefixIcon: Icon(Icons.numbers),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese el número de acta'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Título del Acta',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese el título'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese una descripción'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fechaController,
                decoration: InputDecoration(
                  labelText: 'Fecha (DD/MM/YYYY)',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _seleccionarFecha(context),
                  ),
                ),
                readOnly: true,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Seleccione una fecha'
                    : null,
                onTap: () => _seleccionarFecha(context),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _responsableController,
                decoration: const InputDecoration(
                  labelText: 'Responsable',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingrese el responsable'
                    : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _registrarActa,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verdeInstitucional,
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
                          'REGISTRAR ACTA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // CONSTRUIR LISTA DE ACTAS
  // ============================================
  Widget _buildListaActas() {
    const Color verdeInstitucional = Color(0xFF2E7D32);

    if (_actas.isEmpty && !_cargando) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No hay actas registradas',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Registra una nueva acta para comenzar',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total: ${_actas.length} actas',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        ..._actas.map((acta) {
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: verdeInstitucional.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Acta #${acta['numero_acta'] ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: verdeInstitucional,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        acta['fecha'] ?? 'Sin fecha',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    acta['titulo'] ?? 'Sin título',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    acta['descripcion'] ?? 'Sin descripción',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        acta['responsable'] ?? 'Sin responsable',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      if (rol == 'admin')
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Colors.red.shade300,
                            size: 20,
                          ),
                          onPressed: () => _eliminarActa(acta['id'] ?? 0),
                          tooltip: 'Eliminar acta',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}
