// lib/widgets/drawer_menu.dart
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
    const Color verdeClaro = Color(0xFFC6E7C3);

    final String inicial = username.isNotEmpty
        ? username[0].toUpperCase()
        : 'U';

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // ============================================
            // ENCABEZADO DEL DRAWER
            // ============================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: verdeClaro,
                border: const Border(
                  bottom: BorderSide(color: verdeInstitucional, width: 2),
                ),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/logos/gobernacion.png',
                    height: 50,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sistema SAMDE',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: verdeInstitucional,
                    ),
                  ),
                  const Divider(color: verdeInstitucional, height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: verdeInstitucional,
                        child: Text(
                          inicial,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username.toUpperCase(),
                              style: TextStyle(
                                color: verdeInstitucional,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ROL: ${rol.toUpperCase()}',
                              style: TextStyle(
                                color: verdeInstitucional.withOpacity(0.7),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              sector,
                              style: TextStyle(
                                color: verdeInstitucional.withOpacity(0.6),
                                fontSize: 10,
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
            const SizedBox(height: 4),

            // ============================================
            // OPCIONES DEL MENÚ
            // ============================================
            _buildMenuItem(
              context,
              icon: Icons.dashboard,
              title: 'Inicio',
              index: 0,
              selectedIndex: selectedIndex,
              route: '/menu',
            ),
            _buildMenuItem(
              context,
              icon: Icons.person_add,
              title: 'Registrar Usuarios',
              index: 1,
              selectedIndex: selectedIndex,
              route: '/registrar_usuario',
            ),
            _buildMenuItem(
              context,
              icon: Icons.description,
              title: 'Registrar Actas',
              index: 2,
              selectedIndex: selectedIndex,
              route: '/registrar_acta',
            ),
            _buildMenuItem(
              context,
              icon: Icons.assignment,
              title: 'Registrar Contratos',
              index: 3,
              selectedIndex: selectedIndex,
              route: '/registrar_contrato',
            ),
            _buildMenuItem(
              context,
              icon: Icons.inventory_2,
              title: 'Registrar Egresos',
              index: 4,
              selectedIndex: selectedIndex,
              route: '/registrar_egreso',
            ),
            _buildMenuItem(
              context,
              icon: Icons.add_shopping_cart,
              title: 'Registrar Ingresos',
              index: 5,
              selectedIndex: selectedIndex,
              route: '/registrar_ingreso',
            ),

            const Spacer(),

            // ============================================
            // BOTÓN CERRAR SESIÓN
            // ============================================
            Divider(color: Colors.grey.shade300, height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red.shade700),
              title: Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _confirmarCerrarSesion(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ============================================
  // CONSTRUIR ITEM DEL MENÚ
  // ============================================
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required int index,
    required int selectedIndex,
    required String route,
  }) {
    final bool isSelected = selectedIndex == index;
    const Color verdeInstitucional = Color(0xFF2E7D32);

    // Ocultar "Registrar Usuarios" si no es admin
    if (title == 'Registrar Usuarios' && rol != 'admin') {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? verdeInstitucional : Colors.grey.shade700,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? verdeInstitucional : Colors.grey.shade800,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
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
      onTap: () {
        Navigator.of(context).pop();
        if (ModalRoute.of(context)!.settings.name != route) {
          Navigator.pushReplacementNamed(
            context,
            route,
            arguments: {'username': username, 'sector': sector, 'rol': rol},
          );
        }
      },
    );
  }

  // ============================================
  // CONFIRMAR CIERRE DE SESIÓN
  // ============================================
  void _confirmarCerrarSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final storage = StorageService();
                await storage.cerrarSesion();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  Navigator.pushReplacementNamed(dialogContext, '/');
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
