import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class DrawerMenu extends StatelessWidget {
  final String username;
  final String sector;
  final String rol;
  final int selectedIndex;

  const DrawerMenu({
    super.key,
    required this.username,
    required this.sector,
    required this.rol,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);
    const Color verdeClaro = Color(0xFFC0E7C3);

    // Obtener la inicial del nombre
    final String inicial = username.isNotEmpty
        ? username[0].toUpperCase()
        : '?';

    // Verificar si es administrador
    final bool esAdmin = rol.toLowerCase() == 'admin';

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // ============================================
            // ENCABEZADO DEL DRAWER - CON COLORES DEL BANNER
            // ============================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 35, 20, 20),
              decoration: BoxDecoration(
                color: verdeClaro,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25),
                ),
                border: Border(
                  bottom: BorderSide(color: verdeInstitucional, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo de la Gobernación
                  Image.asset(
                    'assets/logos/gobernacion.png',
                    height: 55,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 14),

                  // Título "MENÚ DE NAVEGACIÓN"
                  Text(
                    'MENÚ DE NAVEGACIÓN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: verdeInstitucional,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Línea separadora decorativa
                  Container(
                    height: 3,
                    width: 35,
                    color: verdeInstitucional.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),

                  // Sistema SAMDE
                  Text(
                    'Sistema SAMDE',
                    style: TextStyle(
                      fontSize: 13,
                      color: verdeInstitucional.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Línea divisora sutil
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: verdeInstitucional.withOpacity(0.15),
                  ),
                  const SizedBox(height: 14),

                  // Información del usuario con círculo
                  Row(
                    children: [
                      // Círculo con inicial
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: verdeInstitucional,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            inicial,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Nombre y rol
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username.toUpperCase(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: verdeInstitucional,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: verdeInstitucional.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'ROL: ${rol.toUpperCase()}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: verdeInstitucional,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Text(
                              sector,
                              style: TextStyle(
                                fontSize: 10,
                                color: verdeInstitucional.withOpacity(0.6),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ============================================
            // OPCIONES DEL MENÚ
            // ============================================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Inicio
                  _buildDrawerItem(
                    context,
                    'Inicio',
                    Icons.home_outlined,
                    0,
                    () {
                      Navigator.pop(context);
                      // Navegar a inicio
                    },
                  ),

                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // ============================================
                  // REGISTRAR USUARIOS (SOLO PARA ADMIN)
                  // ============================================
                  if (esAdmin) ...[
                    _buildDrawerItem(
                      context,
                      'Registrar Usuarios',
                      Icons.person_add_outlined,
                      5,
                      () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/registrar_usuario',
                          arguments: {
                            'username': username,
                            'sector': sector,
                            'rol': rol,
                          },
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                  ],

                  // Registrar Actas
                  _buildDrawerItem(
                    context,
                    'Registrar Actas',
                    Icons.description_outlined,
                    1,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/registrar_acta',
                        arguments: {
                          'username': username,
                          'sector': sector,
                          'rol': rol,
                        },
                      );
                    },
                  ),

                  // Registrar Contratos
                  _buildDrawerItem(
                    context,
                    'Registrar Contratos',
                    Icons.assignment_outlined,
                    2,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/registrar_contrato',
                        arguments: {
                          'username': username,
                          'sector': sector,
                          'rol': rol,
                        },
                      );
                    },
                  ),

                  // Registrar Egresos
                  _buildDrawerItem(
                    context,
                    'Registrar Egresos',
                    Icons.arrow_upward_outlined,
                    3,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/registrar_egreso',
                        arguments: {
                          'username': username,
                          'sector': sector,
                          'rol': rol,
                        },
                      );
                    },
                  ),

                  // Registrar Ingresos
                  _buildDrawerItem(
                    context,
                    'Registrar Ingresos',
                    Icons.arrow_downward_outlined,
                    4,
                    () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        '/registrar_ingreso',
                        arguments: {
                          'username': username,
                          'sector': sector,
                          'rol': rol,
                        },
                      );
                    },
                  ),

                  const Divider(height: 1, indent: 16, endIndent: 16),

                  // Cerrar Sesión
                  _buildDrawerItem(
                    context,
                    'Cerrar Sesión',
                    Icons.logout_outlined,
                    -1,
                    () {
                      Navigator.pop(context);
                      _confirmarCerrarSesion(context);
                    },
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================
  // CONSTRUIR ITEM DEL DRAWER
  // ========================================================
  Widget _buildDrawerItem(
    BuildContext context,
    String title,
    IconData icon,
    int index,
    VoidCallback onTap, {
    Color? color,
  }) {
    final bool isSelected = selectedIndex == index;
    const Color verdeInstitucional = Color(0xFF2E7D32);

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? verdeInstitucional : (color ?? Colors.grey[700]),
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? verdeInstitucional : (color ?? Colors.grey[800]),
        ),
      ),
      trailing: isSelected
          ? Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: verdeInstitucional,
                borderRadius: BorderRadius.circular(2),
              ),
            )
          : null,
      onTap: onTap,
      hoverColor: Colors.grey[100],
      splashColor: Colors.grey[200],
    );
  }

  // ========================================================
  // CONFIRMAR CIERRE DE SESIÓN
  // ========================================================
  void _confirmarCerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigatorContext = dialogContext;
                final storage = StorageService();
                await storage.cerrarSesion();
                if (navigatorContext.mounted) {
                  Navigator.of(navigatorContext).pop();
                  Navigator.pushReplacementNamed(navigatorContext, '/');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
