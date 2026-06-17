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
          // 1. ENCABEZADO INSTITUCIONAL
          Container(
            padding: const EdgeInsets.only(
              top: 40,
              left: 24,
              right: 24,
              bottom: 16,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              border: Border(
                bottom: BorderSide(color: verdeInstitucional, width: 4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GOBERNACIÓN DE GUAINÍA',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: verdeInstitucional,
                        ),
                      ),
                      Text(
                        'Secretaría de Agricultura, Medio Ambiente y Desarrollo Económico Departamental',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'MENÚ DE NAVEGACIÓN',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: verdeInstitucional,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
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
                        // Navegación directa añadida aquí para conectar la vista
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
