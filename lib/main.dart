import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'package:orator_teleprompter/views/login_view.dart';
import 'package:orator_teleprompter/views/dashboard_view.dart';
import 'package:orator_teleprompter/views/profile_view.dart'; // Importante para la navegación
import 'package:orator_teleprompter/views/reset_password_view.dart';

// 1. Definimos la llave global para navegar sin depender del contexto local
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://tohplfxtwylelfpanlcq.supabase.co',
    anonKey: 'sb_publishable_KZXDjJERbA2_2hBAyVLaFg_Hb_fk_7K',
  );

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
      
      // La pantalla inicial según la sesión
      home: session != null ? const DashboardView() : const LoginView(),

      // --- ESTO ES LO QUE FALTABA ---
      // Definimos el "mapa" de nombres de rutas
      routes: {
        '/login': (context) => const LoginView(),
        '/dashboard': (context) => const DashboardView(),
        '/profile': (context) => const ProfileView(),
      },
    );
  }
}