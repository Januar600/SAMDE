import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/menu_navegacion.dart';
import 'screens/registrar_contrato.dart';
import 'screens/registrar_usuario.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color verdeInstitucional = Color(0xFF2E7D32);

    return MaterialApp(
      title: 'Sistema SAMDE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: verdeInstitucional,
        colorScheme: ColorScheme.fromSeed(
          seedColor: verdeInstitucional,
          primary: verdeInstitucional,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: verdeInstitucional, width: 2),
          ),
          labelStyle: TextStyle(color: verdeInstitucional),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/menu': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as String? ??
              'username';
          return MenuNavegacionPage(username: args);
        }, // Coma de separación correcta
        '/registrar_contrato': (context) => const RegistrarContratoPage(),
        '/registrar_usuario': (context) => const RegistrarUsuario(),
      },
    );
  }
}
