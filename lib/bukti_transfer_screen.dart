// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'landing_page_screen.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BuktiTransferScreen extends StatefulWidget {
  final String transaksiId;
  final String referensiTrans;
  final String userId;
  final double nominalIDR;
  final double totalBayar;
  final String namaPenerima;
  final String negaraTujuan;
  final String currencyTujuan;
  final double valas;
  final String namaMitra;
  final DateTime waktuTransaksi;

  const BuktiTransferScreen({
    super.key,
    required this.transaksiId,
    required this.referensiTrans,
    required this.userId,
    required this.nominalIDR,
    required this.totalBayar,
    required this.namaPenerima,
    required this.negaraTujuan,
    required this.currencyTujuan,
    required this.valas,
    required this.namaMitra,
    required this.waktuTransaksi,
  });

  @override
  State<BuktiTransferScreen> createState() => _BuktiTransferScreenState();
}

class _BuktiTransferScreenState extends State<BuktiTransferScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _detailTransaksi;
  bool _isLoading = true;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);

    _loadDetailTransaksi();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDetailTransaksi() async {
    try {
      final data = await Supabase.instance.client
          .from('transaksi')
          .select()
          .eq('id', widget.transaksiId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _detailTransaksi = data;
          _isLoading = false;
        });
        _animCtrl.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _animCtrl.forward();
      }
    }
  }

  // ── Salin referensi ke clipboard ──────────────────────────────────────────
  void _salinReferensi() {
    Clipboard.setData(ClipboardData(text: widget.referensiTrans));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Nomor referensi disalin'),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Share teks bukti ──────────────────────────────────────────────────────
  // ── Fungsi Share Bukti Berbentuk Gambar ──
  Future<void> _bagikanBukti() async {
    try {
      // Tampilkan loading sebentar proses convert
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sedang menyiapkan gambar bukti...'),
          duration: Duration(milliseconds: 800),
        ),
      );

      // 1. Ambil object render dari RepaintBoundary
      final RenderRepaintBoundary boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      // 2. Convert menjadi gambar UI (pixelRatio: 3.0 biar gambar tajam/HD)
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 3. Simpan sementara ke storage local HP
      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/Bukti_Transfer_${widget.referensiTrans}.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      // 4. Panggil pop-up share bawaan Android/iOS
      await Share.shareXFiles([
        XFile(file.path),
      ],);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membagikan gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Kembali ke halaman utama ───────────────────────────────────────────────
  void _kembaliHome() {
    // Tunggu frame selesai sebelum navigasi — cegah _debugLocked assertion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LandingPageScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Cegah back button — user harus tekan tombol selesai
      onPopInvoked: (_) => _kembaliHome(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          automaticallyImplyLeading: false,
          title: const Text(
            'Bukti Transfer',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // ── BUNGKUS DENGAN REPAINTBOUNDARY DI SINI ──
                      RepaintBoundary(
                        key: _boundaryKey,
                        child: Container(
                          // Set warna background solid agar hasil gambar tidak transparan/bolong
                          color: Colors.grey[50],
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: [
                              // ── Animasi sukses ──
                              ScaleTransition(
                                scale: _scaleAnim,
                                child: _buildSuksesHeader(),
                              ),
                              const SizedBox(height: 20),

                              // ── Resi detail ──
                              _buildResiCard(),
                            ],
                          ),
                        ),
                      ),

                      // ─────────────────────────────────────────────
                      const SizedBox(height: 16),

                      // ── Tracking info (Biarkan di luar boundary jika tidak mau ikut kefoto) ──
                      _buildTrackingInfo(),
                      const SizedBox(height: 24),

                      // ── Tombol aksi ──
                      _buildActionButtons(),
                      const SizedBox(height: 16),

                      // ── Tombol selesai ─────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _kembaliHome,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Selesai',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ── Widget Helpers ─────────────────────────────────────────────────────────

  Widget _buildSuksesHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[600]!, Colors.green[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Transfer Diproses!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatRupiah(widget.totalBayar),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatValas(widget.valas)} ${widget.currencyTujuan} ditujukan kepada ${widget.namaPenerima}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildResiCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header resi
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Detail Transaksi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Nomor referensi (bisa disalin)
          _buildResiRowWithCopy('No. Referensi', widget.referensiTrans),
          _buildDivider(),
          _buildResiRow(
            'Tanggal & Waktu',
            _formatTanggal(widget.waktuTransaksi),
          ),
          _buildDivider(),
          _buildResiRow('Nama Penerima', widget.namaPenerima),
          _buildDivider(),
          _buildResiRow('Negara Tujuan', widget.negaraTujuan),
          _buildDivider(),
          _buildResiRow('Mitra Transfer', widget.namaMitra),
          _buildDivider(),
          _buildResiRow('Nominal Dikirim', _formatRupiah(widget.nominalIDR)),

          // Biaya hanya jika beda dengan nominal
          if (widget.totalBayar > widget.nominalIDR) ...[
            _buildDivider(),
            _buildResiRow(
              'Biaya Transfer',
              _formatRupiah(widget.totalBayar - widget.nominalIDR),
            ),
          ],
          _buildDivider(),

          // Total bayar (highlighted)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Dibayar',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatRupiah(widget.totalBayar),
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          _buildDivider(),

          // Penerima dapat (highlighted green)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Penerima Mendapat',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_formatValas(widget.valas)} ${widget.currencyTujuan}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingInfo() {
    final statusTransfer =
        _detailTransaksi?['status_transfer']?.toString() ?? 'diproses';

    final steps = [
      {
        'label': 'Pembayaran Diterima',
        'desc': 'Dana berhasil diterima sistem',
        'done': true,
      },
      {
        'label': 'Diverifikasi',
        'desc': 'Transaksi sedang diverifikasi',
        'done': statusTransfer != 'pending',
      },
      {
        'label': 'Diproses Mitra',
        'desc': 'Mitra sedang memproses transfer',
        'done': statusTransfer == 'dikirim' || statusTransfer == 'selesai',
      },
      {
        'label': 'Transfer Selesai',
        'desc': 'Dana terkirim ke penerima',
        'done': statusTransfer == 'selesai',
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.track_changes_rounded,
                color: Colors.blue[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Status Transfer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((e) {
            final isLast = e.key == steps.length - 1;
            final step = e.value;
            final isDone = step['done'] as bool;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? Colors.green[600] : Colors.grey[200],
                        border: Border.all(
                          color: isDone
                              ? Colors.green[600]!
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : Icons.circle_outlined,
                        size: 16,
                        color: isDone ? Colors.white : Colors.grey,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 36,
                        color: isDone ? Colors.green[200] : Colors.grey[200],
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['label'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isDone ? Colors.black87 : Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step['desc'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDone ? Colors.grey[600] : Colors.grey[300],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        
        //const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _bagikanBukti,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Bagikan'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue[700],
              side: BorderSide(color: Colors.blue[300]!),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Row helpers ────────────────────────────────────────────────────────────

  Widget _buildResiRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResiRowWithCopy(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          GestureDetector(
            onTap: _salinReferensi,
            child: Row(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.copy_rounded, size: 14, color: Colors.blue[400]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey.shade100);
  }

  // ── Format ─────────────────────────────────────────────────────────────────

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
      return value
          .toStringAsFixed(2)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
    }
    return value.toStringAsFixed(2);
  }

  String _formatTanggal(DateTime dt) {
    const bulan = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day} ${bulan[dt.month]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
  }
}
