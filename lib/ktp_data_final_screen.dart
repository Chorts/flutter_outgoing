import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'face_liveness_screen.dart'; 

class KtpDataFinalScreen extends StatefulWidget {
  final String nik;
  final String nama;
  final String tempatLahir;
  final String tglLahir;
  final String jenisKelamin;
  final String golDarah;
  final String alamat;
  final String rtrw;
  final String kelDesa;
  final String kecamatan;
  final String agama;
  final String statusPerkawinan;
  final String pekerjaan;
  final String kewarganegaraan;
  final String berlakuHingga;
  final bool setujuSnk;

  const KtpDataFinalScreen({
    super.key,
    required this.nik,
    required this.nama,
    required this.tempatLahir,
    required this.tglLahir,
    required this.jenisKelamin,
    required this.golDarah,
    required this.alamat,
    required this.rtrw,
    required this.kelDesa,
    required this.kecamatan,
    required this.agama,
    required this.statusPerkawinan,
    required this.pekerjaan,
    required this.kewarganegaraan,
    required this.berlakuHingga,
    this.setujuSnk = false, 
  });

  @override
  State<KtpDataFinalScreen> createState() => _KtpDataFinalScreenState();
}

class _KtpDataFinalScreenState extends State<KtpDataFinalScreen> {
  // ─── Controllers ──────────────────────────────────────────────────────────
  late TextEditingController _nikCtrl;
  late TextEditingController _namaCtrl;
  late TextEditingController _tempatLahirCtrl;
  late TextEditingController _tglLahirCtrl;
  late TextEditingController _jenisKelaminCtrl;
  late TextEditingController _golDarahCtrl;
  late TextEditingController _alamatCtrl;
  late TextEditingController _rtrwCtrl;
  late TextEditingController _kelDesaCtrl;
  late TextEditingController _kecamatanCtrl;
  late TextEditingController _agamaCtrl;
  late TextEditingController _statusPerkawinanCtrl;
  late TextEditingController _pekerjaanCtrl;
  late TextEditingController _kewarganegaraanCtrl;
  late TextEditingController _berlakuHinggaCtrl;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nikCtrl = TextEditingController(text: widget.nik);
    _namaCtrl = TextEditingController(text: widget.nama);
    _tempatLahirCtrl = TextEditingController(text: widget.tempatLahir);
    _tglLahirCtrl = TextEditingController(text: widget.tglLahir);
    _jenisKelaminCtrl = TextEditingController(text: widget.jenisKelamin);
    _golDarahCtrl = TextEditingController(text: widget.golDarah);
    _alamatCtrl = TextEditingController(text: widget.alamat);
    _rtrwCtrl = TextEditingController(text: widget.rtrw);
    _kelDesaCtrl = TextEditingController(text: widget.kelDesa);
    _kecamatanCtrl = TextEditingController(text: widget.kecamatan);
    _agamaCtrl = TextEditingController(text: widget.agama);
    _statusPerkawinanCtrl =
        TextEditingController(text: widget.statusPerkawinan);
    _pekerjaanCtrl = TextEditingController(text: widget.pekerjaan);
    _kewarganegaraanCtrl =
        TextEditingController(text: widget.kewarganegaraan);
    _berlakuHinggaCtrl = TextEditingController(text: widget.berlakuHingga);
  }

  @override
  void dispose() {
    _nikCtrl.dispose();
    _namaCtrl.dispose();
    _tempatLahirCtrl.dispose();
    _tglLahirCtrl.dispose();
    _jenisKelaminCtrl.dispose();
    _golDarahCtrl.dispose();
    _alamatCtrl.dispose();
    _rtrwCtrl.dispose();
    _kelDesaCtrl.dispose();
    _kecamatanCtrl.dispose();
    _agamaCtrl.dispose();
    _statusPerkawinanCtrl.dispose();
    _pekerjaanCtrl.dispose();
    _kewarganegaraanCtrl.dispose();
    _berlakuHinggaCtrl.dispose();
    super.dispose();
  }

 // ─── Simpan ke Supabase ──────────────────────────────────────────────────
  Future<void> _saveToSupabase() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      final currentUser = supabase.auth.currentUser;

      // 1. CEK SESI LOGIN
      // Jika user belum terautentikasi (OTP belum lolos/sesi habis), hentikan proses
      if (currentUser == null) {
        _showError('Sesi pengguna tidak ditemukan. Silakan ulangi proses pendaftaran dari awal.');
        return;
      }

      // Gabungkan alamat lengkap untuk kolom "alamat" di tabel pengguna
      final String alamatLengkap =
          '${_alamatCtrl.text.trim()} RT/RW ${_rtrwCtrl.text.trim()}, '
          'Kel. ${_kelDesaCtrl.text.trim()}, Kec. ${_kecamatanCtrl.text.trim()}';

      // 2. TAMBAHKAN ID DAN EMAIL DARI SESSION SUPABASE
      final Map<String, dynamic> data = {
        'id': currentUser.id,             
        'email': currentUser.email,       
        'nik': _nikCtrl.text.trim(),
        'nama_lengkap': _namaCtrl.text.trim(),
        'jenis_kelamin': _jenisKelaminCtrl.text.trim(),
        'alamat': _alamatCtrl.text.trim(),
        'kecamatan': _kecamatanCtrl.text.trim(),
        'tempat_lahir': _tempatLahirCtrl.text.trim(),
        'tgl_lahir': _tglLahirCtrl.text.trim(),
        'gol_darah': _golDarahCtrl.text.trim(),
        'rtrw': _rtrwCtrl.text.trim(),
        'kel_desa': _kelDesaCtrl.text.trim(),
        'agama': _agamaCtrl.text.trim(),
        'status_perkawinan': _statusPerkawinanCtrl.text.trim(),
        'pekerjaan': _pekerjaanCtrl.text.trim(),
        'kewarganegaraan': _kewarganegaraanCtrl.text.trim(),
        'berlaku_hingga': _berlakuHinggaCtrl.text.trim(),
        'persetujuan_snk': widget.setujuSnk,
        'diperbarui_pada': DateTime.now().toIso8601String(),
        'pin_hash': 'TEMP_HOLDER_UNTUK_DI_UPDATE',
      };

      // Cek apakah row dengan id ini sudah ada
      final existing = await supabase
          .from('pengguna')
          .select('id')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (existing != null) {
        // Row sudah ada → UPDATE saja (tidak kirim 'id' dan 'email' untuk hindari conflict)
        final updateData = Map<String, dynamic>.from(data)
          ..remove('id')
          ..remove('email');
        await supabase
            .from('pengguna')
            .update(updateData)
            .eq('id', currentUser.id);
      } else {
        // Row belum ada → INSERT
        await supabase.from('pengguna').insert(data);
      }

      if (!mounted) return;
      _showSuccessDialog();
    } on PostgrestException catch (e) {
      _showError('Gagal menyimpan data: ${e.message}');
    } catch (e) {
      _showError('Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Dialog Sukses & Navigasi ke Liveness ────────────────────────────────
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
        title: const Text(
          "Berhasil!",
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Data KTP berhasil dikonfirmasi.\nMari lanjutkan ke Verifikasi Wajah (Liveness).",
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Tutup dialog
              
              // 3. ARAHKAN KE HALAMAN LIVENESS
              // Ganti import di file ktp_data_final_screen.dart kamu 
              // dengan import 'face_liveness_screen.dart'; jika belum ada.
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const FaceLivenessScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text("Mulai Liveness"),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          "Konfirmasi Data KTP",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Periksa kembali data hasil scan. Anda dapat mengedit jika ada yang kurang tepat.",
                        style: TextStyle(color: Colors.blueAccent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── SEKSI: IDENTITAS UTAMA ─────────────────────────────────
              _buildSectionHeader("Identitas Utama", Icons.badge_outlined),
              _buildTextField(
                label: "NIK",
                controller: _nikCtrl,
                keyboardType: TextInputType.number,
                icon: Icons.numbers,
                validator: (v) {
                  if (v == null || v.trim().length != 16) {
                    return 'NIK harus 16 digit';
                  }
                  if (!RegExp(r'^\d{16}$').hasMatch(v.trim())) {
                    return 'NIK hanya berisi angka';
                  }
                  return null;
                },
              ),
              _buildTextField(
                label: "Nama Lengkap",
                controller: _namaCtrl,
                keyboardType: TextInputType.name,
                icon: Icons.person_outline,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama tidak boleh kosong' : null,
              ),

              // ── SEKSI: KELAHIRAN ───────────────────────────────────────
              _buildSectionHeader("Data Kelahiran", Icons.cake_outlined),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      label: "Tempat Lahir",
                      controller: _tempatLahirCtrl,
                      icon: Icons.location_city_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      label: "Tgl Lahir",
                      controller: _tglLahirCtrl,
                      icon: Icons.calendar_today_outlined,
                      hint: "DD-MM-YYYY",
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      label: "Jenis Kelamin",
                      controller: _jenisKelaminCtrl,
                      icon: Icons.wc_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      label: "Gol. Darah",
                      controller: _golDarahCtrl,
                      icon: Icons.bloodtype_outlined,
                    ),
                  ),
                ],
              ),

              // ── SEKSI: ALAMAT ──────────────────────────────────────────
              _buildSectionHeader("Alamat", Icons.home_outlined),
              _buildTextField(
                label: "Alamat",
                controller: _alamatCtrl,
                icon: Icons.streetview_outlined,
                maxLines: 2,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Alamat tidak boleh kosong' : null,
              ),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildTextField(
                      label: "RT/RW",
                      controller: _rtrwCtrl,
                      icon: Icons.grid_view_outlined,
                      hint: "000/000",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      label: "Kel/Desa",
                      controller: _kelDesaCtrl,
                      icon: Icons.villa_outlined,
                    ),
                  ),
                ],
              ),
              _buildTextField(
                label: "Kecamatan",
                controller: _kecamatanCtrl,
                icon: Icons.map_outlined,
              ),

              // ── SEKSI: DATA TAMBAHAN ───────────────────────────────────
              _buildSectionHeader("Data Tambahan", Icons.info_outline),
              _buildTextField(
                label: "Agama",
                controller: _agamaCtrl,
                icon: Icons.church_outlined,
              ),
              _buildTextField(
                label: "Status Perkawinan",
                controller: _statusPerkawinanCtrl,
                icon: Icons.favorite_border,
              ),
              _buildTextField(
                label: "Pekerjaan",
                controller: _pekerjaanCtrl,
                icon: Icons.work_outline,
              ),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      label: "Kewarganegaraan",
                      controller: _kewarganegaraanCtrl,
                      icon: Icons.flag_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      label: "Berlaku Hingga",
                      controller: _berlakuHinggaCtrl,
                      icon: Icons.event_outlined,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── TOMBOL SIMPAN ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveToSupabase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.blueAccent.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 20),
                            SizedBox(width: 8),
                            Text(
                              "Konfirmasi & Simpan",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widget Helpers ──────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(color: Colors.blueAccent.withOpacity(0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          labelStyle: const TextStyle(color: Colors.blueAccent, fontSize: 13),
          prefixIcon: icon != null
              ? Icon(icon, color: Colors.blueAccent, size: 20)
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.red[300]!),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          isDense: true,
        ),
      ),
    );
  }
}