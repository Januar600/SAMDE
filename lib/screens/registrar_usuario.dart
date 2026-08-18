import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/drawer_menu.dart';

class RegistrarUsuario extends StatefulWidget {
  const RegistrarUsuario({super.key});

  @override
  State<RegistrarUsuario> createState() => _RegistrarUsuarioState();
}

class _RegistrarUsuarioState extends State<RegistrarUsuario> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();

  String _rolSeleccionado = 'consulta';
  String _sectorSeleccionado = 'Agropecuario';
  List<dynamic> listaUsuarios = [];
  bool _cargando = false;

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

  @override
  void initState() {
    super.initState();
    _obtenerUsuarios();
  }

  void _mostrarAdvertenciaRequisitos(String mensaje) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
              SizedBox(width: 10),
              Text(
                'Requisitos Insuficientes',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(mensaje, style: const TextStyle(fontSize: 15)),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Entendido',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _obtenerUsuarios() async {
    setState(() => _cargando = true);
    final url = Uri.parse("http://localhost/samde_db/api/listar_usuarios.php");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() => listaUsuarios = data['usuarios']);
        }
      } else {
        _mostrarSnackBar("Error en el servidor al listar usuarios.");
      }
    } catch (e) {
      _mostrarSnackBar("Error de conexión: $e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _registrarUsuario() async {
    if (_usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _contrasenaController.text.isEmpty) {
      _mostrarAdvertenciaRequisitos(
        "Todos los campos del formulario son obligatorios.",
      );
      return;
    }
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(_emailController.text.trim())) {
      _mostrarAdvertenciaRequisitos(
        "El correo electrónico no tiene un formato válido.",
      );
      return;
    }
    final url = Uri.parse("http://localhost/samde_db/api/password_hash.php");
    try {
      final response = await http.post(
        url,
        body: {
          "username": _usernameController.text,
          "email": _emailController.text.trim(),
          "contraseña": _contrasenaController.text,
          "rol": _rolSeleccionado,
          "sector": _sectorSeleccionado,
        },
      );
      final data = json.decode(response.body);
      if (data['status'] == 'success') {
        _mostrarSnackBar("Usuario registrado exitosamente.");
        _usernameController.clear();
        _emailController.clear();
        _contrasenaController.clear();
        _obtenerUsuarios();
      } else {
        _mostrarAdvertenciaRequisitos("Error del Servidor: ${data['mensaje']}");
      }
    } catch (e) {
      _mostrarSnackBar("Error al registrar: $e");
    }
  }

  Future<void> _cambiarEstadoUsuario(int id, int nuevoEstado) async {
    final copiaUsuariosAnteriores = List<dynamic>.from(listaUsuarios);
    setState(() {
      final index = listaUsuarios.indexWhere((u) => u['id'] == id);
      if (index != -1) listaUsuarios[index]['estado'] = nuevoEstado;
    });
    final url = Uri.parse("http://localhost/samde_db/api/cambiar_estado.php");
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: {"id": id.toString(), "estado": nuevoEstado.toString()},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          _obtenerUsuarios();
        } else {
          setState(() => listaUsuarios = copiaUsuariosAnteriores);
          _mostrarAdvertenciaRequisitos(
            "No se pudo cambiar el estado: ${data['mensaje']}",
          );
        }
      } else {
        setState(() => listaUsuarios = copiaUsuariosAnteriores);
        _mostrarSnackBar("Error de comunicación.");
      }
    } catch (e) {
      setState(() => listaUsuarios = copiaUsuariosAnteriores);
      _mostrarSnackBar("Error de red: Sin conexión.");
    }
  }

  void _mostrarFormularioEditar(dynamic usuario) {
    final editUsernameController = TextEditingController(
      text: usuario['username'],
    );
    final editEmailController = TextEditingController(text: usuario['email']);
    final editPasswordController = TextEditingController();
    bool ocultarPassword = true;
    String editRolSeleccionado = usuario['rol'] ?? 'consulta';
    String editSectorSeleccionado = 'No Asignado';
    if (usuario['sector'] != null && usuario['sector'].toString().isNotEmpty) {
      String sectorBd = usuario['sector'].toString();
      if ([
        'Medio Ambiente',
        'Agropecuario',
        'Desarrollo Económico',
      ].contains(sectorBd)) {
        editSectorSeleccionado = sectorBd;
      }
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 10),
                  Text('Editar Usuario'),
                ],
              ),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      TextField(
                        controller: editUsernameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de Usuario',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: editEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: editPasswordController,
                        obscureText: ocultarPassword,
                        decoration: InputDecoration(
                          labelText: 'Nueva Contraseña',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              ocultarPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                ocultarPassword = !ocultarPassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Rol del Usuario',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: editRolSeleccionado,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'administrador',
                                child: Text('ADMINISTRADOR'),
                              ),
                              DropdownMenuItem(
                                value: 'administrativo',
                                child: Text('ADMINISTRATIVO'),
                              ),
                              DropdownMenuItem(
                                value: 'almacen',
                                child: Text('ALMACEN'),
                              ),
                              DropdownMenuItem(
                                value: 'consulta',
                                child: Text('CONSULTA'),
                              ),
                            ],
                            onChanged: (value) => setDialogState(
                              () => editRolSeleccionado = value!,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Sector',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: editSectorSeleccionado,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'No Asignado',
                                child: Text('NO ASIGNADO'),
                              ),
                              DropdownMenuItem(
                                value: 'Medio Ambiente',
                                child: Text('MEDIO AMBIENTE'),
                              ),
                              DropdownMenuItem(
                                value: 'Agropecuario',
                                child: Text('AGROPECUARIO'),
                              ),
                              DropdownMenuItem(
                                value: 'Desarrollo Económico',
                                child: Text('DESARROLLO ECONÓMICO'),
                              ),
                            ],
                            onChanged: (value) => setDialogState(
                              () => editSectorSeleccionado = value!,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  onPressed: () async {
                    if (editUsernameController.text.isEmpty ||
                        editEmailController.text.isEmpty) {
                      _mostrarAdvertenciaRequisitos(
                        "No puedes guardar un usuario con campos vacíos.",
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    await _actualizarUsuario(
                      usuario['id'],
                      editUsernameController.text,
                      editEmailController.text.trim(),
                      editRolSeleccionado,
                      editSectorSeleccionado,
                      editPasswordController.text,
                    );
                  },
                  child: const Text(
                    'Guardar Cambios',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _actualizarUsuario(
    int id,
    String username,
    String email,
    String rol,
    String sector,
    String password,
  ) async {
    final url = Uri.parse("http://localhost/samde_db/api/editar_usuario.php");
    try {
      final response = await http.post(
        url,
        body: {
          "id": id.toString(),
          "username": username,
          "email": email,
          "rol": rol,
          "sector": sector,
          "password": password,
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          _mostrarSnackBar("Usuario actualizado con éxito.");
          _obtenerUsuarios();
        } else {
          _mostrarAdvertenciaRequisitos("Error: ${data['mensaje']}");
        }
      } else {
        _mostrarSnackBar("Error del Servidor Código: ${response.statusCode}");
      }
    } catch (e) {
      _mostrarSnackBar("Error de red: $e");
    }
  }

  void _confirmarEliminacion(int id, String username) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ocultar Usuario"),
        content: Text("¿Seguro que deseas enviar a $username a la papelera?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cambiarEstadoUsuario(id, 3);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarPapeleraDialog() {
    List usuariosEliminados = listaUsuarios
        .where((u) => u['estado'] == 3)
        .toList();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.delete_sweep, color: Colors.red),
              SizedBox(width: 10),
              Text('Papelera de Usuarios'),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
            child: SizedBox(
              width: double.infinity,
              height: 400,
              child: usuariosEliminados.isEmpty
                  ? const Center(
                      child: Text(
                        'La papelera está vacía.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: usuariosEliminados.length,
                      itemBuilder: (context, index) {
                        final usuario = usuariosEliminados[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          color: Colors.grey[100],
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Colors.grey,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        usuario['username'] ?? 'Sin usuario',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        usuario['email'] ?? 'Sin correo',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.settings_backup_restore,
                                    color: Colors.green,
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                    _cambiarEstadoUsuario(usuario['id'], 1);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarSnackBar(String mensaje) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    List usuariosVisibles = listaUsuarios
        .where((u) => u['estado'] == 1 || u['estado'] == 2)
        .toList();
    const Color verdeInstitucional = Color(0xFF2E7D32);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      key: _scaffoldKey,
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 1,
      ),
      body: Column(
        children: [
          _buildResponsiveHeader(verdeInstitucional, isMobile),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (isMobile) {
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildFormulario(verdeInstitucional, isMobile),
                        const Divider(height: 1),
                        _buildListado(
                          verdeInstitucional,
                          usuariosVisibles,
                          isMobile,
                        ),
                      ],
                    ),
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildFormulario(verdeInstitucional, isMobile),
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      Expanded(
                        flex: 3,
                        child: _buildListado(
                          verdeInstitucional,
                          usuariosVisibles,
                          isMobile,
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarPapeleraDialog,
        backgroundColor: const Color.fromARGB(255, 227, 6, 6),
        child: const Icon(Icons.delete_sweep, color: Colors.white),
      ),
    );
  }

  Widget _buildResponsiveHeader(Color verdeInstitucional, bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 192, 231, 195),
          border: Border(
            bottom: BorderSide(color: verdeInstitucional, width: 3),
          ),
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
                    child: IconButton(
                      icon: Icon(
                        Icons.menu,
                        color: verdeInstitucional,
                        size: 28,
                      ),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      tooltip: 'Abrir menú',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gestión de Usuarios y Roles',
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 192, 231, 195),
          border: Border(
            bottom: BorderSide(color: verdeInstitucional, width: 4),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.menu, color: verdeInstitucional, size: 30),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Abrir menú',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: Image.asset(
                'assets/logos/banner_gobernacion.png',
                height: 130,
                fit: BoxFit.contain,
              ),
            ),
            Expanded(
              flex: 2,
              child: const Text(
                'Gestión de Usuarios y Roles',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
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

  Widget _buildFormulario(Color verdeInstitucional, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Icon(
              Icons.person_add,
              size: isMobile ? 60 : 80,
              color: verdeInstitucional,
            ),
            const SizedBox(height: 10),
            Text(
              'REGISTRAR NUEVO USUARIO',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: verdeInstitucional,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de Usuario',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Correo Electrónico',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contrasenaController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Rol del Usuario',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _rolSeleccionado,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'administrador',
                      child: Text('ADMINISTRADOR'),
                    ),
                    DropdownMenuItem(
                      value: 'administrativo',
                      child: Text('ADMINISTRATIVO'),
                    ),
                    DropdownMenuItem(value: 'almacen', child: Text('ALMACEN')),
                    DropdownMenuItem(
                      value: 'consulta',
                      child: Text('CONSULTA'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _rolSeleccionado = value!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Sector',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sectorSeleccionado,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'No Asignado',
                      child: Text('NO ASIGNADO'),
                    ),
                    DropdownMenuItem(
                      value: 'Medio Ambiente',
                      child: Text('MEDIO AMBIENTE'),
                    ),
                    DropdownMenuItem(
                      value: 'Agropecuario',
                      child: Text('AGROPECUARIO'),
                    ),
                    DropdownMenuItem(
                      value: 'Desarrollo Económico',
                      child: Text('DESARROLLO ECONÓMICO'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _sectorSeleccionado = value!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _registrarUsuario,
                child: const Text(
                  'GUARDAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListado(
    Color verdeInstitucional,
    List usuariosVisibles,
    bool isMobile,
  ) {
    final Widget lista = _cargando
        ? const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          )
        : usuariosVisibles.isEmpty
        ? const SizedBox(
            height: 100,
            child: Center(child: Text('No hay usuarios activos o inactivos.')),
          )
        : ListView.builder(
            shrinkWrap: isMobile,
            physics: isMobile ? const NeverScrollableScrollPhysics() : null,
            itemCount: usuariosVisibles.length,
            itemBuilder: (context, index) {
              final usuario = usuariosVisibles[index];
              final bool esActivo = usuario['estado'] == 1;
              String sectorTexto = (usuario['sector'] ?? 'NO ASIGNADO')
                  .toString()
                  .toUpperCase();
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                color: const Color(0xFFF1F4F1),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Color(0xFFD0DDD0),
                                  child: Icon(
                                    Icons.person,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              usuario['username'] ??
                                                  'Sin nombre',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: esActivo
                                                  ? Colors.green[100]
                                                  : Colors.red[100],
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            child: Text(
                                              esActivo ? 'Activo' : 'Inactivo',
                                              style: TextStyle(
                                                color: esActivo
                                                    ? Colors.green[700]
                                                    : Colors.red[700],
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        usuario['email'] ?? 'Sin correo',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Rol: ${usuario['rol'].toString().toUpperCase()} | Sector: $sectorTexto",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                    size: 22,
                                  ),
                                  onPressed: () =>
                                      _mostrarFormularioEditar(usuario),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                Switch(
                                  value: esActivo,
                                  activeThumbColor: Colors.green,
                                  onChanged: (bool value) =>
                                      _cambiarEstadoUsuario(
                                        usuario['id'],
                                        value ? 1 : 2,
                                      ),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 22,
                                  ),
                                  onPressed: () => _confirmarEliminacion(
                                    usuario['id'],
                                    usuario['username'],
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFD0DDD0),
                              child: Icon(
                                Icons.person,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        usuario['username'] ?? 'Sin nombre',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: esActivo
                                              ? Colors.green[100]
                                              : Colors.red[100],
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: Text(
                                          esActivo ? 'Activo' : 'Inactivo',
                                          style: TextStyle(
                                            color: esActivo
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${usuario['email'] ?? 'Sin correo'}\nRol: ${usuario['rol'].toString().toUpperCase()}  |  Sector: $sectorTexto",
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () =>
                                      _mostrarFormularioEditar(usuario),
                                ),
                                Switch(
                                  value: esActivo,
                                  activeThumbColor: Colors.green,
                                  onChanged: (bool value) =>
                                      _cambiarEstadoUsuario(
                                        usuario['id'],
                                        value ? 1 : 2,
                                      ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _confirmarEliminacion(
                                    usuario['id'],
                                    usuario['username'],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              );
            },
          );

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'USUARIOS EN EL SISTEMA',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: verdeInstitucional,
            ),
          ),
          const SizedBox(height: 16),
          if (isMobile) lista else Expanded(child: lista),
        ],
      ),
    );
  }
}
