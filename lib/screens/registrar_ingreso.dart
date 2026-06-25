import 'package:flutter/material.dart';
import '../widgets/drawer_menu.dart';

class RegistrarIngresoPage extends StatefulWidget {
  const RegistrarIngresoPage({super.key});

  @override
  State<RegistrarIngresoPage> createState() => _RegistrarIngresoPageState();
}

class _RegistrarIngresoPageState extends State<RegistrarIngresoPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late String username;
  late String sector;
  late String rol;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Object? argumentosRaw = ModalRoute.of(context)!.settings.arguments;
    final Map<String, dynamic> argumentos =
        (argumentosRaw is Map<String, dynamic>) ? argumentosRaw : {};

    username = argumentos['username'] ?? 'Usuario';
    sector = argumentos['sector'] ?? 'No Asignado';
    rol = argumentos['rol'] ?? 'consulta';
  }

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);

    return Scaffold(
      key: _scaffoldKey,
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 5,
      ),
      body: Column(
        children: [
          // ============================================
          // BANNER INSTITUCIONAL
          // ============================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 192, 231, 195),
              border: Border(
                bottom: BorderSide(color: verdeInstitucional, width: 4),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.menu, color: verdeInstitucional, size: 30),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  tooltip: 'Abrir menú',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/logos/banner_gobernacion.png',
                  height: 110,
                  fit: BoxFit.contain,
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Registrar Ingresos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ============================================
          // CONTENIDO
          // ============================================
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.green.shade50, Colors.white],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 5,
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_shopping_cart,
                              size: 80,
                              color: verdeInstitucional,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Bienvenido a la sección de Registrar Ingresos',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Esta sección estará disponible próximamente.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    '/menu',
                                    arguments: {
                                      'username': username,
                                      'sector': sector,
                                      'rol': rol,
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: verdeInstitucional,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Volver al Menú Principal',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
