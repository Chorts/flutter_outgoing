import 'package:flutter/material.dart';
import 'pin_verification_screen.dart'; // Import halaman verifikasi berikutnya

class PinCreationScreen extends StatefulWidget {
  const PinCreationScreen({super.key});

  @override
  State<PinCreationScreen> createState() => _PinCreationScreenState();
}

class _PinCreationScreenState extends State<PinCreationScreen> {
  final _pinController = TextEditingController();
  bool _obscurePin = true;

  void _nextStep() {
    final pin = _pinController.text.trim();
    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN harus terdiri dari 6 digit angka.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Oper data PIN yang dibuat ke halaman Verifikasi PIN
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinVerificationScreen(pinPertama: pin),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat PIN Baru'),
        automaticallyImplyLeading: false, // Tidak boleh back ke liveness
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Langkah 1: Buat PIN Anda',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Buat 6 digit PIN keamanan untuk akun Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Input PIN Pertama
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: _obscurePin,
                style: const TextStyle(fontSize: 24, letterSpacing: 16),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: "",
                  labelText: 'Masukkan PIN Baru',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Tombol Lanjut ke Verifikasi
              ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Lanjutkan',
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