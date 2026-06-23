import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/storage_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _cargando = false;
  bool _obscurePassword = true;
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    final estaLogueado = await _storage.estaLogueado();
    if (estaLogueado && mounted) {
      final userData = await _storage.obtenerUsuario();
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/menu',
          arguments: {
            'username': userData['username'],
            'sector': userData['sector'],
            'rol': userData['rol'],
            'nombreCompleto': userData['nombreCompleto'],
            'email': userData['email'],
          },
        );
      }
    }
  }

  // ============================================
  // MÉTODO PARA EJECUTAR LOGIN
  // ============================================
  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _cargando = true;
    });

    final url = Uri.parse('http://localhost/samde_db/api/login.php');

    try {
      final String username = _usuarioController.text.trim();
      final String password = _passwordController.text;

      print('📤 Enviando: username="$username", password="$password"');

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({'username': username, 'password': password}),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.body.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: El servidor no respondió'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _cargando = false);
        return;
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
        print('📥 Datos decodificados: $data');
      } catch (e) {
        print('❌ Error decodificando JSON: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error en la respuesta del servidor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _cargando = false);
        return;
      }

      if (response.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          final userData = data['usuario'] ?? data['data'];

          if (userData == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Datos de usuario no recibidos'),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => _cargando = false);
            return;
          }

          final String username = userData['username']?.toString() ?? '';
          final String email = userData['email']?.toString() ?? '';
          final String rolString =
              userData['rol']?.toString()?.toLowerCase() ?? 'consulta';
          final String sector = userData['sector']?.toString() ?? 'No Asignado';
          final String nombreCompleto =
              userData['nombre_completo']?.toString() ?? username;

          print('✅ Usuario: $username');
          print('✅ Rol: $rolString');
          print('✅ Sector: $sector');

          await _storage.guardarUsuario(
            username: username,
            sector: sector,
            rol: rolString,
            nombreCompleto: nombreCompleto,
            email: email,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Bienvenido $nombreCompleto!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pushReplacementNamed(
            context,
            '/menu',
            arguments: {
              'username': username,
              'sector': sector,
              'rol': rolString,
              'nombreCompleto': nombreCompleto,
              'email': email,
            },
          );
        }
      } else if (response.statusCode == 403) {
        if (mounted) {
          _mostrarDialogoAccesoDenegado(
            context,
            data['mensaje'] ?? 'Acceso denegado',
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['mensaje'] ?? 'Credenciales incorrectas'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error en la petición: $e');
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
          _cargando = false;
        });
      }
    }
  }

  void _mostrarDialogoAccesoDenegado(BuildContext context, String mensaje) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.block, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text('Acceso Denegado'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mensaje, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Si crees que esto es un error, contacta al administrador.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _passwordController.clear();
              },
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/logos/gobernacion.png',
                    height: 190,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'SISTEMA DE INVENTARIO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Secretaría de Agricultura Medio Ambiente y Desarrollo Económico Departamental',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),

                  // ============================================
                  // CAMPO USUARIO
                  // ============================================
                  TextFormField(
                    controller: _usuarioController,
                    decoration: const InputDecoration(
                      labelText: 'Usuario',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Por favor, ingresa tu usuario.';
                      }
                      return null;
                    },
                    // ============================================
                    // AL PRESIONAR ENTER EN USUARIO → IR A CONTRASEÑA
                    // ============================================
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
                  ),
                  const SizedBox(height: 20),

                  // ============================================
                  // CAMPO CONTRASEÑA
                  // ============================================
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Por favor, ingresa tu contraseña.';
                      }
                      return null;
                    },
                    // ============================================
                    // AL PRESIONAR ENTER EN CONTRASEÑA → EJECUTAR LOGIN
                    // ============================================
                    onFieldSubmitted: (_) {
                      _iniciarSesion();
                    },
                  ),
                  const SizedBox(height: 32),

                  // ============================================
                  // BOTÓN INGRESAR
                  // ============================================
                  ElevatedButton(
                    onPressed: _cargando ? null : _iniciarSesion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: verdeInstitucional,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                            'INGRESAR',
                            style: TextStyle(
                              fontSize: 16,
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
      ),
    );
  }
}
