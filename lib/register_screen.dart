import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
// Pastikan baris ini sesuai dengan nama folder project-mu
import 'package:flutter_outgoing/ktp_scan_screen.dart'; 

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers untuk input teks
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nikController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinController = TextEditingController();

  // Variabel untuk Dropdown dan Checkbox
  String? _selectedGender;
  String? _selectedProfession;
  bool _isConsentChecked = false; // Harus false dari awal (Opt-in Consent)

  final List<String> _genders = ['Laki-laki', 'Perempuan'];
  final List<String> _professions = ['Karyawan Swasta', 'PNS/BUMN', 'Wiraswasta', 'Mahasiswa', 'Lainnya'];

  // Fungsi untuk Hash PIN menggunakan SHA-256
  String hashPin(String pin) {
    var bytes = utf8.encode(pin);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Fungsi untuk mengirim data ke Supabase
  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_isConsentChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda harus menyetujui Syarat & Ketentuan.')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final supabase = Supabase.instance.client;
      final hashedPin = hashPin(_pinController.text);

      // 1. Insert ke tabel pengguna (dan kembalikan datanya untuk ambil ID)
      final response = await supabase.from('pengguna').insert({
        'nama_lengkap': _nameController.text,
        'email': _emailController.text,
        'nomor_telepon': _phoneController.text,
        'nik': _nikController.text,
        'alamat': _addressController.text,
        'jenis_kelamin': _selectedGender,
        'profesi': _selectedProfession,
        'pin_hash': hashedPin,
        'persetujuan_snk': _isConsentChecked,
      }).select();

      final userId = response.first['id'];

      // 2. Insert ke tabel jejak_audit (kepatuhan merekam persetujuan pengguna)
      await supabase.from('jejak_audit').insert({
        'id_pengguna': userId,
        'aksi': 'REGISTRASI_DAN_PERSETUJUAN_SNK',
        'deskripsi': 'Pengguna mendaftar dan secara aktif menyetujui Syarat & Ketentuan',
      });

      // 3. JIKA BERHASIL, PINDAH KE HALAMAN SCAN KTP
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Registrasi Berhasil! Lanjut Scan KTP.')),
        );
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const KtpScanScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mendaftar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nikController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendaftaran Nasabah'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Lengkapi Profil Risiko & Identitas Anda',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Form Nama
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 15),

              // Form NIK
              TextFormField(
                controller: _nikController,
                keyboardType: TextInputType.number,
                maxLength: 16,
                decoration: const InputDecoration(labelText: 'NIK KTP (16 Digit)', border: OutlineInputBorder()),
                validator: (val) => val != null && val.length == 16 ? null : 'NIK harus 16 digit',
              ),
              const SizedBox(height: 15),

              // Form Kontak (Email & Telepon)
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                validator: (val) => val == null || !val.contains('@') ? 'Email tidak valid' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Nomor Telepon', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Nomor telepon tidak boleh kosong' : null,
              ),
              const SizedBox(height: 15),

              // Form Alamat
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Alamat Sesuai KTP', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Alamat tidak boleh kosong' : null,
              ),
              const SizedBox(height: 15),

              // Dropdown Jenis Kelamin
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Jenis Kelamin', border: OutlineInputBorder()),
                items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setState(() => _selectedGender = val),
                validator: (val) => val == null ? 'Pilih jenis kelamin' : null,
              ),
              const SizedBox(height: 15),

              // Dropdown Profesi (Wajib APU-PPT)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Profesi', border: OutlineInputBorder()),
                items: _professions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) => setState(() => _selectedProfession = val),
                validator: (val) => val == null ? 'Pilih profesi Anda' : null,
              ),
              const SizedBox(height: 15),

              // Form PIN
              TextFormField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Buat PIN (6 Digit)', border: OutlineInputBorder()),
                validator: (val) => val != null && val.length == 6 ? null : 'PIN harus 6 angka',
              ),
              const SizedBox(height: 10),

              // Checkbox S&K (Opt-in)
              CheckboxListTile(
                title: const Text('Saya menyetujui Syarat & Ketentuan serta Kebijakan Privasi yang berlaku.'),
                value: _isConsentChecked,
                onChanged: (val) => setState(() => _isConsentChecked = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),

              // Tombol Submit
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.blue,
                ),
                onPressed: _isLoading ? null : registerUser,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Daftar Sekarang', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}