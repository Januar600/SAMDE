import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // ============================================
  // CONSTANTES (lowerCamelCase según las reglas de Dart)
  // ============================================
  static const String keyUsername = 'username';
  static const String keySector = 'sector';
  static const String keyRol = 'rol';
  static const String keyNombreCompleto = 'nombreCompleto';
  static const String keyEmail = 'email';
  static const String keyIsLoggedIn = 'isLoggedIn';

  // ============================================
  // GUARDAR DATOS DEL USUARIO
  // ============================================
  Future<void> guardarUsuario({
    required String username,
    required String sector,
    required String rol,
    required String nombreCompleto,
    required String email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyUsername, username);
      await prefs.setString(keySector, sector);
      await prefs.setString(keyRol, rol);
      await prefs.setString(keyNombreCompleto, nombreCompleto);
      await prefs.setString(keyEmail, email);
      await prefs.setBool(keyIsLoggedIn, true);
    } catch (e) {
      // Manejar error si ocurre
      print('Error guardando usuario: $e');
    }
  }

  // ============================================
  // OBTENER DATOS DEL USUARIO
  // ============================================
  Future<Map<String, String>> obtenerUsuario() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'username': prefs.getString(keyUsername) ?? 'Usuario',
        'sector': prefs.getString(keySector) ?? 'No Asignado',
        'rol': prefs.getString(keyRol) ?? 'consulta',
        'nombreCompleto': prefs.getString(keyNombreCompleto) ?? 'Usuario',
        'email': prefs.getString(keyEmail) ?? '',
      };
    } catch (e) {
      print('Error obteniendo usuario: $e');
      return {
        'username': 'Usuario',
        'sector': 'No Asignado',
        'rol': 'consulta',
        'nombreCompleto': 'Usuario',
        'email': '',
      };
    }
  }

  // ============================================
  // VERIFICAR SI EL USUARIO ESTÁ LOGUEADO
  // ============================================
  Future<bool> estaLogueado() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyIsLoggedIn) ?? false;
    } catch (e) {
      print('Error verificando sesión: $e');
      return false;
    }
  }

  // ============================================
  // CERRAR SESIÓN (ELIMINAR DATOS)
  // ============================================
  Future<void> cerrarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyUsername);
      await prefs.remove(keySector);
      await prefs.remove(keyRol);
      await prefs.remove(keyNombreCompleto);
      await prefs.remove(keyEmail);
      await prefs.setBool(keyIsLoggedIn, false);
    } catch (e) {
      print('Error cerrando sesión: $e');
    }
  }
}
