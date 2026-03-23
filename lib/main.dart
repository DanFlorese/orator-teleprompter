import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'package:orator_teleprompter/views/auth/login_view.dart';
import 'package:orator_teleprompter/views/dashboard/dashboard_view.dart';
import 'package:orator_teleprompter/views/dashboard/profile_view.dart';
import 'package:orator_teleprompter/views/auth/reset_password_view.dart';
import 'package:orator_teleprompter/views/auth/forgot_password_view.dart';
import 'package:orator_teleprompter/services/purchase_service.dart';
import 'package:orator_teleprompter/services/ad_service.dart'; // <--- IMPORTANTE
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// Instancia global para llamar a los anuncios desde cualquier vista
final adService = AdService();

// Global key to navigate without local context
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // 1. Ensure platform channels are ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Google Ads & Load first ad
  // Lo hacemos al principio para que tenga tiempo de bajar el anuncio
  await MobileAds.instance.initialize();
  adService.loadAd();

  // 3. Load Environment Variables (.env)
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("Environment variables loaded successfully.");
  } catch (e) {
    debugPrint("Critical error loading .env file: $e");
  }

  // 4. Supabase Initialization
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // 5. RevenueCat Initialization
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

    // Auth state listener for password recovery
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;

      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint("Password recovery event detected!");
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/reset-password',
          (route) => false,
        );
      }
    });
  }

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
        '/forgot-password': (context) => const ForgotPasswordView(),
        '/reset-password': (context) => const ResetPasswordView(),
        '/dashboard': (context) => const DashboardView(),
        '/profile': (context) => const ProfileView(),
      },
    );
  }
}