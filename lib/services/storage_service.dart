import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // ============================================
  // CONSTANTES
  // ============================================
  static const String keyUsuarioId = 'usuarioId'; // ✅ NUEVO
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
    required int usuarioId, // ✅ NUEVO
    required String username,
    required String sector,
    required String rol,
    required String nombreCompleto,
    required String email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(keyUsuarioId, usuarioId); // ✅ NUEVO
      await prefs.setString(keyUsername, username);
      await prefs.setString(keySector, sector);
      await prefs.setString(keyRol, rol);
      await prefs.setString(keyNombreCompleto, nombreCompleto);
      await prefs.setString(keyEmail, email);
      await prefs.setBool(keyIsLoggedIn, true);
    } catch (e) {
      print('Error guardando usuario: $e');
    }
  }

  // ============================================
  // OBTENER DATOS DEL USUARIO
  // ============================================
  Future<Map<String, dynamic>> obtenerUsuario() async {
    // ✅ Cambiado a dynamic para soportar int
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'usuarioId': prefs.getInt(keyUsuarioId) ?? 2, // ✅ NUEVO (respaldo en 2)
        'username': prefs.getString(keyUsername) ?? 'Usuario',
        'sector': prefs.getString(keySector) ?? 'No Asignado',
        'rol': prefs.getString(keyRol) ?? 'consulta',
        'nombreCompleto': prefs.getString(keyNombreCompleto) ?? 'Usuario',
        'email': prefs.getString(keyEmail) ?? '',
      };
    } catch (e) {
      print('Error obteniendo usuario: $e');
      return {
        'usuarioId': 2,
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
      await prefs.remove(keyUsuarioId); // ✅ NUEVO
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
