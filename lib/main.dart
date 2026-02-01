import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'package:orator_teleprompter/views/auth/login_view.dart';
import 'package:orator_teleprompter/views/dashboard/dashboard_view.dart';
import 'package:orator_teleprompter/views/dashboard/profile_view.dart';
import 'package:orator_teleprompter/views/auth/reset_password_view.dart';
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
    debugPrint("Environment variables loaded successfully."); // Fixed: replaced print with debugPrint
  } catch (e) {
    debugPrint("Critical error loading .env file: $e"); // Fixed: replaced print with debugPrint
  }

  // --- SUPABASE INITIALIZATION ---
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // --- REVENUECAT INITIALIZATION ---
  await PurchaseService.init();

  // 2. Auth state listener for password recovery
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
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Orator Teleprompter',
      debugShowCheckedModeBanner: false,
      theme: oratorTheme,
      home: session != null ? const DashboardView() : const LoginView(),
      routes: {
        '/login': (context) => const LoginView(),
        '/dashboard': (context) => const DashboardView(),
        '/profile': (context) => const ProfileView(),
      },
    );
  }
}