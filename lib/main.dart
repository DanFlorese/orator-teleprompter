import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'package:orator_teleprompter/views/auth/login_view.dart';
import 'package:orator_teleprompter/views/dashboard/dashboard_view.dart';
import 'package:orator_teleprompter/views/dashboard/profile_view.dart';
import 'package:orator_teleprompter/views/auth/reset_password_view.dart';
// --- IMPORTACIÓN DEL SERVICIO DE COMPRAS ---
import 'package:orator_teleprompter/services/purchase_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 1. Definimos la llave global para navegar sin depender del contexto local
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Asegura que los canales de la plataforma estén listos antes de ejecutar código asíncrono
  WidgetsFlutterBinding.ensureInitialized();

  // --- CARGA DE VARIABLES DE ENTORNO (.env) ---
  // Vital para evitar el error 'NotInitializedError'
  try {
    await dotenv.load(fileName: ".env");
    print("Variables de entorno cargadas correctamente.");
  } catch (e) {
    print("Error crítico al cargar el archivo .env: $e");
  }

  // --- INICIALIZACIÓN DE SUPABASE ---
  // Ahora usamos las llaves cargadas desde dotenv
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // --- INICIALIZACIÓN DE REVENUECAT ---
  // Permite verificar suscripciones desde el arranque
  await PurchaseService.init();

  // 2. Escuchamos cambios en la autenticación (especialmente recuperación de clave)
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final AuthChangeEvent event = data.event;

    if (event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (context) => const ResetPasswordView()),
      );
    }
  });

  runApp(const OratorApp());
}

class OratorApp extends StatelessWidget {
  const OratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Verificamos si hay una sesión activa para decidir la pantalla inicial
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Orator Teleprompter',
      debugShowCheckedModeBanner: false,
      theme: oratorTheme,

      // La pantalla inicial según la sesión detectada
      home: session != null ? const DashboardView() : const LoginView(),

      // Rutas de navegación principales
      routes: {
        '/login': (context) => const LoginView(),
        '/dashboard': (context) => const DashboardView(),
        '/profile': (context) => const ProfileView(),
      },
    );
  }
}