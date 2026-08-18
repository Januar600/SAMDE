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
    try {
      final estaLogueado = await _storage.estaLogueado();
      if (estaLogueado && mounted) {
        final userData = await _storage.obtenerUsuario();
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/menu',
            arguments: {
              'usuario_id': userData['usuarioId'] ?? 2,
              'username': userData['username'] ?? 'Usuario',
              'sector': userData['sector'] ?? 'No Asignado',
              'rol': userData['rol'] ?? 'consulta',
              'nombreCompleto':
                  userData['nombreCompleto'] ??
                  userData['username'] ??
                  'Usuario',
              'email': userData['email'] ?? '',
            },
          );
        }
      }
    } catch (e) {
      print('❌ Error al verificar sesión: $e');
      await _storage.cerrarSesion();
    }
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _cargando = true;
    });

    final url = Uri.parse('http://localhost/samde_db/api/login.php');

    try {
      final response = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "username": _usuarioController.text.trim(),
              "password": _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          final userData = data['usuario'] ?? data['data'];

          final String username = userData['username'] ?? '';
          final String email = userData['email'] ?? '';
          final String rolString =
              (userData['rol'] as String?)?.toLowerCase() ?? 'consulta';
          final String sector = userData['sector'] ?? 'No Asignado';
          final String nombreCompleto = userData['nombre_completo'] ?? username;

          final int usuarioId = int.tryParse(userData['id'].toString()) ?? 2;

          await _storage.guardarUsuario(
            usuarioId: usuarioId,
            username: username,
            sector: sector,
            rol: rolString,
            nombreCompleto: nombreCompleto,
            email: email,
          );

          if (mounted) {
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
                'usuario_id': usuarioId,
                'username': username,
                'sector': sector,
                'rol': rolString,
                'nombreCompleto': nombreCompleto,
                'email': email,
              },
            );
          }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error de conexión: Verifica que el servidor esté activo. ($e)',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);
    final screenWidth = MediaQuery.of(context).size.width;

    // 🎯 Breakpoints responsivos
    final isSmallMobile = screenWidth < 360;
    final isMobile = screenWidth < 600;

    // 📏 Tamaños adaptativos
    final logoHeight = isSmallMobile
        ? 110.0
        : isMobile
        ? 140.0
        : 190.0;
    final titleFontSize = isSmallMobile
        ? 20.0
        : isMobile
        ? 24.0
        : 28.0;
    final subtitleFontSize = isSmallMobile ? 12.0 : 14.0;
    final horizontalPadding = isSmallMobile
        ? 16.0
        : isMobile
        ? 24.0
        : 32.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              // Garantiza que el contenido ocupe al menos toda la altura visible
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // centra vertical
                  children: [
                    Center(
                      // 👈 ESTE es el que faltaba: centra horizontal
                      child: Form(
                        key: _formKey,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 480),
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Image.asset(
                                'assets/logos/gobernacion.png',
                                height: logoHeight,
                                fit: BoxFit.contain,
                              ),
                              SizedBox(height: isMobile ? 16 : 24),
                              Text(
                                'SISTEMA DE INVENTARIO',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: verdeInstitucional,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Secretaría de Agricultura, Medio Ambiente y Desarrollo Económico Departamental',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: subtitleFontSize,
                                  color: Colors.grey[600],
                                  height: 1.3,
                                ),
                              ),
                              SizedBox(height: isMobile ? 24 : 40),
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
                                onFieldSubmitted: (_) {
                                  FocusScope.of(context).nextFocus();
                                },
                              ),
                              SizedBox(height: isMobile ? 16 : 20),
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
                                onFieldSubmitted: (_) {
                                  _iniciarSesion();
                                },
                              ),
                              SizedBox(height: isMobile ? 24 : 32),
                              ElevatedButton(
                                onPressed: _cargando ? null : _iniciarSesion,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: verdeInstitucional,
                                  padding: EdgeInsets.symmetric(
                                    vertical: isMobile ? 14 : 16,
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
                                    : Text(
                                        'INGRESAR',
                                        style: TextStyle(
                                          fontSize: isMobile ? 15 : 16,
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
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
