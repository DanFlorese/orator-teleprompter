import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'package:orator_teleprompter/views/legal/privacy_policy_view.dart';
import 'package:orator_teleprompter/views/legal/terms_conditions_view.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true; 
  bool _isLoading = false;
  
  // --- AVANCE LEGAL: Estado del Checkbox ---
  bool _acceptedTerms = false;

  Future<void> _handleRegister() async {
    if (!_acceptedTerms) {
      _showMsg('You must accept the terms and privacy policy');
      return;
    }

    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMsg('Please fill all fields');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      // ACTUALIZACIÓN: Ahora enviamos metadatos de aceptación a Supabase
      await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'accepted_terms': true,
          'accepted_terms_at': DateTime.now().toIso8601String(),
        },
      );
      
      _showMsg('Registration successful! Please check your email.');
      if (mounted) Navigator.pop(context); 
    } on AuthException catch (e) {
      _showMsg(e.message);
    } catch (e) {
      _showMsg('An unexpected error occurred');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: redOrator)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackBackground,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create Account', 
              style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Start your journey with Orator Teleprompter', 
              style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            
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
                fillColor: graySurface,
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
            
            const SizedBox(height: 30),
            
            ElevatedButton(
              onPressed: (_acceptedTerms && !_isLoading) ? _handleRegister : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor: redOrator,
                disabledBackgroundColor: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : Text(
                    'Sign Up', 
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold, 
                      color: _acceptedTerms ? Colors.white : Colors.white24 
                    )
                  ),
            ),
          ],
        ),
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
        fillColor: graySurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}