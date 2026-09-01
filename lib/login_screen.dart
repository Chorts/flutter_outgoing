import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'landing_page_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController(); // Bisa email / no HP
  final _pinController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePin = true;

  // Fungsi Hash PIN (harus sama persis dengan yang di register_screen)
  String hashPin(String pin) {
    var bytes = utf8.encode(pin);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final identifier = _identifierController.text.trim();
      final inputtedPinHash = hashPin(_pinController.text);

      // Cek apakah inputan berupa email (ada '@') atau nomor HP
      final isEmail = identifier.contains('@');

      // Ambil data user dari database Supabase
      final response = await supabase
          .from('pengguna')
          .select()
          .eq(isEmail ? 'email' : 'nomor_telepon', identifier)
          .maybeSingle(); // maybeSingle mengembalikan null jika data tidak ditemukan

      if (response == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Akun tidak ditemukan. Silakan daftar terlebih dahulu.')),
          );
        }
        return;
      }

      // Cocokkan PIN yang ada di database dengan inputan user
      if (response['pin_hash'] == inputtedPinHash) {
        // ✅ Simpan status login ke SharedPreferences
        // FIX: Tambah 'userEmail' agar ProfilePage bisa baca email saat
        //      auth.currentUser == null (custom PIN login tanpa Supabase session)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userId',    response['id'].toString());
        await prefs.setString('userName',  response['nama_lengkap'] ?? '');
        await prefs.setString('userEmail', response['email'] ?? '');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login Berhasil!'), backgroundColor: Colors.green),
          );
          
          // Gunakan pushReplacement agar tidak bisa kembali ke halaman login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LandingPageScreen()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN yang Anda masukkan salah.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Selamat Datang\nKembali!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Silakan masukkan Email/No. HP dan PIN Anda untuk melanjutkan.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Input Email / No HP
              TextFormField(
                controller: _identifierController,
                decoration: InputDecoration(
                  labelText: 'Email / Nomor Telepon',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Tidak boleh kosong' : null,
              ),
              const SizedBox(height: 20),

              // Input PIN
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: _obscurePin,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'PIN (6 Digit)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (val) => val != null && val.length == 6 ? null : 'PIN harus 6 digit angka',
              ),
              const SizedBox(height: 30),

              // Tombol Login
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isLoading ? null : loginUser,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Masuk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}