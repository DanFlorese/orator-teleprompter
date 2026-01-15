import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  final _supabase = Supabase.instance.client;

  // Esta función nos dirá si debemos mostrar anuncios o no
  Future<bool> isUserPremium() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final data = await _supabase
          .from('profiles')
          .select('is_premium')
          .eq('id', user.id)
          .single();
      
      return data['is_premium'] ?? false;
    } catch (e) {
      return false; // Por seguridad, si hay error, asumimos que no es premium
    }
  }
}