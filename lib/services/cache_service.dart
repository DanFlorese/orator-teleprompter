import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _scriptsKey = 'cached_scripts_list';
  static const String _profileKey = 'cached_profile_data';

  // --- SCRIPTS CACHE ---
  static Future<void> setScripts(List<Map<String, dynamic>> scripts) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scriptsKey, jsonEncode(scripts));
  }

  static Future<List<Map<String, dynamic>>> getScripts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? cachedData = prefs.getString(_scriptsKey);
    if (cachedData != null) {
      final List<dynamic> decodedData = jsonDecode(cachedData);
      return decodedData.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }

  // --- PROFILE CACHE (NUEVO) ---
  static Future<void> setProfile(String name, String? avatarUrl) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = {'name': name, 'avatar_url': avatarUrl};
    await prefs.setString(_profileKey, jsonEncode(data));
  }

  static Future<Map<String, String?>> getProfile() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? cachedData = prefs.getString(_profileKey);
    if (cachedData != null) {
      final Map<String, dynamic> decoded = jsonDecode(cachedData);
      return {'name': decoded['name'], 'avatar_url': decoded['avatar_url']};
    }
    return {'name': '', 'avatar_url': null};
  }

  // --- CLEANUP ---
  static Future<void> clearAllCache() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scriptsKey);
    await prefs.remove(_profileKey);
  }
}