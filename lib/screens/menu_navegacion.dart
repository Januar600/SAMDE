import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class MenuNavegacion extends StatelessWidget {
  const MenuNavegacion({super.key});

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);
    const Color azulBoton = Color(0xFFB3E5FC);

    // ========================================================
    // RECIBIR ARGUMENTOS
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ========================================================
          // ENCABEZADO INSTITUCIONAL
          // ========================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 192, 231, 195),
              border: Border(
                bottom: BorderSide(color: Color(0xFF2E7D32), width: 4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset(
                  'assets/logos/banner_gobernacion.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const Expanded(
                  child: Text(
                    'MENÚ DE NAVEGACIÓN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                // ============================================
                // INFORMACIÓN DEL USUARIO (REORDENADA)
                // ============================================
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. NOMBRE DEL USUARIO
                    Text(
                      nombreCompleto.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // 2. ROL DEL USUARIO (DEBAJO DEL NOMBRE)
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
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getRolColor(rol),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),

                    // 3. SECTOR (DEBAJO DEL ROL)
                    Text(
                      'Sector: $sectorUsuario',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 4. BOTÓN CERRAR SESIÓN
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

          // ========================================================
          // CONTENIDO SEGÚN ROL
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
                          if (puedeVerSecciones) ...[
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
        Icon(Icons.dashboard_outlined, size: 80, color: verdeInstitucional),
        const SizedBox(height: 20),
        Text(
          '¡Bienvenido, ${username.toUpperCase()}!',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: verdeInstitucional,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tienes acceso de solo consulta al sistema.',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          'Sector: $sector',
          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
        ),
        const SizedBox(height: 24),
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
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final storage = StorageService();
                await storage.cerrarSesion();

                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/');
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
