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
    if (email.isEmpty) {
      _showSnackBar('Please enter your email', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // CAMBIO CRÍTICO: redirectTo ahora coincide con el Dashboard y el Manifest
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'orator://reset-callback', 
      );

      if (!mounted) return;

      _showSnackBar('Email sent! Please check your inbox.', isError: false);
      
      // Regresamos al login después de enviar el correo
      Navigator.pop(context);

    } on AuthException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('An unexpected error occurred', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? redOrator : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      body: Center( // Centrado para mejor estética
        child: SingleChildScrollView( 
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHeader(),
              const SizedBox(height: 50),
              _buildEmailField(),
              const SizedBox(height: 30),
              _buildSubmitButton(),
            ],
          ),
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
            fontSize: 28, 
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0
          )
        ),
        SizedBox(height: 15),
        Text(
          'We’ll send a magic link to your email to restore your access.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 16),
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
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: graySurface,
        contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), 
          borderSide: BorderSide.none
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: redOrator, width: 1.5),
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
          elevation: 8,
          shadowColor: redOrator.withOpacity(0.5),
        ),
        child: _isLoading 
          ? const SizedBox(
              height: 20, 
              width: 20, 
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            ) 
          : const Text(
              'SEND INSTRUCTIONS', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)
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