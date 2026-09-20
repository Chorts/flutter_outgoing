import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_user_model.dart';

class AdminAuthService {
  static const String keyIsAdminLoggedIn = 'admin_is_logged_in';
  static const String keyAdminId = 'admin_session_id';
  static const String keyAdminUsername = 'admin_session_username';
  static const String keyAdminName = 'admin_session_name';
  static const String keyAdminEmail = 'admin_session_email';

  /// Hash password menggunakan SHA-256 (identik dengan implementasi hash PIN nasabah)
  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  /// Login staf admin ke Supabase
  static Future<AdminUser?> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final hashedInput = hashPassword(password);
      final isEmail = usernameOrEmail.contains('@');

      final response = await supabase
          .from('admin')
          .select()
          .eq(isEmail ? 'email' : 'username', usernameOrEmail.trim())
          .maybeSingle();

      if (response == null) {
        throw Exception('Akun admin tidak ditemukan.');
      }

      if (response['is_aktif'] == false) {
        throw Exception('Akun admin telah dinonaktifkan.');
      }

      final storedHash = response['password_hash']?.toString() ?? '';
      if (storedHash != hashedInput) {
        throw Exception('Password yang Anda masukkan salah.');
      }

      final admin = AdminUser.fromMap(response);

      // Simpan sesi admin ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyIsAdminLoggedIn, true);
      await prefs.setString(keyAdminId, admin.id);
      await prefs.setString(keyAdminUsername, admin.username);
      await prefs.setString(keyAdminName, admin.namaLengkap);
      await prefs.setString(keyAdminEmail, admin.email);

      return admin;
    } catch (e) {
      debugPrint('Admin login error: $e');
      rethrow;
    }
  }

  /// Cek apakah admin sedang login
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyIsAdminLoggedIn) ?? false;
  }

  /// Ambil data admin saat ini dari sesi lokal
  static Future<AdminUser?> getCurrentAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(keyIsAdminLoggedIn) ?? false;
    if (!loggedIn) return null;

    final id = prefs.getString(keyAdminId) ?? '';
    final username = prefs.getString(keyAdminUsername) ?? '';
    final name = prefs.getString(keyAdminName) ?? '';
    final email = prefs.getString(keyAdminEmail) ?? '';

    if (id.isEmpty) return null;

    return AdminUser(
      id: id,
      username: username,
      namaLengkap: name,
      email: email,
    );
  }

  /// Logout admin
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyIsAdminLoggedIn);
    await prefs.remove(keyAdminId);
    await prefs.remove(keyAdminUsername);
    await prefs.remove(keyAdminName);
    await prefs.remove(keyAdminEmail);
  }
}
