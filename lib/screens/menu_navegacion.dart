import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/storage_service.dart';
import '../widgets/drawer_menu.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MenuNavegacion extends StatefulWidget {
  const MenuNavegacion({super.key});

  @override
  State<MenuNavegacion> createState() => _MenuNavegacionState();
}

class _MenuNavegacionState extends State<MenuNavegacion> {
  static const Color verdeInstitucional = Color(0xFF2E7D32);

  bool _argumentosListos = false;
  late Map<String, dynamic> _argumentos;
  bool _cargandoStats = false;
  Map<String, dynamic> _stats = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentosListos) return;

    final Object? argumentosRaw = ModalRoute.of(context)!.settings.arguments;

    if (argumentosRaw is Map<String, dynamic> && argumentosRaw.isNotEmpty) {
      _argumentos = argumentosRaw;
      _argumentosListos = true;
      _cargarEstadisticas();
    } else {
      _cargarDesdeStorage();
    }
  }

  Future<void> _cargarDesdeStorage() async {
    final storage = StorageService();
    final data = await storage.obtenerUsuario();

    if (!mounted) return;

    setState(() {
      _argumentos = {
        'username': data['username'] ?? 'Usuario',
        'sector': data['sector'] ?? 'No Asignado',
        'rol': data['rol'] ?? 'consulta',
        'nombreCompleto':
            data['nombreCompleto'] ?? data['username'] ?? 'Usuario',
        'email': data['email'] ?? '',
      };
      _argumentosListos = true;
      _cargarEstadisticas();
    });
  }

  Future<void> _cargarEstadisticas() async {
    setState(() => _cargandoStats = true);

    try {
      final response = await http
          .get(
            Uri.parse(
              'http://localhost/samde_db/api/dashboard/estadisticas.php',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _stats = data['data'];
            _cargandoStats = false;
          });
        } else {
          throw Exception('Respuesta no exitosa');
        }
      }
    } catch (e) {
      debugPrint('Error cargando estadísticas: $e');
      if (mounted) {
        setState(() => _cargandoStats = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_argumentosListos) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: verdeInstitucional),
        ),
      );
    }

    final String username = _argumentos['username'] ?? 'Usuario';
    final String sectorUsuario = _argumentos['sector'] ?? 'No Asignado';
    final String rol = (_argumentos['rol'] ?? 'consulta')
        .toString()
        .toLowerCase();
    final String nombreCompleto = _argumentos['nombreCompleto'] ?? username;

    final bool esAdmin = rol == 'administrador';
    final bool esAlmacen = rol == 'almacen';
    final bool esAdministrativo = rol == 'administrativo';
    final bool esConsulta = rol == 'consulta';

    final bool puedeVerUsuarios = esAdmin;
    // ✅ Ahora consulta también puede ver acciones rápidas
    final bool puedeVerSecciones =
        esAdmin || esAlmacen || esAdministrativo || esConsulta;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      drawer: esConsulta
          ? null // 🚫 No Drawer para rol consulta
          : DrawerMenu(
              username: username,
              sector: sectorUsuario,
              rol: rol,
              selectedIndex: 0,
            ),
      body: Column(
        children: [
          // HEADER
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
                if (!esConsulta) // 🚫 Ocultar botón menú en rol consulta
                  Builder(
                    builder: (ctx) => IconButton(
                      icon: const Icon(
                        Icons.menu,
                        color: verdeInstitucional,
                        size: 30,
                      ),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                      tooltip: 'Abrir menú de navegación',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Image.asset(
                    'assets/logos/banner_gobernacion.png',
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'PANEL DE CONTROL',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
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
                          color: _getRolColor(rol).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          ' ${rol.toUpperCase()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getRolColor(rol),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _confirmarCerrarSesion(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade700,
                          elevation: 0,
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
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CONTENIDO
          Expanded(
            child: RefreshIndicator(
              onRefresh: _cargarEstadisticas,
              color: verdeInstitucional,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Saludo
                    Text(
                      '¡Hola, ${username.split(' ')[0]}! 👋',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Text(
                      'Aquí tienes un resumen de la actividad del sistema.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // ✅ Acciones rápidas visibles también para consulta
                    if (puedeVerSecciones || puedeVerUsuarios) ...[
                      _buildSectionTitle('Acciones Rápidas', Icons.bolt),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildActionCard(
                            context,
                            'Consultar Actas',
                            Icons.assignment_turned_in,
                            Colors.blue.shade50,
                            '/consultar_actas',
                          ),
                          _buildActionCard(
                            context,
                            'Consultar Egreso',
                            Icons.remove_shopping_cart,
                            Colors.orange.shade50,
                            '/consultar_egreso',
                          ),
                          _buildActionCard(
                            context,
                            'Consultar Ingreso',
                            Icons.add_shopping_cart,
                            Colors.green.shade50,
                            '/consultar_ingreso',
                          ),
                          _buildActionCard(
                            context,
                            'Consultar Contrato',
                            Icons.file_present,
                            Colors.purple.shade50,
                            '/consultar_contrato',
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],

                    // 2. KPIs
                    if (_cargandoStats)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.6,
                        children: [
                          _buildKpiCard(
                            'Total Actas',
                            '${_stats['total_actas']}',
                            Icons.description,
                            Colors.blue,
                          ),
                          _buildKpiCard(
                            'Stock Disponible',
                            '${_stats['stock_disponible']}',
                            Icons.warehouse,
                            Colors.green,
                          ),
                          _buildKpiCard(
                            'Contratos Activos',
                            '${_stats['contratos_activos']}',
                            Icons.file_present,
                            Colors.purple,
                          ),
                          _buildKpiCard(
                            'Alertas Stock',
                            '${_stats['alertas_stock']}',
                            Icons.warning_amber_rounded,
                            Colors.orange,
                          ),
                        ],
                      ),

                    const SizedBox(height: 32),

                    // 3. FILA DE GRÁFICAS
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gráfico de Barras
                        Expanded(
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.bar_chart,
                                        color: verdeInstitucional,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Movimientos del Sistema',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    height: 250,
                                    child: FlBarChart(
                                      ingresos: _toDouble(
                                        _stats['total_ingresos'],
                                      ),
                                      egresos: _toDouble(
                                        _stats['total_egresos'],
                                      ),
                                      entregas: _toDouble(
                                        _stats['total_entregas'],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Gráfico Circular
                        Expanded(
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.pie_chart,
                                        color: verdeInstitucional,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Distribución de Movimientos',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    height: 250,
                                    child: FlPieChart(
                                      ingresos: _toDouble(
                                        _stats['total_ingresos'],
                                      ),
                                      egresos: _toDouble(
                                        _stats['total_egresos'],
                                      ),
                                      entregas: _toDouble(
                                        _stats['total_entregas'],
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

                    const SizedBox(height: 32),

                    // 4. Actividad Reciente
                    if (!(esAlmacen || esConsulta)) ...[
                      _buildSectionTitle(
                        'Movimientos Recientes',
                        Icons.history,
                      ),
                      const SizedBox(height: 16),
                      _buildRecentActivityList(),
                      const SizedBox(height: 24),
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

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: verdeInstitucional, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: verdeInstitucional,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color bgColor,
    String route,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          route,
          arguments: {
            'username': _argumentos['username'],
            'sector': _argumentos['sector'],
            'rol': _argumentos['rol'],
          },
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 180,
        height: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: verdeInstitucional, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityList() {
    final movimientos = List<Map<String, dynamic>>.from(
      _stats['ultimos_movimientos'] ?? [],
    );
    if (movimientos.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No hay movimientos recientes',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: movimientos.asMap().entries.map((entry) {
          final index = entry.key;
          final mov = entry.value;

          final esEntrega = mov['tipo'] == 'ENTREGA';
          final esIngreso = mov['tipo'] == 'INGRESO';
          final esEgreso = mov['tipo'] == 'EGRESO';

          final colorFondo = esEntrega
              ? Colors.blue.shade50
              : (esIngreso ? Colors.green.shade50 : Colors.orange.shade50);
          final colorIcono = esEntrega
              ? Colors.blue
              : (esIngreso ? Colors.green : Colors.orange);
          final icono = esEntrega
              ? Icons.delivery_dining
              : (esIngreso
                    ? Icons.add_shopping_cart
                    : Icons.remove_shopping_cart);
          final tipoLabel = esEntrega
              ? 'ENTREGA'
              : (esIngreso ? 'INGRESO' : 'EGRESO');

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: index < movimientos.length - 1
                      ? Colors.grey.shade200
                      : Colors.transparent,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorFondo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icono, color: colorIcono, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mov['item'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        mov['fecha'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorFondo,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tipoLabel, // ✅ CORREGIDO: Ya no muestra el número
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorIcono,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getRolColor(String rol) {
    switch (rol) {
      case 'administrador':
        return Colors.red;
      case 'almacen':
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

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

// ========================================================
// GRÁFICO DE BARRAS - INGRESOS VS EGRESOS
// ========================================================
class FlBarChart extends StatelessWidget {
  final double ingresos;
  final double egresos;
  final double entregas;

  const FlBarChart({
    super.key,
    required this.ingresos,
    required this.egresos,
    required this.entregas,
  });

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxValue([ingresos, egresos, entregas]) * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String label = '';
              if (groupIndex == 0) {
                label = 'Ingresos';
              } else if (groupIndex == 1) {
                label = 'Egresos';
              } else if (groupIndex == 2) {
                label = 'Entregas';
              }
              return BarTooltipItem(
                rod.toY.toStringAsFixed(0),
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: '\n$label',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const style = TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
                Widget text;
                if (value.toInt() == 0) {
                  text = const Text('Ingresos', style: style);
                } else if (value.toInt() == 1) {
                  text = const Text('Egresos', style: style);
                } else if (value.toInt() == 2) {
                  text = const Text('Entregas', style: style);
                } else {
                  text = const Text('', style: style);
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 10,
                  child: text,
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 10,
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: ingresos,
                color: Colors.green,
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(
                toY: egresos,
                color: Colors.orange,
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          ),
          BarChartGroupData(
            x: 2,
            barRods: [
              BarChartRodData(
                toY: entregas,
                color: Colors.blue,
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _getMaxValue(List<double> values) {
    double max = 0;
    for (var v in values) {
      if (v > max) max = v;
    }
    return max > 0 ? max : 10;
  }
}

// ========================================================
// GRÁFICO CIRCULAR - DISTRIBUCIÓN (SIN TOOLTIPS)
// ========================================================
class FlPieChart extends StatefulWidget {
  final double ingresos;
  final double egresos;
  final double entregas;

  const FlPieChart({
    super.key,
    required this.ingresos,
    required this.egresos,
    required this.entregas,
  });

  @override
  State<FlPieChart> createState() => _FlPieChartState();
}

class _FlPieChartState extends State<FlPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.ingresos + widget.egresos + widget.entregas;

    if (total <= 0) {
      return const Center(child: Text('No hay datos para mostrar'));
    }

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          enabled: true,
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  pieTouchResponse == null ||
                  pieTouchResponse.touchedSection == null) {
                touchedIndex = -1;
                return;
              }
              touchedIndex =
                  pieTouchResponse.touchedSection!.touchedSectionIndex;
            });
          },
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 2,
        centerSpaceRadius: 0,
        sections: _showingSections(),
      ),
    );
  }
// 
  List<PieChartSectionData> _showingSections() {
    final total = widget.ingresos + widget.egresos + widget.entregas;

    return List.generate(3, (i) {
      final isTouched = i == touchedIndex;
      final radius = isTouched ? 125.0 : 115.0;

      double value;
      Color color;
      String title;

      if (i == 0) {
        value = widget.ingresos;
        color = Colors.green;
        title = 'Ingresos\n${value.toInt()}';
      } else if (i == 1) {
        value = widget.egresos;
        color = Colors.orange;
        title = 'Egresos\n${value.toInt()}';
      } else {
        value = widget.entregas;
        color = Colors.blue;
        title = 'Entregas\n${value.toInt()}';
      }

      final percentage = total > 0
          ? (value / total * 100).toStringAsFixed(1)
          : '0';

      return PieChartSectionData(
        value: value,
        title: '$title\n$percentage%',
        radius: radius,
        color: color,
        titleStyle: TextStyle(
          fontSize: isTouched ? 13 : 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }
}
