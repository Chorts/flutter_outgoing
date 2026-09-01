import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'riwayat_page.dart';
import 'landing_page_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // State data user
  String _email = "";
  String _username = "";
  Map<String, dynamic>? _ktpData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ── AMBIL DATA DARI SUPABASE AUTH & TABEL PENGGUNA ──
  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);

      // FIX: auth.currentUser NULL saat login via PIN (custom login).
      // Solusi: coba Supabase session dulu, kalau null fallback ke SharedPreferences.
      final user = _supabase.auth.currentUser;
      String? userId;

      if (user != null) {
        // ── Kasus A: Login via OTP/registrasi (ada Supabase session) ──
        userId  = user.id;
        _email  = user.email ?? "";
      } else {
        // ── Kasus B: Login via PIN kustom (SharedPreferences only) ──
        final prefs = await SharedPreferences.getInstance();
        userId  = prefs.getString('userId');
        _email  = prefs.getString('userEmail') ?? "";
      }

      if (userId != null && userId.isNotEmpty) {
        final data = await _supabase
            .from('pengguna')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (data != null) {
          _ktpData = data;

          // FIX: kolom di tabel pengguna adalah 'nama_lengkap', bukan 'username'/'nama'
          _username = (data['nama_lengkap'] as String?)?.trim() ?? "";

          // Ambil email dari DB jika belum ada (misal dari SharedPreferences kosong)
          if (_email.isEmpty) {
            _email = (data['email'] as String?) ?? "";
          }

          // Fallback terakhir: pakai bagian depan email
          if (_username.isEmpty) {
            _username = _email.isNotEmpty ? _email.split('@')[0] : "-";
          }
        } else {
          _username = _email.isNotEmpty ? _email.split('@')[0] : "-";
        }
      }
    } catch (e) {
      debugPrint("Error loading user data: $e");
      if (_email.isNotEmpty && _username.isEmpty) {
        _username = _email.split('@')[0];
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── FUNGSI LOGOUT KELUAR AKUN ──
  Future<void> _handleLogout() async {
    try {
      // 1. Hapus sesi otentikasi dari Supabase
      await _supabase.auth.signOut();
      
      // 2. Hapus memori lokal di SharedPreferences agar tidak lengket
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Ini akan menghapus SEMUA data di SharedPreferences
      // Catatan: Jika kamu tidak ingin menghapus semuanya, gunakan prefs.remove('nama_key_login_mu');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil keluar dari akun")),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LandingPageScreen()),
          (route) => false, // Menghapus semua tumpukan halaman (history back)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal logout: $e")),
        );
      }
    }
  }

  // ── POP-UP DIALOG UNTUK MENAMPILKAN KELENGKAPAN DATA KTP ALL FIELDS ──
  void _showKtpDataPopup() {
    if (_ktpData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Data KTP tidak ditemukan.")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(
            children: [
              Icon(Icons.credit_card, color: Colors.blue),
              SizedBox(width: 10),
              Text("Data Kelengkapan KTP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(right: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sudah disesuaikan 100% dengan penambahan kolom SQL baru kamu
                    _buildKtpRow("NIK", _ktpData!['nik']),
                    _buildKtpRow("Nama Lengkap", _ktpData!['nama_lengkap'] ?? _ktpData!['username']),
                    _buildKtpRow("Tempat Lahir", _ktpData!['tempat_lahir']),
                    _buildKtpRow("Tanggal Lahir", _ktpData!['tgl_lahir']),
                    _buildKtpRow("Jenis Kelamin", _ktpData!['jenis_kelamin']),
                    _buildKtpRow("Gol. Darah", _ktpData!['gol_darah']),
                    _buildKtpRow("Alamat", _ktpData!['alamat']),
                    _buildKtpRow("RT/RW", _ktpData!['rtrw']),
                    _buildKtpRow("Kel/Desa", _ktpData!['kel_desa']),
                    _buildKtpRow("Kecamatan", _ktpData!['kecamatan']),
                    _buildKtpRow("Agama", _ktpData!['agama']),
                    _buildKtpRow("Status Perkawinan", _ktpData!['status_perkawinan']),
                    _buildKtpRow("Pekerjaan", _ktpData!['pekerjaan']),
                    _buildKtpRow("Kewarganegaraan", _ktpData!['kewarganegaraan']),
                    _buildKtpRow("Berlaku Hingga", _ktpData!['berlaku_hingga']),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKtpRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value?.toString() ?? "-", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
          const Divider(height: 12, thickness: 0.5),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),
              
              // ── ROW LAYOUT: USERNAME & EMAIL + TOMBOL PENSIL EDIT DI KANAN ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _username,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: const TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue, size: 26),
                    onPressed: () async {
                      // Pindah ke Halaman Edit, dan refresh data saat kembali
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditProfilePage(currentName: _username),
                        ),
                      );
                      _loadUserData();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 35),

              // ── MENU LIST (KELENGKAPAN KTP & RIWAYAT) ──
              _buildMenuTile(
                icon: Icons.assignment_ind_outlined,
                title: "Kelengkapan KTP",
                subtitle: "Lihat data identitas yang terdaftar",
                onTap: _showKtpDataPopup,
              ),
              _buildMenuTile(
                icon: Icons.history,
                title: "Lihat Riwayat Transaksi",
                subtitle: "Semua log aktivitas penukaran valas",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RiwayatPage()),
                  );
                },
              ),
              
              const SizedBox(height: 50),

              // ── TOMBOL KELUAR AKUN (LOGOUT) ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _handleLogout,

                  child: const Text(
                    "Log Out",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-SCREEN HALAMAN EDIT PROFIL (MENGUBAH USERNAME DI SUPABASE)
// ─────────────────────────────────────────────────────────────────────────────
class EditProfilePage extends StatefulWidget {
  final String currentName;
  const EditProfilePage({super.key, required this.currentName});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentName;
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      String? userId; 
      if (user != null) {
        userId = user.id;
      } else {
       
        final prefs = await SharedPreferences.getInstance();
        userId = prefs.getString('userId'); 
      }
      if (userId != null && userId.isNotEmpty) {
        await Supabase.instance.client
            .from('pengguna')
            .update({'nama_lengkap': _nameController.text.trim()})
            .eq('id', userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Username berhasil diperbarui")),
          );
          Navigator.pop(context);
        }
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal memperbarui profil: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ubah Username", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Username Baru", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                hintText: "Masukkan username baru",
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Simpan Perubahan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}