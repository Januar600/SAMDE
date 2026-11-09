import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../widgets/drawer_menu.dart';

class DashboardEjecutivoPage extends StatefulWidget {
  const DashboardEjecutivoPage({super.key});

  @override
  State<DashboardEjecutivoPage> createState() => _DashboardEjecutivoPageState();
}

class _DashboardEjecutivoPageState extends State<DashboardEjecutivoPage> {
  late String username;
  late String sector;
  late String rol;

  int _anioSeleccionado = DateTime.now().year;
  List<int> _aniosDisponibles = [];
  bool _cargando = false;
  String? _errorMensaje;

  Map<String, dynamic>? _data;

  static const String _baseUrl = 'http://localhost/samde_db/api';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = (args is Map<String, dynamic>) ? args : <String, dynamic>{};
    username = map['username'] ?? 'Usuario';
    sector = map['sector'] ?? 'No Asignado';
    rol = map['rol'] ?? 'consulta';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDashboard();
    });
  }

  Future<void> _cargarDashboard() async {
    setState(() {
      _cargando = true;
      _errorMensaje = null;
    });

    try {
      final url =
          '$_baseUrl/reportes/dashboard_ejecutivo.php?anio=$_anioSeleccionado';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _data = data;
          if (data['anios_disponibles'] != null) {
            _aniosDisponibles = List<int>.from(data['anios_disponibles']);
          }
        });
      } else {
        setState(() {
          _errorMensaje = data['message'] ?? 'Error al cargar el dashboard';
        });
      }
    } catch (e) {
      setState(() {
        _errorMensaje = 'Error de conexión: $e';
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _formatMoney(dynamic value) {
    if (value == null) return '\$0';
    try {
      final numValue = value is String
          ? double.tryParse(value) ?? 0
          : value.toDouble();
      return '\$${numValue.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    } catch (e) {
      return '\$0';
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF2E7D32);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      drawer: DrawerMenu(
        username: username,
        sector: sector,
        rol: rol,
        selectedIndex: 13,
      ),
      body: Column(
        children: [
          _buildHeader(verde, isMobile),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF1F8F1), Colors.white],
                ),
              ),
              child: _cargando
                  ? const Center(child: CircularProgressIndicator(color: verde))
                  : _errorMensaje != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _errorMensaje!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 12 : 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSelectorAnio(verde, isMobile),
                              const SizedBox(height: 24),
                              if (_data != null) ...[
                                _buildKPIs(verde, isMobile),
                                const SizedBox(height: 24),
                                _buildGraficos(verde, isMobile),
                                const SizedBox(height: 24),
                                _buildAlertas(verde, isMobile),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color verde, bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 192, 231, 195),
        border: Border(bottom: BorderSide(color: verde, width: 3)),
      ),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.menu, color: verde, size: 28),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.dashboard, color: verde, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Dashboard Ejecutivo',
              style: TextStyle(
                fontSize: isMobile ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorAnio(Color verde, bool isMobile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: verde),
            const SizedBox(width: 12),
            const Text(
              'Año:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _anioSeleccionado,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: _aniosDisponibles.isEmpty
                    ? [
                        DropdownMenuItem<int>(
                          value: _anioSeleccionado,
                          child: Text('$_anioSeleccionado'),
                        ),
                      ]
                    : _aniosDisponibles
                          .map(
                            (year) => DropdownMenuItem<int>(
                              value: year,
                              child: Text('$year'),
                            ),
                          )
                          .toList(),
                onChanged: (int? newValue) {
                  if (newValue != null && newValue != _anioSeleccionado) {
                    setState(() => _anioSeleccionado = newValue);
                    _cargarDashboard();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _cargando ? null : _cargarDashboard,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualizar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPIs(Color verde, bool isMobile) {
    final kpis = _data!['kpis'] as Map<String, dynamic>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Indicadores Clave',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: verde,
          ),
        ),
        const SizedBox(height: 16),
        if (isMobile)
          Column(
            children: [
              _buildKPICard(
                'Contratos Activos',
                '${kpis['contratos_activos']}',
                Icons.description,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildKPICard(
                'Valor Ejecutado',
                _formatMoney(kpis['valor_ejecutado']),
                Icons.attach_money,
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildKPICard(
                'Total Actas',
                '${kpis['total_actas']}',
                Icons.receipt_long,
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildKPICard(
                'Por Vencer (30 días)',
                '${kpis['contratos_por_vencer']}',
                Icons.warning_amber,
                Colors.red,
              ),
            ],
          )
        else
          Row(
            children: [
              _buildKPICard(
                'Contratos Activos',
                '${kpis['contratos_activos']}',
                Icons.description,
                Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildKPICard(
                'Valor Ejecutado',
                _formatMoney(kpis['valor_ejecutado']),
                Icons.attach_money,
                Colors.green,
              ),
              const SizedBox(width: 16),
              _buildKPICard(
                'Total Actas',
                '${kpis['total_actas']}',
                Icons.receipt_long,
                Colors.orange,
              ),
              const SizedBox(width: 16),
              _buildKPICard(
                'Por Vencer (30 días)',
                '${kpis['contratos_por_vencer']}',
                Icons.warning_amber,
                Colors.red,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildKPICard(
    String titulo,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Expanded(
      child: Card(
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
                child: Icon(icono, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valor,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGraficos(Color verde, bool isMobile) {
    final actasPorMes = List<Map<String, dynamic>>.from(
      _data!['actas_por_mes'] ?? [],
    );
    final contratosPorTipo = List<Map<String, dynamic>>.from(
      _data!['contratos_por_tipo'] ?? [],
    );
    final topAreas = List<Map<String, dynamic>>.from(_data!['top_areas'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Análisis Visual',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: verde,
          ),
        ),
        const SizedBox(height: 16),
        if (isMobile)
          Column(
            children: [
              _buildGraficoBarras(actasPorMes, verde),
              const SizedBox(height: 24),
              _buildGraficoDona(contratosPorTipo, verde),
              const SizedBox(height: 24),
              _buildGraficoAreas(topAreas, verde),
            ],
          )
        else
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildGraficoBarras(actasPorMes, verde)),
                  const SizedBox(width: 24),
                  Expanded(child: _buildGraficoDona(contratosPorTipo, verde)),
                ],
              ),
              const SizedBox(height: 24),
              _buildGraficoAreas(topAreas, verde),
            ],
          ),
      ],
    );
  }

  Widget _buildGraficoBarras(List<Map<String, dynamic>> data, Color verde) {
    final meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actas por Mes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: data.isEmpty
                      ? 10
                      : (data
                                .map((d) => d['total'] as int)
                                .reduce((a, b) => a > b ? a : b) *
                            1.2),
                  barGroups: List.generate(12, (index) {
                    final mesData = data
                        .where((d) => d['mes'] == index + 1)
                        .toList();
                    final valor = mesData.isEmpty
                        ? 0
                        : mesData.first['total'] as int;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: valor.toDouble(),
                          color: verde,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              meses[value.toInt()],
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoDona(List<Map<String, dynamic>> data, Color verde) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
    ];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contratos por Tipo',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return PieChartSectionData(
                      value: (item['total'] as int).toDouble(),
                      title: '${item['tipo_contrato']}',
                      color: colors[index % colors.length],
                      radius: 90,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      color: colors[index % colors.length],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item['tipo_contrato'],
                      style: const TextStyle(fontSize: 10),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraficoAreas(List<Map<String, dynamic>> data, Color verde) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 Áreas con Más Actas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: verde,
              ),
            ),
            const SizedBox(height: 16),
            if (data.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sin datos disponibles',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...data.map((item) {
                final maxValor = data
                    .map((d) => d['total'] as int)
                    .reduce((a, b) => a > b ? a : b);
                final porcentaje = ((item['total'] as int) / maxValor * 100)
                    .toDouble();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['area_dependencia'] ?? 'N/A',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${item['total']} actas',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: verde,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: porcentaje / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(verde),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertas(Color verde, bool isMobile) {
    final alertas = _data!['alertas'] as Map<String, dynamic>;
    final contratosVencer = List<Map<String, dynamic>>.from(
      alertas['contratos_por_vencer'] ?? [],
    );
    final topProveedores = List<Map<String, dynamic>>.from(
      alertas['top_proveedores'] ?? [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alertas y Destacados',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: verde,
          ),
        ),
        const SizedBox(height: 16),
        if (isMobile)
          Column(
            children: [
              _buildAlertaCard(
                'Contratos por Vencer',
                contratosVencer,
                Icons.warning_amber,
                Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildAlertaCard(
                'Top Proveedores',
                topProveedores,
                Icons.leaderboard,
                Colors.blue,
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildAlertaCard(
                  'Contratos por Vencer',
                  contratosVencer,
                  Icons.warning_amber,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildAlertaCard(
                  'Top Proveedores',
                  topProveedores,
                  Icons.leaderboard,
                  Colors.blue,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildAlertaCard(
    String titulo,
    List<Map<String, dynamic>> data,
    IconData icono,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (data.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Sin datos', textAlign: TextAlign.center),
              )
            else
              ...data.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['proveedor'] ?? item['numero_contrato'] ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (item['fecha_fin'] != null)
                        Text(
                          'Vence: ${item['fecha_fin']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (item['valor_total'] != null)
                        Text(
                          'Valor: ${_formatMoney(item['valor_total'])}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      if (item['total_contratos'] != null)
                        Text(
                          'Contratos: ${item['total_contratos']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
