import 'package:flutter/material.dart';

class RegistrarActaPage extends StatelessWidget {
  const RegistrarActaPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ============================================
    // RECIBIR ARGUMENTOS
    // ============================================
    final Object? argumentosRaw = ModalRoute.of(context)!.settings.arguments;
    final Map<String, dynamic> argumentos =
        (argumentosRaw is Map<String, dynamic>) ? argumentosRaw : {};

    final String username = argumentos['username'] ?? 'Usuario';
    final String sector = argumentos['sector'] ?? 'No Asignado';
    final String rol = argumentos['rol'] ?? 'consulta';

    const Color verdeInstitucional = Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Acta de Entrega'),
        backgroundColor: verdeInstitucional,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // ============================================
            // VOLVER AL MENÚ CON LOS ARGUMENTOS
            // ============================================
            Navigator.pushReplacementNamed(
              context,
              '/menu',
              arguments: {'username': username, 'sector': sector, 'rol': rol},
            );
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
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
                        Icons.description,
                        size: 80,
                        color: verdeInstitucional,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Bienvenido a la sección de Registrar Acta de Entrega',
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
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
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
                            // ============================================
                            // VOLVER AL MENÚ CON LOS ARGUMENTOS
                            // ============================================
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
    );
  }
}
