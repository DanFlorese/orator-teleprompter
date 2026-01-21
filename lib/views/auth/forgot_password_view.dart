import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:orator_teleprompter/core/theme.dart';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  // Controladores y Estado
  final _emailController = TextEditingController();
  bool _isLoading = false;

  // --- LÓGICA DE NEGOCIO ---

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.flutter://reset-callback/',
      );

      // CORRECCIÓN: Verificamos si el widget sigue vivo antes de usar el context
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Email enviado! Revisa tu bandeja.'), 
          backgroundColor: Colors.green
        ),
      );
      Navigator.pop(context);

    } on AuthException catch (e) {
      if (!mounted) return; // Seguridad adicional
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: redOrator),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error inesperado'), backgroundColor: redOrator),
      );
    } finally {
      // CORRECCIÓN: Seguridad al actualizar el estado tras un proceso asíncrono
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- INTERFAZ DE USUARIO (CLEAN UI) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView( // Añadido para evitar errores si el teclado se abre
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildHeader(),
            const SizedBox(height: 50),
            _buildEmailField(),
            const SizedBox(height: 30),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Icon(Icons.lock_reset_rounded, size: 100, color: redOrator),
        SizedBox(height: 25),
        Text(
          'Recover Password', 
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26, 
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0
          )
        ),
        SizedBox(height: 15),
        Text(
          'We’ll send a magic link to your email to restore your access.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.email_outlined, color: redOrator),
        hintText: 'Your Registered Email',
        hintStyle: const TextStyle(color: Colors.white10),
        filled: true,
        fillColor: graySurface,
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), 
          borderSide: BorderSide.none
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: redOrator, width: 1),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleResetPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: redOrator,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 5,
        ),
        child: _isLoading 
          ? const SizedBox(
              height: 20, 
              width: 20, 
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            ) 
          : const Text(
              'SEND INSTRUCTIONS', 
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)
            ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}