import 'package:flutter/material.dart';
import '../models/admin_user_model.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_transaction_service.dart';
import '../widgets/status_badge.dart';

class AdminDetailTransaksiScreen extends StatefulWidget {
  final String transaksiId;
  final AdminUser? adminUser;

  const AdminDetailTransaksiScreen({
    super.key,
    required this.transaksiId,
    this.adminUser,
  });

  @override
  State<AdminDetailTransaksiScreen> createState() => _AdminDetailTransaksiScreenState();
}

class _AdminDetailTransaksiScreenState extends State<AdminDetailTransaksiScreen> {
  AdminUser? _adminUser;
  Map<String, dynamic>? _transaksi;
  bool _isLoading = true;
  bool _isProcessing = false;
  String _errorMessage = '';

  // ── Form Penerusan Mitra State ──
  String _selectedMitra = 'Wallex';
  final TextEditingController _referensiMitraCtrl = TextEditingController();
  final TextEditingController _catatanAdminCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _referensiMitraCtrl.dispose();
    _catatanAdminCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      _adminUser = widget.adminUser ?? await AdminAuthService.getCurrentAdmin();
      final data = await AdminTransactionService.getDetailTransaksi(widget.transaksiId);
      if (mounted) {
        setState(() {
          _transaksi = data;
          _isLoading = false;
          if (data?['mitra_remitansi'] != null && data!['mitra_remitansi'].toString().isNotEmpty) {
            _selectedMitra = data['mitra_remitansi'].toString();
          }
          if (data?['referensi_mitra'] != null) {
            _referensiMitraCtrl.text = data!['referensi_mitra'].toString();
          }
          if (data?['catatan_admin'] != null) {
            _catatanAdminCtrl.text = data!['catatan_admin'].toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat detail transaksi: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatRupiah(num? value) {
    if (value == null) return 'Rp 0';
    final parts = value.toStringAsFixed(0).split('');
    String f = '';
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) f += '.';
      f += parts[i];
    }
    return 'Rp $f';
  }

  String _formatTanggal(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$min WIB';
  }

  // ── Aksi 1: Verifikasi Setujui Pembayaran ──
  Future<void> _handleSetujuiPembayaran() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Setujui Pembayaran?'),
          ],
        ),
        content: const Text(
          'Bukti pembayaran akan diverifikasi dan status transfer akan diperbarui menjadi "Diverifikasi" (Siap diteruskan ke mitra luar negeri).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Setujui', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final adminId = _adminUser?.id ?? '';
    if (adminId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi admin berakhir. Silakan login kembali.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await AdminTransactionService.verifikasiPembayaran(
        transaksiId: widget.transaksiId,
        disetujui: true,
        adminId: adminId,
        catatan: 'Pembayaran telah diverifikasi sesuai.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pembayaran berhasil disetujui! Status menjadi Diverifikasi.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyetujui pembayaran: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Aksi 2: Tolak Pembayaran (Dengan Input Alasan) ──
  Future<void> _handleTolakPembayaran() async {
    final reasonCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 8),
            Text('Tolak Pembayaran'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Masukkan alasan penolakan bukti pembayaran:'),
              const SizedBox(height: 10),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Nominal transfer tidak sesuai / Bukti tidak terbaca',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Alasan penolakan wajib diisi' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Tolak Transaksi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final adminId = _adminUser?.id ?? '';
    if (adminId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi admin berakhir. Silakan login kembali.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await AdminTransactionService.verifikasiPembayaran(
        transaksiId: widget.transaksiId,
        disetujui: false,
        adminId: adminId,
        catatan: reasonCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Transaksi telah ditolak.'),
            backgroundColor: Colors.red,
          ),
        );
        _loadDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak pembayaran: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Aksi 3: Catat Penerusan ke Mitra (Wallex / Instarem) ──
  Future<void> _handleCatatPenerusanMitra() async {
    if (_referensiMitraCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nomor referensi transaksi dari mitra luar negeri!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final adminId = _adminUser?.id ?? '';
    if (adminId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi admin berakhir. Silakan login kembali.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await AdminTransactionService.catatPenerusanMitra(
        transaksiId: widget.transaksiId,
        mitraRemitansi: _selectedMitra,
        referensiMitra: _referensiMitraCtrl.text.trim(),
        adminId: adminId,
        catatan: _catatanAdminCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🚀 Penerusan dana ke $_selectedMitra berhasil dicatat! Status: Diteruskan.'),
            backgroundColor: Colors.purple.shade700,
          ),
        );
        _loadDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencatat penerusan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Aksi 4: Selesaikan Transaksi ──
  Future<void> _handleSelesaikanTransaksi() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green),
            SizedBox(width: 8),
            Text('Tandai Selesai?'),
          ],
        ),
        content: const Text(
          'Pastikan dana telah sukses terkirim ke rekening penerima luar negeri melalui mitra remitansi.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Selesaikan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final adminId = _adminUser?.id ?? '';
    if (adminId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesi admin berakhir. Silakan login kembali.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await AdminTransactionService.selesaikanTransaksi(
        transaksiId: widget.transaksiId,
        adminId: adminId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Transaksi telah ditandai Selesai!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan transaksi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          'Detail Transaksi: ${_transaksi?["referensi_transaksi"] ?? _transaksi?["referensi_trans"] ?? widget.transaksiId}',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true), // return true to refresh list
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _transaksi == null
                  ? const Center(child: Text('Data transaksi tidak ditemukan'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Status Banner Atas ──
                          _buildStatusBanner(),

                          const SizedBox(height: 24),

                          // ── Grid 2 Kolom Komprehensif ──
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Kolom Kiri: Nasabah, Profil Risiko, Penerima
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    _buildPengirimCard(),
                                    const SizedBox(height: 20),
                                    _buildProfilRisikoCard(),
                                    const SizedBox(height: 20),
                                    _buildPenerimaCard(),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 24),

                              // Kolom Kanan: Rincian Finansial & Panel Aksi Operasional
                              Expanded(
                                flex: 5,
                                child: Column(
                                  children: [
                                    _buildFinansialCard(),
                                    const SizedBox(height: 20),
                                    _buildActionPanel(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
    );
  }

  // ── 1. Status Banner ──
  Widget _buildStatusBanner() {
    final sp = _transaksi!['status_pembayaran']?.toString() ?? 'menunggu_pembayaran';
    final st = _transaksi!['status_transfer']?.toString() ?? 'diproses';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'Status Pembayaran: ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              StatusBadge(status: sp, isPaymentStatus: true),
              const SizedBox(width: 20),
              const Text(
                'Status Transfer: ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              StatusBadge(status: st, isPaymentStatus: false),
            ],
          ),
          Text(
            'Dibuat: ${_formatTanggal(_transaksi!["dibuat_pada"]?.toString())}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  // ── 2. Card Data Pengirim (Nasabah) ──
  Widget _buildPengirimCard() {
    final pengguna = _transaksi!['pengguna'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.person_rounded, 'Data Nasabah Pengirim (KYC)'),
          const Divider(height: 24),
          _buildInfoRow('Nama Lengkap', pengguna?['nama_lengkap']?.toString() ?? '-'),
          _buildInfoRow('NIK (KTP)', pengguna?['nik']?.toString() ?? '-'),
          _buildInfoRow('Email', pengguna?['email']?.toString() ?? '-'),
          _buildInfoRow('Nomor Telepon', pengguna?['nomor_telepon']?.toString() ?? '-'),
          _buildInfoRow('Profesi Nasabah', pengguna?['profesi']?.toString() ?? '-'),
          _buildInfoRow('Alamat Domisili', pengguna?['alamat']?.toString() ?? '-'),
        ],
      ),
    );
  }

  // ── 3. Card Profil Risiko APU-PPT ──
  Widget _buildProfilRisikoCard() {
    final pengguna = _transaksi!['pengguna'] as Map<String, dynamic>?;
    // Kolom 'pekerjaan' diisi tujuan transfer kuesioner profil risiko
    final maksudKuesioner = pengguna?['pekerjaan']?.toString() ?? '-';
    final sumberDana = pengguna?['sumber_dana']?.toString() ?? '-';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.security_rounded, 'Kepatuhan APU-PPT & Profil Risiko'),
          const Divider(height: 24),
          _buildInfoRow('Sumber Dana', sumberDana),
          _buildInfoRow('Maksud/Tujuan Transfer', maksudKuesioner),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kuesioner APU-PPT wajib disimpan untuk kepatuhan regulasi Bank Indonesia.',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Card Data Penerima ──
  Widget _buildPenerimaCard() {
    final penerima = _transaksi!['nama_penerima']?.toString() ?? '-';
    final rek = _transaksi!['no_rek_penerima']?.toString() ?? '-';
    final bank = _transaksi!['bank_penerima']?.toString() ?? '-';
    final cur = _transaksi!['mata_uang_tujuan']?.toString() ?? '-';
    final tujuanTransfer = _transaksi!['tujuan_transfer']?.toString() ?? '-';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.call_made_rounded, 'Data Penerima Luar Negeri'),
          const Divider(height: 24),
          _buildInfoRow('Nama Penerima', penerima),
          _buildInfoRow('Bank Penerima', bank),
          _buildInfoRow('Nomor Rekening', rek),
          _buildInfoRow('Mata Uang Tujuan', cur),
          _buildInfoRow('Tujuan Transaksi Ini', tujuanTransfer),
        ],
      ),
    );
  }

  // ── 5. Card Rincian Finansial ──
  Widget _buildFinansialCard() {
    final nominalIdr = _transaksi!['nominal_idr'] as num?;
    final kurs = _transaksi!['kurs_pertukaran'] as num?;
    final fee = _transaksi!['biaya_transfer'] as num?;
    final valas = _transaksi!['nominal_asing'] as num?;
    final cur = _transaksi!['mata_uang_tujuan']?.toString() ?? '';
    final totalBayar = (nominalIdr ?? 0) + (fee ?? 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(Icons.payments_rounded, 'Rincian Finansial'),
          const Divider(height: 24),
          _buildInfoRow('Nominal Kirim (IDR)', _formatRupiah(nominalIdr)),
          _buildInfoRow('Kurs Konversi', '1 $cur = ${_formatRupiah(kurs)}'),
          _buildInfoRow('Biaya Transfer / Fee', _formatRupiah(fee)),
          const Divider(height: 16),
          _buildInfoRow('Total Dibayar Nasabah', _formatRupiah(totalBayar), isBold: true),
          _buildInfoRow(
            'Penerima Menerima (Valas)',
            '${valas != null ? valas.toStringAsFixed(2) : "0"} $cur',
            isBold: true,
            valueColor: Colors.green.shade700,
          ),
          _buildInfoRow('Metode Pembayaran', _transaksi!['metode_pembayaran']?.toString() ?? 'QRIS'),
        ],
      ),
    );
  }

