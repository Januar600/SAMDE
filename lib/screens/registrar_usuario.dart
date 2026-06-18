import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegistrarUsuario extends StatefulWidget {
  const RegistrarUsuario({super.key});

  @override
  State<RegistrarUsuario> createState() => _RegistrarUsuarioState();
}

class _RegistrarUsuarioState extends State<RegistrarUsuario> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  String _rolSeleccionado = 'consulta';
  final List<String> _rolesDisponibles = ['admin', 'almacen', 'consulta'];

  bool _cargandoRegistro = false;
  bool _cargandoLista = true;
  List<dynamic> _listaUsuarios = [];

  @override
  void initState() {
    super.initState();
    _obtenerUsuarios();
  }

  // API: OBTENER USUARIOS (ESTADOS 1 Y 2)
  Future<void> _obtenerUsuarios() async {
    final url = Uri.parse('http://localhost/samde_db/api/listar_usuarios.php');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['usuarios'] != null) {
          setState(() {
            _listaUsuarios = data['usuarios'];
            _cargandoLista = false;
          });
          return;
        }
      }
      setState(() {
        _cargandoLista = false;
      });
    } catch (e) {
      setState(() {
        _cargandoLista = false;
      });
      debugPrint("Error al cargar usuarios: $e");
    }
  }

  // API: REGISTRAR NUEVO USUARIO
  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargandoRegistro = true;
    });

    final url = Uri.parse('http://localhost/samde_db/api/password_hash.php');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _usuarioController.text.trim(),
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
          "rol": _rolSeleccionado,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['mensaje'] ?? 'Usuario creado'),
              backgroundColor: Colors.green,
            ),
          );

          _usuarioController.clear();
          _emailController.clear();
          _passwordController.clear();
          setState(() {
            _rolSeleccionado = 'consulta';
          });

          _obtenerUsuarios();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['mensaje'] ?? 'Error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargandoRegistro = false;
        });
      }
    }
  }

  // MODAL FLOTANTE Y API: EDITAR USUARIO
  void _editarUsuario(Map<String, dynamic> usuario) {
    final editUsuarioController = TextEditingController(
      text: usuario['username'],
    );
    final editEmailController = TextEditingController(text: usuario['email']);
    String editRolSeleccionado = usuario['rol'] ?? 'consulta';

    final editFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        const Color verdeInstitucional = Color(0xFF2E7D32);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  const Icon(Icons.edit, color: verdeInstitucional),
                  const SizedBox(width: 10),
                  Text(
                    'Editar Usuario: ${usuario['username']}',
                    style: const TextStyle(
                      color: verdeInstitucional,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: editFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: editUsuarioController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de Usuario',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresa el nombre.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: editEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: Icon(Icons.email),
                        ),
                        validator: (v) => v == null || !v.contains('@')
                            ? 'Ingresa un correo válido.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: editRolSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Rol del Usuario',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: _rolesDisponibles.map((String rol) {
                          return DropdownMenuItem<String>(
                            value: rol,
                            child: Text(rol.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (String? nuevoRol) {
                          if (nuevoRol != null) {
                            setDialogState(() {
                              editRolSeleccionado = nuevoRol;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verdeInstitucional,
                  ),
                  onPressed: () {
                    if (editFormKey.currentState!.validate()) {
                      Navigator.pop(context);
                      _actualizarUsuarioEnBD(
                        usuario['id'].toString(),
                        editUsuarioController.text.trim(),
                        editEmailController.text.trim(),
                        editRolSeleccionado,
                      );
                    }
                  },
                  child: const Text(
                    'GUARDAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _actualizarUsuarioEnBD(
    String id,
    String username,
    String email,
    String rol,
  ) async {
    final url = Uri.parse('http://localhost/samde_db/api/editar_usuario.php');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": id,
          "username": username,
          "email": email,
          "rol": rol,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['mensaje'] ?? 'Usuario actualizado'),
              backgroundColor: Colors.green,
            ),
          );
          _obtenerUsuarios();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['mensaje'] ?? 'Error al actualizar'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // LÓGICA: ALTERNAR ENTRE ACTIVO (1) E INACTIVO (2)
  void _alternarDesactivacion(Map<String, dynamic> usuario) {
    final int estadoActual = int.tryParse(usuario['estado'].toString()) ?? 1;
    final int nuevoEstado = (estadoActual == 1) ? 2 : 1;

    _enviarCambioEstadoBD(usuario['id'].toString(), nuevoEstado);
  }

  // LÓGICA: MANDAR A LA PAPELERA OCULTA (ESTADO 3)
  void _confirmarEnviarAPapelera(Map<String, dynamic> usuario) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(Icons.delete_sweep, color: Colors.red),
              SizedBox(width: 10),
              Text(
                'Enviar a la Papelera',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            '¿Deseas enviar al usuario "${usuario['username']}" a la sección de cuentas ocultas inactivas permanentes? Dejará de mostrarse en este listado.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCELAR',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _enviarCambioEstadoBD(usuario['id'].toString(), 3);
              },
              child: const Text(
                'OCULTAR',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // HTTP POST unificado para cambiar el estado (1, 2 o 3)
  Future<void> _enviarCambioEstadoBD(String id, int nuevoEstado) async {
    final url = Uri.parse('http://localhost/samde_db/api/cambiar_estado.php');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": id, "estado": nuevoEstado}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['mensaje']),
              backgroundColor: Colors.green,
            ),
          );
          _obtenerUsuarios();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['mensaje'] ?? 'Error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Gestión de Usuarios y Roles'),
        backgroundColor: verdeInstitucional,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Row(
        children: [
          // COLUMNA IZQUIERDA: Formulario de Registro
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 60,
                      color: verdeInstitucional,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'REGISTRAR NUEVO USUARIO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: verdeInstitucional,
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _usuarioController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de Usuario',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa el usuario.'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: Icon(Icons.email),
                      ),
                      validator: (v) => v == null || !v.contains('@')
                          ? 'Ingresa un correo válido.'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (v) => v == null || v.length < 6
                          ? 'Mínimo 6 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _rolSeleccionado,
                      decoration: const InputDecoration(
                        labelText: 'Rol del Usuario',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: _rolesDisponibles.map((String rol) {
                        return DropdownMenuItem<String>(
                          value: rol,
                          child: Text(rol.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (String? nuevoRol) {
                        if (nuevoRol != null) {
                          setState(() {
                            _rolSeleccionado = nuevoRol;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _cargandoRegistro ? null : _registrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verdeInstitucional,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _cargandoRegistro
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'GUARDAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const VerticalDivider(width: 1, color: Colors.grey),

          // COLUMNA DERECHA: Lista de usuarios (Muestra Activos e Inactivos)
          Expanded(
            flex: 3,
            child: _cargandoLista
                ? const Center(
                    child: CircularProgressIndicator(color: verdeInstitucional),
                  )
                : _listaUsuarios.isEmpty
                ? const Center(
                    child: Text(
                      'No hay usuarios activos o inactivos en el sistema.',
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'USUARIOS EN EL SISTEMA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: verdeInstitucional,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _listaUsuarios.length,
                            // AQUÍ CORREGIDO EL PARAMETRO DE LA IMAGEN 1
                            itemBuilder: (context, index) {
                              final user = _listaUsuarios[index];
                              final String estadoStr = user['estado']
                                  .toString();

                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: verdeInstitucional
                                        .withOpacity(0.1),
                                    child: const Icon(
                                      Icons.person,
                                      color: verdeInstitucional,
                                    ),
                                  ),
                                  title: Text(
                                    user['username'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${user['email']}\nRol: ${user['rol'] ?? 'No asignado'}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: estadoStr == '1'
                                              ? Colors.green[100]
                                              : Colors.red[100],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          estadoStr == '1'
                                              ? 'Activo'
                                              : 'Inactivo',
                                          style: TextStyle(
                                            color: estadoStr == '1'
                                                ? Colors.green[800]
                                                : Colors.red[800],
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () => _editarUsuario(user),
                                        tooltip: 'Editar Usuario',
                                      ),

                                      IconButton(
                                        icon: Icon(
                                          estadoStr == '1'
                                              ? Icons.toggle_on
                                              : Icons.toggle_off,
                                          color: estadoStr == '1'
                                              ? Colors.green
                                              : Colors.grey,
                                          size: 28,
                                        ),
                                        onPressed: () =>
                                            _alternarDesactivacion(user),
                                        tooltip: estadoStr == '1'
                                            ? 'Desactivar Cuenta'
                                            : 'Activar Cuenta',
                                      ),

                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _confirmarEnviarAPapelera(user),
                                        tooltip: 'Enviar a Cuentas Ocultas',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
