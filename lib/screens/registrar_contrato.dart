import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegistrarContratoPage extends StatefulWidget {
  const RegistrarContratoPage({super.key});

  @override
  State<RegistrarContratoPage> createState() => _RegistrarContratoPageState();
}

class _RegistrarContratoPageState extends State<RegistrarContratoPage> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para capturar el texto de los campos
  final _numeroController = TextEditingController();
  final _objetoController = TextEditingController();
  final _contratistaController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final _fechaFinController = TextEditingController();
  final _valorController = TextEditingController();

  // Estado inicial por defecto para el Dropdown
  String _estadoSeleccionado = 'Activo';
  bool _cargando = false;

  /// Método para enviar los datos directamente a tu API en XAMPP
  Future<void> _guardarContrato() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
    });

    // Cambia a 'http://10.0.2.2/...' si estás probando desde un emulador Android físico/virtual
    final url = Uri.parse('http://localhost/samde_db/api/crear_contrato.php');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "numero_contrato": _numeroController.text,
          "objeto_contrato": _objetoController.text,
          "contratista": _contratistaController.text,
          "fecha_inicio": _fechaInicioController.text,
          "fecha_fin": _fechaFinController.text,
          "valor_total": double.tryParse(_valorController.text) ?? 0.0,
          "estado": _estadoSeleccionado,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Contrato guardado con éxito! ID: ${data['contrato_id']}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _limpiarFormulario();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error del servidor: ${data['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error de conexión: Asegúrate que XAMPP esté encendido. $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  void _limpiarFormulario() {
    _numeroController.clear();
    _objetoController.clear();
    _contratistaController.clear();
    _fechaInicioController.clear();
    _fechaFinController.clear();
    _valorController.clear();
    setState(() {
      _estadoSeleccionado = 'Activo';
    });
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _objetoController.dispose();
    _contratistaController.dispose();
    _fechaInicioController.dispose();
    _fechaFinController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Registrar Contrato - SAMDE',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: verdeInstitucional,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'INFORMACIÓN DEL CONTRATO',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: verdeInstitucional,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Número del Contrato
                TextFormField(
                  controller: _numeroController,
                  decoration: const InputDecoration(
                    labelText: 'Número de Contrato *',
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 16),

                // Contratista
                TextFormField(
                  controller: _contratistaController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Contratista *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 16),

                // Objeto del Contrato
                TextFormField(
                  controller: _objetoController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Objeto del Contrato *',
                    prefixIcon: Icon(Icons.description),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 16),

                // Fechas (Fila doble)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fechaInicioController,
                        decoration: const InputDecoration(
                          labelText: 'Fecha Inicio (AAAA-MM-DD) *',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _fechaFinController,
                        decoration: const InputDecoration(
                          labelText: 'Fecha Fin (AAAA-MM-DD) *',
                          prefixIcon: Icon(Icons.calendar_month),
                        ),
                        validator: (v) => v!.isEmpty ? 'Obligatorio' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Valor Total
                TextFormField(
                  controller: _valorController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Valor Total (\$) *',
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (v) => v!.isEmpty ? 'Campo obligatorio' : null,
                ),
                const SizedBox(height: 16),

                // Estado del Contrato Dropdown
                DropdownButtonFormField<String>(
                  value: _estadoSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Estado del Contrato',
                    prefixIcon: Icon(Icons.info),
                  ),
                  items: ['Activo', 'Liquidado', 'Suspendido'].map((
                    String estado,
                  ) {
                    return DropdownMenuItem<String>(
                      value: estado,
                      child: Text(estado),
                    );
                  }).toList(),
                  onChanged: (nuevoEstado) {
                    setState(() {
                      _estadoSeleccionado = nuevoEstado!;
                    });
                  },
                ),
                const SizedBox(height: 32),

                // Botón de Enviar
                ElevatedButton(
                  onPressed: _cargando ? null : _guardarContrato,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verdeInstitucional,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _cargando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'GUARDAR EN BASE DE DATOS',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
