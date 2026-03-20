import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;
  
  // Variable interna para evitar consultas repetitivas en la misma sesión
  bool? _isPremiumCache;

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
          .maybeSingle(); // maybeSingle evita excepciones si el perfil no existe
      
      _isPremiumCache = data?['is_premium'] ?? false;
      return _isPremiumCache!;
    } catch (e) {
      // Si hay un error de red, no cacheamos el resultado para reintentar luego
      return false; 
    }
  }

  // Método para limpiar el caché (útil al hacer logout)
  void clearCache() => _isPremiumCache = null;
}