  // ── 6. Panel Aksi Operasional Admin ──
  Widget _buildActionPanel() {
    final st = (_transaksi!['status_transfer']?.toString() ?? 'diproses').toLowerCase();
    final sp = (_transaksi!['status_pembayaran']?.toString() ?? '').toLowerCase();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCardHeader(Icons.admin_panel_settings, 'Tindakan Operasional Admin'),
          const Divider(height: 24),

          // TAHAP 1: VERIFIKASI PEMBAYARAN
          if (st == 'diproses' || (st == 'pending' && sp == 'dibayar')) ...[
            const Text(
              'Langkah 1: Verifikasi Pembayaran',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Periksa kesesuaian pembayaran nasabah. Jika dana sudah masuk, klik "Setujui Pembayaran".',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _handleSetujuiPembayaran,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Setujui Pembayaran'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _handleTolakPembayaran,
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Tolak'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ]

          // TAHAP 2: PENERUSAN DANA KE MITRA (WALLEX / INSTAREM)
          else if (st == 'diverifikasi' || st == 'diteruskan') ...[
            const Text(
              'Langkah 2: Penerusan Dana ke Mitra Luar Negeri',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Catat eksekusi pengiriman dana ke jaringan Wallex atau Instarem.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            // Dropdown Pilihan Mitra
            const Text('Pilih Mitra Remitansi:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedMitra,
              items: const [
                DropdownMenuItem(value: 'Wallex', child: Text('Wallex (Penyelenggara Resmi)')),
                DropdownMenuItem(value: 'Instarem', child: Text('Instarem (Penyelenggara Resmi)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedMitra = val);
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Input No. Referensi Mitra
            const Text('No. Referensi Mitra Luar Negeri:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _referensiMitraCtrl,
              decoration: const InputDecoration(
                hintText: 'Contoh: WLX-8932402 / INST-938210',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Catatan Tambahan
            const Text('Catatan Tambahan (Opsional):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _catatanAdminCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Catatan operasional jika ada...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),

            // Tombol Simpan Penerusan
            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _handleCatatPenerusanMitra,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Simpan / Perbarui Penerusan Mitra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            if (st == 'diteruskan') ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _handleSelesaikanTransaksi,
                icon: const Icon(Icons.check_circle_rounded, size: 16),
                label: const Text('Tandai Selesai (Dana Tiba)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ]

          // TAHAP 3: SELESAI ATAU GAGAL
          else if (st == 'selesai') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Transaksi Selesai',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Mitra: ${_transaksi!["mitra_remitansi"] ?? "-"}'),
                  Text('Ref Mitra: ${_transaksi!["referensi_mitra"] ?? "-"}'),
                  if (_transaksi!['catatan_admin'] != null)
                    Text('Catatan: ${_transaksi!["catatan_admin"]}'),
                ],
              ),
            ),
          ] else if (st == 'gagal') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cancel, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Transaksi Ditolak / Gagal',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Alasan: ${_transaksi!["catatan_admin"] ?? "Tidak ada catatan"}'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── UI Helper Widgets ──
  Widget _buildCardHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ),
          const Text(': ', style: TextStyle(color: Color(0xFF64748B))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
