import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart'; // Importación para RevenueCat
import 'package:orator_teleprompter/core/theme.dart';
import 'package:orator_teleprompter/views/legal/privacy_policy_view.dart';
import 'package:orator_teleprompter/views/legal/terms_conditions_view.dart';
import 'package:orator_teleprompter/views/dashboard/dashboard_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); 
  bool _obscurePassword = true; 
  bool _isLoading = false;
  bool _acceptedTerms = false;

  // --- LÓGICA DE REGISTRO DIRECTO ---
  Future<void> _handleRegister() async {
    if (!_acceptedTerms) {
      _showMsg('You must accept the terms and privacy policy');
      return;
    }

    if (_emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _nameController.text.isEmpty) {
      _showMsg('Please fill all fields');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final AuthResponse response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _nameController.text.trim(),
          'accepted_terms': true,
          'accepted_terms_at': DateTime.now().toIso8601String(),
        },
      );
      
      if (response.user != null) {
        try {
          await Purchases.logIn(response.user!.id);
        } catch (e) {
          debugPrint('Error syncing new user with RevenueCat: $e');
        }

        if (!mounted) return;

        _showMsg('Welcome to Orator!', isError: false);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DashboardView()),
          (route) => false,
        );
      }

    } on AuthException catch (e) {
      _showMsg(e.message);
    } catch (e) {
      _showMsg('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String text, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)), 
        backgroundColor: isError ? redOrator : const Color(0xFF424242),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackBackground,
      // Extendemos el cuerpo detrás de la AppBar para que la imagen cubra todo
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        iconTheme: const IconThemeData(color: Colors.white)
      ),
      body: Stack(
        children: [
          // 1. Imagen de fondo
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/signup.png'), // Asegúrate que la ruta coincida con tu pubspec.yaml
                fit: BoxFit.cover,
                // Aplicamos un filtro oscuro para que los textos resalten
                colorFilter: ColorFilter.mode(
                  Colors.black54, 
                  BlendMode.darken
                ),
              ),
            ),
          ),
          // 2. Contenido original
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Create Account', 
                    style: TextStyle(
                      fontSize: 32, 
                      color: Colors.white, 
                      fontWeight: FontWeight.w900, 
                      letterSpacing: 1.0
                    )),
                  const SizedBox(height: 10),
                  const Text('Start your journey with Orator Teleprompter', 
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 40),
                  
                  _buildInput(_nameController, 'Full Name', Icons.person_outline),
                  const SizedBox(height: 20),
                  
                  _buildInput(_emailController, 'Email', Icons.email_outlined),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline, color: redOrator),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      hintText: 'Password',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: graySurface.withOpacity(0.8), // Ligera transparencia para el fondo
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  
                  const SizedBox(height: 25),

                  Row(
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        activeColor: redOrator,
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.white24, width: 2),
                        onChanged: (value) => setState(() => _acceptedTerms = value ?? false),
                      ),
                      Expanded(
                        child: Wrap(
                          children: [
                            const Text("I agree to the ", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TermsConditionsView())),
                              child: const Text("Terms", style: TextStyle(color: redOrator, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                            ),
                            const Text(" and ", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyView())),
                              child: const Text("Privacy Policy", style: TextStyle(color: redOrator, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    height: 58,
                    child: ElevatedButton(
                      onPressed: (_acceptedTerms && !_isLoading) ? _handleRegister : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: redOrator,
                        disabledBackgroundColor: Colors.white10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
                        : const Text(
                            'Sign Up', 
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white 
                            )
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String hint, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: redOrator),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: graySurface.withOpacity(0.8), // Ligera transparencia
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}