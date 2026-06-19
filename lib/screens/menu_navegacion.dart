import 'package:flutter/material.dart';

class MenuNavegacionPage extends StatelessWidget {
  final String username;

  const MenuNavegacionPage({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);
    const Color azulBoton = Color(0xFFB3E5FC);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ========================================================
          // 1. ENCABEZADO INSTITUCIONAL HORIZONTAL (ACTUALIZADO)
          // ========================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: Color.fromARGB(
                255,
                192,
                231,
                195,
              ), // Fondo verde claro institucional
              border: Border(
                bottom: BorderSide(color: verdeInstitucional, width: 4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // LADO IZQUIERDO: Logo horizontal completo (Banner)
                Image.asset(
                  'assets/logos/banner_gobernacion.png', // Tu nueva imagen horizontal
                  height: 150,
                  fit: BoxFit.contain,
                ),

                // CENTRO: Título del Menú perfectamente alineado
                const Expanded(
                  child: Text(
                    'MENÚ DE NAVEGACIÓN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: verdeInstitucional,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // LADO DERECHO: Control de Sesión e Información del Usuario
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Usuario',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    Text(
                      username.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Te redirige a la pantalla de login '/'
                        Navigator.pushReplacementNamed(context, '/');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: azulBoton,
                        foregroundColor: Colors.black87,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Cerrar sesión',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. BOTONES EN CUADRÍCULA
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 40,
                  runSpacing: 30,
                  children: [
                    _buildMenuButton(
                      context,
                      'Registrar\nUsuarios',
                      azulBoton,
                      () {
                        Navigator.pushNamed(context, '/registrar_usuario');
                      },
                    ),
                    _buildMenuButton(
                      context,
                      'Registrar\nActa de\nEntrega',
                      azulBoton,
                      () {},
                    ),
                    _buildMenuButton(
                      context,
                      'Registrar\nContratos',
                      azulBoton,
                      () {
                        Navigator.pushNamed(context, '/registrar_contracto');
                      },
                    ),
                    _buildMenuButton(
                      context,
                      'Registrar\nEgreso\nAlmacen',
                      azulBoton,
                      () {},
                    ),
                    _buildMenuButton(
                      context,
                      'Registrar\nIngreso\nAlmacen',
                      azulBoton,
                      () {},
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

  Widget _buildMenuButton(
    BuildContext context,
    String texto,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 160,
        height: 120,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
