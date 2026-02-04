import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'package:orator_teleprompter/views/auth/login_view.dart';
import 'package:orator_teleprompter/views/dashboard/dashboard_view.dart';
import 'package:orator_teleprompter/views/dashboard/profile_view.dart';
import 'package:orator_teleprompter/views/auth/reset_password_view.dart';
import 'package:orator_teleprompter/views/auth/forgot_password_view.dart';
// --- PURCHASE SERVICE IMPORT ---
import 'package:orator_teleprompter/services/purchase_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 1. Global key to navigate without local context
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Ensure platform channels are ready
  WidgetsFlutterBinding.ensureInitialized();

  // --- LOAD ENVIRONMENT VARIABLES (.env) ---
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("Environment variables loaded successfully.");
  } catch (e) {
    debugPrint("Critical error loading .env file: $e");
  }

  // --- SUPABASE INITIALIZATION ---
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // --- REVENUECAT INITIALIZATION ---
  await PurchaseService.init();

  runApp(const OratorApp());
}

class OratorApp extends StatefulWidget {
  const OratorApp({super.key});

  @override
  State<OratorApp> createState() => _OratorAppState();
}

class _OratorAppState extends State<OratorApp> {
  @override
  void initState() {
    super.initState();

    // 2. Auth state listener for password recovery
    // Se coloca aquí para que el listener esté activo durante toda la vida de la app
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint("Password recovery event detected!");
        // Usamos pushNamedAndRemoveUntil para limpiar el stack y forzar la nueva contraseña
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/reset-password',
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Verificamos si hay una sesión activa al arrancar
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Orator Teleprompter',
      debugShowCheckedModeBanner: false,
      theme: oratorTheme,
      // Home decide la pantalla inicial
      home: session != null ? const DashboardView() : const LoginView(),
      routes: {
        '/login': (context) => const LoginView(),
        '/forgot-password': (context) => const ForgotPasswordView(),
        '/reset-password': (context) => const ResetPasswordView(),
        '/dashboard': (context) => const DashboardView(),
        '/profile': (context) => const ProfileView(),
      },
    );
  }
}