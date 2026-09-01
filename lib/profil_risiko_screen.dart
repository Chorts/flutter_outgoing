// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'kalkulasi_screen.dart';

class ProfilRisikoScreen extends StatefulWidget {
  final String userId;
  final String negaraTujuan;
  final String currencyTujuan;
  final String namaPenerima;
  final String noRekening;
  final String bankPenerima;
  final double limitTransaksi;

  const ProfilRisikoScreen({
    super.key,
    required this.userId,
    required this.negaraTujuan,
    required this.currencyTujuan,
    required this.namaPenerima,
    required this.noRekening,
    required this.bankPenerima,
    required this.limitTransaksi,
  });

  @override
  State<ProfilRisikoScreen> createState() => _ProfilRisikoScreenState();
}

class _ProfilRisikoScreenState extends State<ProfilRisikoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingData = true;

  // ── Pilihan profesi ───────────────────────────────────────────────────────
  final List<String> _profesiList = [
    'Karyawan Swasta',
    'Pegawai Negeri (PNS/ASN)',
    'Wiraswasta / Pengusaha',
    'Freelancer / Pekerja Lepas',
    'Pelajar / Mahasiswa',
    'Ibu Rumah Tangga',
    'Tenaga Kerja Indonesia (TKI)',
    'Profesional (Dokter, Pengacara, dll)',
    'Pensiunan',
    'Lainnya',
  ];

  // ── Pilihan sumber dana ──────────────────────────────────────────────────
  final List<String> _sumberDanaList = [
    'Gaji / Upah',
    'Hasil Usaha / Keuntungan Bisnis',
    'Tabungan Pribadi',
    'Kiriman dari Keluarga',
    'Hasil Investasi',
    'Dana Pensiun',
    'Hibah / Hadiah',
    'Lainnya',
  ];

  // ── Pilihan tujuan transfer ───────────────────────────────────────────────
  final List<Map<String, dynamic>> _tujuanList = [
    {"label": "Biaya Hidup Keluarga",   "icon": Icons.family_restroom_rounded},
    {"label": "Biaya Pendidikan",        "icon": Icons.school_rounded},
    {"label": "Pembayaran Bisnis",       "icon": Icons.business_center_rounded},
    {"label": "Pembayaran Properti",     "icon": Icons.home_rounded},
    {"label": "Pariwisata / Traveling",  "icon": Icons.flight_rounded},
    {"label": "Investasi",               "icon": Icons.trending_up_rounded},
    {"label": "Donasi / Amal",           "icon": Icons.volunteer_activism_rounded},
    {"label": "Lainnya",                 "icon": Icons.more_horiz_rounded},
  ];

  String? _selectedProfesi;
  String? _selectedSumberDana;
  String? _selectedTujuan;
  bool _profilSudahAda = false;

  @override
  void initState() {
    super.initState();
    _loadProfilRisiko();
  }

  /// Cek apakah profil risiko sudah pernah diisi sebelumnya
  Future<void> _loadProfilRisiko() async {
    try {
      final data = await Supabase.instance.client
          .from('pengguna')
          .select('profesi, sumber_dana, pekerjaan')
          .eq('id', widget.userId)
          .maybeSingle();

      if (data != null && mounted) {
        final profesi    = data['profesi']?.toString() ?? '';
        final sumberDana = data['sumber_dana']?.toString() ?? '';
        final tujuan     = data['pekerjaan']?.toString() ?? ''; // reuse kolom 'pekerjaan' untuk tujuan transfer

        setState(() {
          if (_profesiList.contains(profesi)) _selectedProfesi = profesi;
          if (_sumberDanaList.contains(sumberDana)) _selectedSumberDana = sumberDana;
          if (_tujuanList.any((t) => t['label'] == tujuan)) _selectedTujuan = tujuan;
          _profilSudahAda = profesi.isNotEmpty && sumberDana.isNotEmpty;
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
      }
    } catch (_) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _lanjutkan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTujuan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tujuan transfer terlebih dahulu')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Update profil risiko ke Supabase
      await Supabase.instance.client.from('pengguna').update({
        'profesi'    : _selectedProfesi,
        'sumber_dana': _selectedSumberDana,
        'pekerjaan'  : _selectedTujuan, // tujuan_transfer disimpan di kolom pekerjaan
      }).eq('id', widget.userId);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => KalkulasiScreen(
              userId: widget.userId,
              negaraTujuan: widget.negaraTujuan,
              currencyTujuan: widget.currencyTujuan,
              namaPenerima: widget.namaPenerima,
              noRekening: widget.noRekening,
              bankPenerima: widget.bankPenerima,
              limitTransaksi: widget.limitTransaksi,
              tujuanTransfer: _selectedTujuan!,
              sumberDana: _selectedSumberDana!,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan profil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Profil Risiko',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header info ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[700]!, Colors.blue[500]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Profil Risiko Diperlukan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Sesuai regulasi OJK & PPATK, kami perlu mengetahui informasi ini untuk keamanan transaksi Anda.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_profilSudahAda) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Colors.green[600], size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Data profil sebelumnya sudah dimuat.',
                              style: TextStyle(color: Colors.green[700], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── 1. Profesi ─────────────────────────────────────────
                    _buildSectionLabel('1. Profesi Anda', Icons.work_outline_rounded),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedProfesi,
                      hint: const Text('Pilih profesi Anda'),
                      decoration: _dropdownDecoration(Icons.work_rounded),
                      items: _profesiList.map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p, style: const TextStyle(fontSize: 14)),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedProfesi = val),
                      validator: (val) => val == null ? 'Pilih profesi Anda' : null,
                    ),

                    const SizedBox(height: 24),

                    // ── 2. Sumber Dana ────────────────────────────────────
                    _buildSectionLabel('2. Sumber Dana', Icons.account_balance_wallet_outlined),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedSumberDana,
                      hint: const Text('Pilih sumber dana'),
                      decoration: _dropdownDecoration(Icons.payments_rounded),
                      items: _sumberDanaList.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s, style: const TextStyle(fontSize: 14)),
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedSumberDana = val),
                      validator: (val) => val == null ? 'Pilih sumber dana' : null,
                    ),

                    const SizedBox(height: 24),

                    // ── 3. Tujuan Transfer ────────────────────────────────
                    _buildSectionLabel('3. Tujuan Transfer', Icons.send_rounded),
                    const SizedBox(height: 10),
                    _buildTujuanGrid(),
                    if (_selectedTujuan == null && _isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(
                          'Pilih tujuan transfer',
                          style: TextStyle(color: Colors.red[700], fontSize: 12),
                        ),
                      ),

                    const SizedBox(height: 36),

                    // ── Tombol Lanjut ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _lanjutkan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text(
                                    'Lanjut ke Kalkulasi',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
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

  // ── Tujuan Transfer Grid ──────────────────────────────────────────────────

  Widget _buildTujuanGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemCount: _tujuanList.length,
      itemBuilder: (context, index) {
        final item = _tujuanList[index];
        final isSelected = _selectedTujuan == item['label'];
        return GestureDetector(
          onTap: () => setState(() => _selectedTujuan = item['label']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[700] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue[700]! : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  item['icon'] as IconData,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.blue[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item['label'],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue[700]),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration(IconData icon) {
    return InputDecoration(
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
      ),
    );
  }
}