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

  bool _cargandoRegistro = false;
  bool _cargandoLista = true;
  List<dynamic> _listaUsuarios = [];

  @override
  void initState() {
    super.initState();
    _obtenerUsuarios(); // Carga los usuarios existentes al abrir la pantalla
  }

  // Función para obtener la lista de usuarios desde MySQL
  Future<void> _obtenerUsuarios() async {
    final url = Uri.parse('http://localhost/samde_db/api/listar_usuarios.php');
    try {
      final response = await http.get(url);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        setState(() {
          _listaUsuarios = data['usuarios'];
          _cargandoLista = false;
        });
      } else {
        setState(() {
          _cargandoLista = false;
        });
      }
    } catch (e) {
      setState(() {
        _cargandoLista = false;
      });
      debugPrint("Error al cargar usuarios: $e");
    }
  }

  // Función para enviar el formulario a password_hash.php
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
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['mensaje'] ?? 'Usuario creado con éxito'),
              backgroundColor: Colors.green,
            ),
          );

          // Limpiar el formulario
          _usuarioController.clear();
          _emailController.clear();
          _passwordController.clear();

          // Refrescar la lista automáticamente
          _obtenerUsuarios();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['mensaje'] ?? 'Error al registrar'),
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
        title: const Text('Gestión de Usuarios'),
        backgroundColor: verdeInstitucional,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _obtenerUsuarios,
            tooltip: 'Refrescar Lista',
          ),
        ],
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
                      Icons.person_add_alt_1_outlined,
                      size: 60,
                      color: verdeInstitucional,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'CREAR USUARIO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: verdeInstitucional,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Input Usuario
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

                    // Input Email
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

                    // Input Contraseña
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
                    const SizedBox(height: 24),

                    // Botón de Registrar
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
                              'REGISTRAR',
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

          // Divisor intermedio
          const VerticalDivider(width: 1, color: Colors.grey),

          // COLUMNA DERECHA: Lista de usuarios traídos desde la BD
          Expanded(
            flex: 3,
            child: _cargandoLista
                ? const Center(
                    child: CircularProgressIndicator(color: verdeInstitucional),
                  )
                : _listaUsuarios.isEmpty
                ? const Center(
                    child: Text('No hay usuarios en la base de datos.'),
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
                            itemBuilder: (context, index) {
                              // <--- Corregido 'item Nancy' aquí
                              final user = _listaUsuarios[index];
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
                                  subtitle: Text(user['email'] ?? ''),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: user['estado'].toString() == '1'
                                          ? Colors.green[100]
                                          : Colors.red[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      user['estado'].toString() == '1'
                                          ? 'Activo'
                                          : 'Inactivo',
                                      style: TextStyle(
                                        color: user['estado'].toString() == '1'
                                            ? Colors.green[800]
                                            : Colors.red[800],
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
