// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'konfirmasi_pin_screen.dart';
import 'xendit_service.dart';

class QrPembayaranScreen extends StatefulWidget {
  final String userId;
  final String negaraTujuan;
  final String currencyTujuan;
  final String namaPenerima;
  final String noRekening;
  final String bankPenerima;
  final String tujuanTransfer;
  final String sumberDana;
  final double nominalIDR;
  final Map<String, dynamic> mitra;

  const QrPembayaranScreen({
    super.key,
    required this.userId,
    required this.negaraTujuan,
    required this.currencyTujuan,
    required this.namaPenerima,
    required this.noRekening,
    required this.bankPenerima,
    required this.tujuanTransfer,
    required this.sumberDana,
    required this.nominalIDR,
    required this.mitra,
  });

  @override
  State<QrPembayaranScreen> createState() => _QrPembayaranScreenState();
}

class _QrPembayaranScreenState extends State<QrPembayaranScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isCreating = true;
  bool _isExpired = false;
  String _transaksiId = '';
  String _referensiTrans = '';
  String _qrPayload      = '';
  String _xenditQrId     = '';   // ID QR dari Xendit untuk polling
  Timer? _pollingTimer;          // Polling status setiap 5 detik
  bool   _isPaid         = false; // True saat pembayaran dikonfirmasi Xendit
  late DateTime _batasWaktu;
  int _sisaDetik = 15 * 60; // 15 menit
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _buatTransaksi();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── Generate referensi unik ────────────────────────────────────────────────
  String _generateReferensi() {
    final now = DateTime.now();
    final rand = Random().nextInt(9999).toString().padLeft(4, '0');
    return 'TRX${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}$rand';
  }

  // ── Buat transaksi di Supabase & mulai timer ──────────────────────────────
  Future<void> _buatTransaksi() async {
    setState(() => _isCreating = true);

    try {
      final referensi = _generateReferensi();
      _batasWaktu = DateTime.now().add(const Duration(minutes: 15));

      // ── Buat QR QRIS nyata via Xendit ──────────────────────────────────────
      final xenditResult = await XenditService.buatQrisCode(
        referensiTransaksi : referensi,
        nominalIDR         : widget.mitra['total_bayar'] as double,
        deskripsi          : 'Transfer ke ${widget.negaraTujuan} - ${widget.namaPenerima}',
      );
      final qrPayload  = xenditResult['qr_string']   as String;
      final xenditQrId = xenditResult['xendit_qr_id'] as String;

      // Simpan transaksi ke Supabase dengan status 'menunggu_pembayaran'
      final response = await Supabase.instance.client
          .from('transaksi')
          .insert({
            'id_pengguna'          : widget.userId,
            'referensi_transaksi'  : referensi,
            'nominal_idr'          : widget.nominalIDR,
            'kurs_pertukaran'      : widget.mitra['kurs'],
            'biaya_transfer'       : widget.mitra['total_biaya'],
            'nominal_asing'        : widget.mitra['valas_diterima'],
            'mata_uang_tujuan'     : widget.currencyTujuan,
            'metode_pembayaran'    : 'QRIS',
            'payload_kode_qr'      : qrPayload,
            'status_pembayaran'    : 'menunggu_pembayaran',
            'status_transfer'      : 'pending',
            'nama_penerima'        : widget.namaPenerima,
            'no_rek_penerima'      : widget.noRekening,
            'bank_penerima'        : widget.bankPenerima,
            'tujuan_transfer'      : widget.tujuanTransfer,
            'dibuat_pada'          : DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      if (!mounted) return;

      setState(() {
        _transaksiId    = response['id'].toString();
        _referensiTrans = referensi;
        _qrPayload      = qrPayload;
        _xenditQrId     = xenditQrId;
        _isCreating     = false;
        _sisaDetik      = 15 * 60;
      });
      _mulaiPollingPembayaran();

      _mulaiTimer();
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        if (errStr.contains('QRIS_LIMIT_EXCEEDED') || (errStr.contains('400') && errStr.contains('API_VALIDATION_ERROR'))) {
          // QRIS hanya support s.d. Rp 10 juta per transaksi
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Row(children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text('Nominal Terlalu Besar untuk QRIS', style: TextStyle(fontSize: 16))),
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'QRIS hanya mendukung pembayaran hingga Rp 10.000.000 per transaksi.',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Untuk transaksi di atas Rp 10 juta, gunakan metode:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        SizedBox(height: 6),
                        Text('• Transfer Bank / Virtual Account', style: TextStyle(fontSize: 13)),
                        Text('• Datang langsung ke kantor', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // tutup dialog
                    Navigator.pop(context); // kembali ke kalkulasi
                  },
                  child: const Text('Mengerti'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal membuat transaksi: $e'), backgroundColor: Colors.red),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  void _mulaiTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      final sisa = _batasWaktu.difference(DateTime.now()).inSeconds;
      if (sisa <= 0) {
        t.cancel();
        _tandaiExpired();
      } else {
        setState(() => _sisaDetik = sisa);
      }
    });
  }

  Future<void> _tandaiExpired() async {
    setState(() => _isExpired = true);
    try {
      await Supabase.instance.client
          .from('transaksi')
          .update({'status_pembayaran': 'expired'})
          .eq('id', _transaksiId);
    } catch (_) {}
  }

  void _lanjutKonfirmasiPin() {
    if (_isExpired) return;
    _timer?.cancel();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KonfirmasiPinScreen(
          transaksiId   : _transaksiId,
          referensiTrans: _referensiTrans,
          userId        : widget.userId,
          nominalIDR    : widget.nominalIDR,
          totalBayar    : widget.mitra['total_bayar'] as double,
          namaPenerima  : widget.namaPenerima,
          negaraTujuan  : widget.negaraTujuan,
          currencyTujuan: widget.currencyTujuan,
          valas         : widget.mitra['valas_diterima'] as double,
          namaMitra     : widget.mitra['nama_mitra']?.toString() ?? '-',
        ),
      ),
    );
  }

  // ── Format waktu countdown ─────────────────────────────────────────────────
  String get _waktuCountdown {
    final menit = _sisaDetik ~/ 60;
    final detik = _sisaDetik % 60;
    return '${menit.toString().padLeft(2, '0')}:${detik.toString().padLeft(2, '0')}';
  }

  Color get _warnaTimer {
    if (_sisaDetik > 5 * 60) return Colors.green[600]!;
    if (_sisaDetik > 2 * 60) return Colors.orange[700]!;
    return Colors.red[700]!;
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
          'Scan QR Pembayaran',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isCreating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Menyiapkan QR Code...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Header info nominal ─────────────────────────────────
                  _buildNominalCard(),
                  const SizedBox(height: 20),

                  // ── QR Code / Expired ───────────────────────────────────
                  _buildQrArea(),
                  const SizedBox(height: 20),

                  // ── Instruksi ──────────────────────────────────────────
                  if (!_isExpired) _buildInstruksi(),
                  const SizedBox(height: 24),

                  // ── Tombol aksi ────────────────────────────────────────
                  if (_isExpired)
                    _buildExpiredAction()
                  else
                    _buildKonfirmasiButton(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ── Widget Helpers ─────────────────────────────────────────────────────────

  Widget _buildNominalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Pembayaran',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    _formatRupiah(widget.mitra['total_bayar'] as double),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Penerima mendapat',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatValas(widget.mitra['valas_diterima'] as double)} ${widget.currencyTujuan}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withOpacity(0.3), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ref: $_referensiTrans',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              Text(widget.namaPenerima,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQrArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isExpired ? Colors.red[200]! : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isExpired)
            // ── Expired state ──────────────────────────────────────────
            Column(
              children: [
                Icon(Icons.timer_off_rounded, color: Colors.red[400], size: 64),
                const SizedBox(height: 12),
                Text(
                  'QR Code Kadaluarsa',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Batas waktu 15 menit telah habis.\nSilakan buat transaksi baru.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ],
            )
          else ...[
            // ── Timer countdown ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_rounded, size: 16, color: _warnaTimer),
                const SizedBox(width: 6),
                Text(
                  'Berlaku selama $_waktuCountdown',
                  style: TextStyle(
                    color: _warnaTimer,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── QR Image ───────────────────────────────────────────────
            QrImageView(
              data: _qrPayload,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
            const SizedBox(height: 12),

            // ── Label mitra ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.mitra['nama_mitra']?.toString() ?? '-',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstruksi() {
    final steps = [
      'Buka aplikasi mobile banking atau e-wallet Anda',
      'Pilih menu "Scan QR" atau "QRIS"',
      'Arahkan kamera ke QR Code di atas',
      'Konfirmasi pembayaran di aplikasi bank Anda',
      'Setelah selesai, tekan tombol "Sudah Bayar" di bawah',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 6),
              Text(
                'Cara Pembayaran',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1, right: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildKonfirmasiButton() {
    return Column(
      children: [
        // ── Indikator polling — muncul saat menunggu pembayaran ───────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade700),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Menunggu konfirmasi pembayaran...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),

      ],
    );
  }

  Widget _buildExpiredAction() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // kembali ke kalkulasi untuk buat ulang
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: const Text(
              'Buat Transaksi Baru',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ── Format ─────────────────────────────────────────────────────────────────
  // ── Polling status Xendit setiap 5 detik ────────────────────────────────────
  void _mulaiPollingPembayaran() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_isExpired || _isPaid || _xenditQrId.isEmpty) {
        _pollingTimer?.cancel();
        return;
      }
      try {
        final status = await XenditService.cekStatusQr(_xenditQrId);
        debugPrint('Polling status: $status');
        // PAID/SUCCEEDED = dibayar via webhook
        // INACTIVE = dibayar via simulate (Xendit Test Mode)
        if (status == 'PAID' || status == 'SUCCEEDED' || status == 'INACTIVE') {
          _pollingTimer?.cancel();
          await Supabase.instance.client
              .from('transaksi')
              .update({'status_pembayaran': 'pembayaran_diterima'})
              .eq('id', _transaksiId);
          if (!mounted) return;
          setState(() => _isPaid = true);
          _lanjutKonfirmasiPin();
        } else if (status == 'EXPIRED') {
          // Benar-benar expired tanpa dibayar
          _pollingTimer?.cancel();
          if (!mounted) return;
          setState(() => _isExpired = true);
        }
      } catch (e) {
        debugPrint('Polling error (diabaikan): $e');
      }
    });
  }


    String _formatRupiah(double value) {
    final parts = value.toStringAsFixed(0).split('');
    String f = '';
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) f += '.';
      f += parts[i];
    }
    return 'Rp $f';
  }

  String _formatValas(double value) {
    if (value >= 1000) {
      return value.toStringAsFixed(2).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
    }
    return value.toStringAsFixed(2);
  }
}