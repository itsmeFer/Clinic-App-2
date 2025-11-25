import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const _kTokenKey = 'token';
  static const _baseUrl = 'http://10.19.0.247:8000';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Kembalikan true kalau token masih bisa dipakai.
  static Future<bool> validateToken() async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/dokter/get-data-dokter'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (res.statusCode == 200) return true;
      if (res.statusCode == 401) return false; // expired/invalid
      return true; // jaringan/error lain → anggap tetap login biar UX enak
    } catch (_) {
      return true; // offline: tetap ijinkan masuk
    }
  }
}
