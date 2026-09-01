import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ktp_scan_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String username;
  final bool setujuSnk; 
  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.username,
    this.setujuSnk = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  
  // Variabel untuk Timer Resend
  Timer? _timer;
  int _start = 60; // Durasi tunggu 60 detik
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    startTimer(); // Mulai hitung mundur saat halaman dibuka
  }

  void startTimer() {
    setState(() {
      _canResend = false;
      _start = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _timer?.cancel();
          _canResend = true;
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  // Fungsi Kirim Ulang OTP
  Future<void> _resendOtp() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: widget.email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kode OTP baru telah dikirim!")),
        );
        startTimer(); // Reset timer setelah berhasil kirim ulang
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal kirim ulang: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        token: _otpController.text,
        type: OtpType.signup,
        email: widget.email,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => KtpScanScreen(setujuSnk: widget.setujuSnk),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kode OTP Salah atau Kadaluarsa!")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verifikasi OTP")),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            Text(
              "Masukkan 6 digit kode yang dikirim ke\n${widget.email}", 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold, 
                letterSpacing: 15, 
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                hintText: "000000",
                counterText: "",
                hintStyle: TextStyle(letterSpacing: 15, color: Colors.grey),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue[700],
              ),
              onPressed: _isLoading ? null : _verifyOtp,
              child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Verifikasi & Lanjut Scan KTP", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            
            // --- BAGIAN TOMBOL KIRIM ULANG ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Tidak menerima kode? "),
                _canResend
                    ? TextButton(
                        onPressed: _isLoading ? null : _resendOtp,
                        child: Text("Kirim Ulang", style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold)),
                      )
                    : Text(
                        "Kirim ulang dalam $_start s",
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}