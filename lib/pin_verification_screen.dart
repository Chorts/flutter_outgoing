import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'landing_page_screen.dart'; // Sesuaikan path beranda milikmu

class PinVerificationScreen extends StatefulWidget {
  final String pinPertama; // Menerima PIN dari halaman sebelumnya

  const PinVerificationScreen({super.key, required this.pinPertama});

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen> {
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePin = true;

  Future<void> _processAndSavePin() async {
    final inputConfirmPin = _confirmPinController.text.trim();

    if (inputConfirmPin.length != 6) {
      _showMessage('PIN harus 6 digit.', Colors.red);
      return;
    }

    // MEMASTIKAN ULANG: Apakah PIN yang dimasukkan sekarang sama dengan PIN pertama?
    if (inputConfirmPin != widget.pinPertama) {
      _showMessage('PIN tidak cocok! Silakan periksa kembali.', Colors.red);
      _confirmPinController.clear(); // Reset input biar isi ulang
      return;
    }

    // Jika COCOK, lakukan simpan ke database
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        _showMessage('Sesi tidak ditemukan. Silakan login ulang.', Colors.red);
        return;
      }

      // Hash PIN menggunakan SHA-256 agar aman di database
      final bytes = utf8.encode(inputConfirmPin);
      final hashedPin = sha256.convert(bytes).toString();

      // Update kolom 'pin_hash' di tabel pengguna
      await supabase
          .from('pengguna')
          .update({'pin_hash': hashedPin})
          .eq('id', currentUser.id);

      if (!mounted) return;

      // Sukses! Langsung arahkan ke Dashboard / Landing Page
      _showMessage('Registrasi Berhasil & PIN disimpan!', Colors.green);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LandingPageScreen()),
        (route) => false, // Bersihkan semua tumpukan halaman ke belakang agar user tidak bisa 'back' lagi
      );

    } on PostgrestException catch (e) {
      _showMessage('Gagal menyimpan PIN: ${e.message}', Colors.red);
    } catch (e) {
      _showMessage('Terjadi kesalahan sistem: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi PIN')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.verified_user_outlined, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                'Langkah 2: Verifikasi PIN Anda',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan kembali 6 digit PIN yang baru saja Anda buat untuk memastikan data sudah benar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Input PIN Kedua (Konfirmasi/Verifikasi)
              TextField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: _obscurePin,
                style: const TextStyle(fontSize: 24, letterSpacing: 16),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: "",
                  labelText: 'Konfirmasi PIN Anda',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Tombol Simpan & Selesai
              ElevatedButton(
                onPressed: _isLoading ? null : _processAndSavePin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Verifikasi & Selesai',
                        style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}