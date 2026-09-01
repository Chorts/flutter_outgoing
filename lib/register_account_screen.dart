// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'otp_verification_screen.dart';

class RegisterAccountScreen extends StatefulWidget {
  const RegisterAccountScreen({super.key});

  @override
  State<RegisterAccountScreen> createState() => _RegisterAccountScreenState();
}

class _RegisterAccountScreenState extends State<RegisterAccountScreen> {
  final _emailController    = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading    = false;
  bool _setujuSnk    = false; // checkbox S&K

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // ── Kirim OTP ─────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (_emailController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi semua data!')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              email   : _emailController.text.trim(),
              username: _usernameController.text.trim(),
              setujuSnk: _setujuSnk,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Pop-up Syarat & Ketentuan ─────────────────────────────────────────────
  void _showSnkDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Text(
                    'Syarat & Ketentuan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Isi S&K — scrollable
            SizedBox(
              height: 380,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    
                    _snkSection('1. Kepatuhan Regulasi & Identifikasi (KYC)',
                      'Anda wajib memberikan data identitas diri (KTP) dan verifikasi wajah (Liveness) '
                      'yang asli, valid, dan dapat dipertanggungjawabkan sesuai dengan prinsip '
                      'Know Your Customer (KYC) dan Anti-Pencucian Uang (APU-PPT).'),

                    _snkSection('Batas Maksimal Transaksi (Limit)',
                      'Sesuai dengan kepatuhan pelaporan Lalu Lintas Devisa (LLD) ke Bank Indonesia, '
                      'batas maksimal (limit) akumulasi pengiriman uang ke luar negeri adalah ' 
                      'ekuivalen USD 50.000 per pengguna.'),

                    _snkSection('3. Validasi Kurs & Eksekusi Transaksi',
                      'Nilai tukar konversi mata uang asing akan diikat secara real-time pada '
                      'saat instruksi pembayaran dibuat. Transaksi akan diproses ke dalam '
                      'antrean sistem untuk divalidasi lebih lanjut oleh admin operasional.'),

                    _snkSection('4. Keamanan & Penyimpanan Data',
                      'Seluruh rincian transaksi Anda, data pengirim, data penerima, dan '
                      'resi digital akan disimpan secara aman secara immutable di dalam '
                      'basis data (database) internal kami demi keperluan audit dan kepatuhan hukum.'),
  
                    _snkSection('5. Tanggung Jawab Pengguna',
                      'Anda menjamin bahwa seluruh dana yang ditransaksikan bukan berasal dari'
                      ' tindakan kejahatan, penipuan, atau pencucian uang.'),
                      
                    

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Tombol tutup
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snkSection(String judul, String isi) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.blue[800],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isi,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Tombol aktif hanya jika checkbox dicentang
    final bool canSubmit = _setujuSnk && !_isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Daftar Akun Baru',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Username ─────────────────────────────────────────────────
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),

            // ── Email ─────────────────────────────────────────────────────
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 28),

            // ── Checkbox Syarat & Ketentuan ───────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _setujuSnk ? Colors.blue[50] : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _setujuSnk
                      ? Colors.blue[300]!
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: _setujuSnk,
                    activeColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) =>
                        setState(() => _setujuSnk = val ?? false),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                        children: [
                          const TextSpan(text: 'Saya telah membaca dan menyetujui '),
                          TextSpan(
                            text: 'Syarat & Ketentuan',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = _showSnkDialog,
                          ),
                          const TextSpan(text: ' yang berlaku.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Tombol Kirim OTP ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      canSubmit ? Colors.blue[700] : Colors.grey[300],
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: canSubmit ? _sendOtp : null,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Kirim Kode OTP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: canSubmit ? Colors.white : Colors.grey[500],
                        ),
                      ),
              ),
            ),

            // ── Hint jika belum centang S&K ───────────────────────────────
            if (!_setujuSnk) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    'Centang Syarat & Ketentuan untuk melanjutkan',
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}