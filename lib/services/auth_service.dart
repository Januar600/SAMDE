import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final String _baseUrl = 'http://127.0.0.1/samde_db/api';

  /// Método para validar las credenciales del usuario con el backend en PHP
  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse('$_baseUrl/login.php');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      final Map<String, dynamic> responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        return {
          "success": true,
          "message": responseData['message'],
          "user": responseData['data'],
        };
      } else {
        return {
          "success": false,
          "message": responseData['message'] ?? 'Error al iniciar sesión.',
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message":
            "No se pudo conectar con el servidor. Verifica que XAMPP esté corriendo.",
      };
    }
  }
}
