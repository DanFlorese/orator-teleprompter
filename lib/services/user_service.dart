import 'dart:io';
import 'package:flutter/foundation.dart'; // Importante para debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;
  
  // Variable interna para evitar consultas repetitivas en la misma sesión
  bool? _isPremiumCache;

  /// Verifica si el usuario actual tiene estatus Premium.
  Future<bool> isUserPremium() async {
    // Si ya lo consultamos en esta sesión, lo devolvemos rápido
    if (_isPremiumCache != null) return _isPremiumCache!;

    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final data = await _supabase
          .from('profiles')
          .select('is_premium')
          .eq('id', user.id)
          .maybeSingle(); 
      
      _isPremiumCache = data?['is_premium'] ?? false;
      return _isPremiumCache!;
    } on SocketException {
      // Error específico de red: no hay internet
      return false; 
    } on PostgrestException catch (e) {
      // Usamos debugPrint en lugar de print para cumplir con las reglas de producción
      debugPrint('Error de base de datos: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error desconocido: $e');
      return false; 
    }
  }

  /// Método de utilidad para traducir errores técnicos a mensajes amigables.
  String mapErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (error is SocketException || 
        errorString.contains('socketexception') || 
        errorString.contains('failed host lookup')) {
      return "Could not connect to the server. Please check your internet connection.";
    }

    if (errorString.contains('invalid login credentials')) {
      return "Invalid email or password.";
    }

    if (errorString.contains('network_error')) {
      return "Network error. Please check your signal and try again.";
    }

    return "An unexpected error occurred. Please try again later.";
  }

  // Método para limpiar el caché (útil al hacer logout)
  void clearCache() => _isPremiumCache = null;
}