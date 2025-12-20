import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static const String _keyRole = 'user_role';

  // Simpan Role (Panggil pas Login Berhasil)
  static Future<void> saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyRole, role);
  }

  // Ambil Role (Panggil di Splash Screen / Awal Buka App)
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  // Hapus Data (Panggil pas Logout)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}