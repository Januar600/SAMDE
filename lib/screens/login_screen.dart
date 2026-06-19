import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Variables e identificadores del formulario
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _cargando = false;

  // Almacena el mensaje de error del backend (ej: "Su usuario se encuentra inactivo")
  String? _errorMensaje;

  Future<void> _iniciarSesion() async {
    // Valida los campos localmente (borde rojo nativo si están vacíos)
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _cargando = true;
      _errorMensaje = null; // Limpiamos errores previos al intentar de nuevo
    });

    // Ruta local en XAMPP para el login
    final url = Uri.parse('http://localhost/samde_db/api/login.php');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _usuarioController.text.trim(),
          "password": _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Bienvenido al sistema SAMDE!'),
              backgroundColor: Colors.green,
            ),
          );

          // Redirección al menú principal pasando el usuario como argumento
          Navigator.pushReplacementNamed(
            context,
            '/menu',
            arguments: _usuarioController.text.trim(),
          );
        }
      } else {
        // Manejo de error controlado desde el backend (ej: Usuario Inactivo)
        if (mounted) {
          setState(() {
            _errorMensaje = data['mensaje'] ?? 'Credenciales incorrectas';
          });
        }
      }
    } catch (e) {
      // Los errores críticos de infraestructura (Apache apagado) se mantienen en SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: Verifica Apache/MySQL. $e'),
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
              constraints: const BoxConstraints(
                maxWidth: 400,
              ), // Centra y estructura el diseño en entornos Web/Escritorio
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Escudo oficial de la Gobernación del Guainía
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
                      color: verdeInstitucional,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Secretaría de Agricultura Medio Ambiente y Desarrollo Economico Departamental',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 40),

                  // Campo Usuario
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
                  ),
                  const SizedBox(height: 20),

                  // Campo Contraseña con detección de Enter y Error text integrado
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    textInputAction: TextInputAction
                        .done, // Muestra el botón "Listo" en teclados virtuales
                    onFieldSubmitted: (_) {
                      // Ejecuta el login automáticamente si se presiona ENTER en el teclado
                      if (!_cargando) {
                        _iniciarSesion();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock),
                      border: const OutlineInputBorder(),
                      // Si hay un error del backend, se inyecta directamente aquí abajo sin alterar el diseño
                      errorText: _errorMensaje,
                      errorMaxLines: 2,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Por favor, ingresa tu contraseña.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Botón Ingresar
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
