import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/drawer_menu.dart';

class MenuNavegacion extends StatelessWidget {
  const MenuNavegacion({super.key});

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);
    const Color azulBoton = Color(0xFFB3E5FC);

    // ========================================================
    // ARGUMENTOS: username, sector y rol
    // ========================================================
    final Object? argumentosRaw = ModalRoute.of(context)!.settings.arguments;
    Map<String, dynamic> argumentos = (argumentosRaw is Map<String, dynamic>)
        ? argumentosRaw
        : {};

    if (argumentos.isEmpty) {
      final storage = StorageService();
      final futureData = storage.obtenerUsuario();
      argumentos = {
        'username': 'Usuario',
        'sector': 'No Asignado',
        'rol': 'consulta',
        'nombreCompleto': 'Usuario',
        'email': '',
      };
      futureData.then((data) {
        print('Datos cargados: $data');
      });
    }

    final String username = argumentos['username'] ?? 'Usuario';
    final String sectorUsuario = argumentos['sector'] ?? 'No Asignado';
    final String rol = (argumentos['rol'] ?? 'consulta')
        .toString()
        .toLowerCase();
    final String nombreCompleto = argumentos['nombreCompleto'] ?? username;

    // ========================================================
    // PERMISOS POR ROL
    // ========================================================
    final bool esAdmin = rol == 'admin';
    final bool esAlmacen = rol == 'almacen';
    final bool puedeVerUsuarios = esAdmin;
    final bool puedeVerSecciones = esAdmin || esAlmacen;
    final bool esSoloConsulta = !esAdmin && !esAlmacen;

    // ============================================
    // CONTROLLADOR DEL DRAWER
    // ============================================
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: DrawerMenu(
        username: username,
        sector: sectorUsuario,
        rol: rol,
        selectedIndex: 0,
      ),
      body: Column(
        children: [
          // ========================================================
          // ENCABEZADO INSTITUCIONAL (BANNER VERDE)
          // ========================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 192, 231, 195),
              border: Border(
                bottom: BorderSide(color: verdeInstitucional, width: 4),
              ),
            ),
            child: Row(
              children: [
                // ============================================
                // LOGO EXPANDIDO - OCUPA TODO EL ESPACIO IZQUIERDO
                // ============================================
                Expanded(
                  flex: 4,
                  child: Image.asset(
                    'assets/logos/banner_gobernacion.png',
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                ),

                // ============================================
                // TÍTULO CENTRADO
                // ============================================
                const Expanded(
                  flex: 2,
                  child: Text(
                    'MENÚ DE NAVEGACIÓN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),

                // ============================================
                // INFORMACIÓN DEL USUARIO
                // ============================================
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nombreCompleto.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getRolColor(rol).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ROL: ${rol.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getRolColor(rol),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sector: $sectorUsuario',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          _confirmarCerrarSesion(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulBoton,
                          foregroundColor: Colors.black87,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'Cerrar sesión',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ========================================================
          // FILA CON BOTÓN DEL MENÚ (PARTE BLANCA)
          // ========================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey, width: 1)),
            ),
            child: Row(
              children: [
                // ============================================
                // BOTÓN DEL DRAWER (HAMBURGUESA)
                // ============================================
                IconButton(
                  icon: Icon(Icons.menu, color: verdeInstitucional, size: 28),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                  tooltip: 'Abrir menú',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Text(
                  'Menú de navegación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),

          // ========================================================
          // CONTENIDO - BOTONES EN CUADRÍCULA
          // ========================================================
          Expanded(
            child: Center(
              child: esSoloConsulta
                  ? _buildDashboardConsulta(
                      context,
                      username,
                      sectorUsuario,
                      rol,
                      verdeInstitucional,
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 40,
                        runSpacing: 30,
                        children: [
                          if (puedeVerUsuarios)
                            _buildMenuButton(
                              context,
                              'Registrar\nUsuarios',
                              azulBoton,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  '/registrar_usuario',
                                  arguments: {
                                    'username': username,
                                    'sector': sectorUsuario,
                                    'rol': rol,
                                  },
                                );
                              },
                            ),
                          if (puedeVerSecciones)
                            _buildMenuButton(
                              context,
                              'Registrar\nActa de\nEntrega',
                              azulBoton,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  '/registrar_acta',
                                  arguments: {
                                    'username': username,
                                    'sector': sectorUsuario,
                                    'rol': rol,
                                  },
                                );
                              },
                            ),
                          if (puedeVerSecciones)
                            _buildMenuButton(
                              context,
                              'Registrar\nContratos',
                              azulBoton,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  '/registrar_contrato',
                                  arguments: {
                                    'username': username,
                                    'sector': sectorUsuario,
                                    'rol': rol,
                                  },
                                );
                              },
                            ),
                          if (puedeVerSecciones)
                            _buildMenuButton(
                              context,
                              'Registrar\nEgreso\nAlmacen',
                              azulBoton,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  '/registrar_egreso',
                                  arguments: {
                                    'username': username,
                                    'sector': sectorUsuario,
                                    'rol': rol,
                                  },
                                );
                              },
                            ),
                          if (puedeVerSecciones)
                            _buildMenuButton(
                              context,
                              'Registrar\nIngreso\nAlmacen',
                              azulBoton,
                              () {
                                Navigator.pushNamed(
                                  context,
                                  '/registrar_ingreso',
                                  arguments: {
                                    'username': username,
                                    'sector': sectorUsuario,
                                    'rol': rol,
                                  },
                                );
                              },
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

  // ========================================================
  // COLOR SEGÚN ROL
  // ========================================================
  Color _getRolColor(String rol) {
    switch (rol) {
      case 'admin':
        return Colors.red;
      case 'almacen':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  // ========================================================
  // DASHBOARD PARA ROL CONSULTA
  // ========================================================
  Widget _buildDashboardConsulta(
    BuildContext context,
    String username,
    String sector,
    String rol,
    Color verdeInstitucional,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.dashboard_outlined, size: 70, color: verdeInstitucional),
        const SizedBox(height: 16),
        Text(
          '¡Bienvenido, ${username.toUpperCase()}!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: verdeInstitucional,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Tienes acceso de solo consulta al sistema.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          'Sector: $sector',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 20,
          runSpacing: 20,
          children: [
            _buildMenuButton(
              context,
              'Consultar\nActas',
              Colors.blue.shade100,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Módulo de consulta de actas en desarrollo'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
            _buildMenuButton(
              context,
              'Consultar\nContratos',
              Colors.purple.shade100,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Módulo de consulta de contratos en desarrollo',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
            _buildMenuButton(
              context,
              'Consultar\nInventario',
              Colors.teal.shade100,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Módulo de consulta de inventario en desarrollo',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // ========================================================
  // BOTÓN DE MENÚ
  // ========================================================
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
