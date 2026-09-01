// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RiwayatPage extends StatefulWidget {
  const RiwayatPage({super.key});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

class _RiwayatPageState extends State<RiwayatPage> {
  List<Map<String, dynamic>> _transaksi = [];
  bool _isLoading = true;
  bool _isError   = false;
  String _userId  = '';

  // ── Filter state ───────────────────────────────────────────────────────────
  String _filterStatus = 'Semua'; // Semua | menunggu_pembayaran | dibayar | gagal | expired
  static const List<String> _filterOptions = [
    'Semua', 'Diproses', 'Berhasil', 'Gagal',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('userId') ?? '';
    setState(() => _userId = uid);
    await _fetchRiwayat();
  }

  Future<void> _fetchRiwayat() async {
    if (_userId.isEmpty) {
      setState(() { _isLoading = false; _isError = true; });
      return;
    }

    setState(() { _isLoading = true; _isError = false; });

    try {
      // Ambil semua transaksi user, terbaru dulu
      final data = await Supabase.instance.client
          .from('transaksi')
          .select()
          .eq('id_pengguna', _userId)
          .order('dibuat_pada', ascending: false);

      if (mounted) {
        setState(() {
          _transaksi = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; _isError = true; });
      }
    }
  }

  // ── Filter transaksi ───────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _transaksiFiltered {
    if (_filterStatus == 'Semua') return _transaksi;

    final Map<String, List<String>> statusMap = {
      'Diproses': ['menunggu_pembayaran', 'dibayar', 'diverifikasi', 'diteruskan', 'pending'],
      'Berhasil': ['selesai'],
      'Gagal'   : ['gagal', 'expired'],
    };

    final targetStatuses = statusMap[_filterStatus] ?? [];
    return _transaksi.where((t) {
      final sp = t['status_pembayaran']?.toString() ?? '';
      final st = t['status_transfer']?.toString()   ?? '';
      return targetStatuses.contains(sp) || targetStatuses.contains(st);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Riwayat Pengiriman',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        actions: [
          // Tombol refresh
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black),
            onPressed: _fetchRiwayat,
            tooltip: 'Perbarui',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chip row ──────────────────────────────────────────────
          _buildFilterRow(),

          // ── Content ──────────────────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── Filter Row ─────────────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filterOptions.map((opt) {
            final isSelected = _filterStatus == opt;
            return GestureDetector(
              onTap: () => setState(() => _filterStatus = opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[700] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? Colors.blue[700]! : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Gagal memuat data',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchRiwayat,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    final list = _transaksiFiltered;

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 14),
            Text(
              _filterStatus == 'Semua'
                  ? 'Belum ada transaksi'
                  : 'Tidak ada transaksi "$_filterStatus"',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'Transaksi yang kamu buat akan muncul di sini',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRiwayat,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildTrxCard(list[index]),
      ),
    );
  }

  // ── Card per transaksi ─────────────────────────────────────────────────────
  Widget _buildTrxCard(Map<String, dynamic> trx) {
    final String namaPenerima  = trx['nama_penerima']?.toString()   ?? '-';
    final String matauang      = trx['mata_uang_tujuan']?.toString() ?? '-';
    final String negara        = trx['bank_penerima']?.toString()    ?? '-'; // bank sebagai sub-info
    final double nominalIdr    = (trx['nominal_idr']    as num?)?.toDouble() ?? 0;
    final double nominalAsing  = (trx['nominal_asing']  as num?)?.toDouble() ?? 0;
    final double kurs          = (trx['kurs_pertukaran'] as num?)?.toDouble() ?? 0;
    final double biaya         = (trx['biaya_transfer'] as num?)?.toDouble() ?? 0;
    final String statusP       = trx['status_pembayaran']?.toString() ?? '';
    final String statusT       = trx['status_transfer']?.toString()   ?? '';
    final String referensi     = trx['referensi_trans']?.toString()   ?? '-';
    final String rawTanggal    = trx['dibuat_pada']?.toString()       ?? '';

    // ── Tentukan status tampilan ─────────────────────────────────────────────
    final _StatusInfo statusInfo = _resolveStatus(statusP, statusT);

    return GestureDetector(
      onTap: () => _showDetailBottomSheet(context, trx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(children: [
          // ── Baris atas: nama + status badge ───────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                CircleAvatar(
                  backgroundColor: statusInfo.color.withOpacity(0.12),
                  child: Icon(statusInfo.icon, color: statusInfo.color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(namaPenerima,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    '$matauang · $negara',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ]),
              ]),
              _buildStatusBadge(statusInfo),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),

          // ── Baris tengah: nominal kirim → nominal terima ───────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Jumlah Dikirim',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                Text(_formatRupiah(nominalIdr),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Penerima Mendapat',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                Text(
                  '${_formatValas(nominalAsing)} $matauang',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700]),
                ),
              ]),
            ],
          ),

          const SizedBox(height: 8),

          // ── Baris bawah: kurs & tanggal ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTanggal(rawTanggal),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (kurs > 0)
                Text(
                  'Kurs: 1 $matauang = ${_formatRupiah(kurs)}',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Bottom sheet detail ───────────────────────────────────────────────────
  void _showDetailBottomSheet(
      BuildContext context, Map<String, dynamic> trx) {
    final String namaPenerima = trx['nama_penerima']?.toString()    ?? '-';
    final String matauang     = trx['mata_uang_tujuan']?.toString() ?? '-';
    final double nominalIdr   = (trx['nominal_idr']    as num?)?.toDouble() ?? 0;
    final double nominalAsing = (trx['nominal_asing']  as num?)?.toDouble() ?? 0;
    final double biaya        = (trx['biaya_transfer'] as num?)?.toDouble() ?? 0;
    final double kurs         = (trx['kurs_pertukaran'] as num?)?.toDouble() ?? 0;
    final String referensi    = trx['referensi_trans']?.toString()   ?? '-';
    final String rawTanggal   = trx['dibuat_pada']?.toString()       ?? '';
    final String statusP      = trx['status_pembayaran']?.toString() ?? '';
    final String statusT      = trx['status_transfer']?.toString()   ?? '';
    final String bankPenerima = trx['bank_penerima']?.toString()     ?? '-';
    final String noRek        = trx['no_rek_penerima']?.toString() ?? '-';
    final String tujuan       = trx['tujuan_transfer']?.toString()   ?? '-';
    final String mitra        = trx['nama_mitra']?.toString()        ?? '-'; // jika disimpan

    final _StatusInfo statusInfo = _resolveStatus(statusP, statusT);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                children: [
                  // Header
                  Row(children: [
                    Icon(statusInfo.icon, color: statusInfo.color, size: 22),
                    const SizedBox(width: 10),
                    Text('Detail Transaksi',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    _buildStatusBadge(statusInfo),
                  ]),
                  const SizedBox(height: 16),

                  // Ringkasan nominal
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Kamu kirim',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          Text(_formatRupiah(nominalIdr),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                        ]),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.blue[300], size: 18),
                        Column(crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                          const Text('Penerima dapat',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          Text(
                            '${_formatValas(nominalAsing)} $matauang',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue[700]),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Detail rows
                  _detailRow('No. Referensi', referensi,
                      isHighlight: true),
                  _detailRow('Tanggal', _formatTanggal(rawTanggal)),
                  _detailRow('Nama Penerima', namaPenerima),
                  _detailRow('Bank Penerima', bankPenerima),
                  _detailRow('No. Rekening', noRek),
                  _detailRow('Mata Uang Tujuan', matauang),
                  _detailRow('Kurs', kurs > 0
                      ? '1 $matauang = ${_formatRupiah(kurs)}'
                      : '-'),
                  _detailRow('Biaya Transfer', _formatRupiah(biaya)),
                  _detailRow('Tujuan Transfer', tujuan),
                  const Divider(height: 24),
                  _detailRow(
                    'Total Dibayar',
                    _formatRupiah(nominalIdr + biaya),
                    isBold: true,
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _buildStatusBadge(_StatusInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        info.label,
        style: TextStyle(
          color: info.color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: isHighlight ? Colors.blue[700] : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Resolve status dari 2 kolom (status_pembayaran + status_transfer) ───────
  _StatusInfo _resolveStatus(String statusP, String statusT) {
    // Prioritas: gagal/expired → selesai → dalam proses
    if (statusP == 'gagal' || statusT == 'gagal') {
      return _StatusInfo('Gagal', Colors.red, Icons.error_outline_rounded);
    }
    if (statusP == 'expired') {
      return _StatusInfo('Kadaluarsa', Colors.red[300]!, Icons.timer_off_rounded);
    }
    if (statusT == 'selesai') {
      return _StatusInfo('Berhasil', Colors.green, Icons.check_circle_outline_rounded);
    }
    if (statusP == 'menunggu_pembayaran') {
      return _StatusInfo('Menunggu Bayar', Colors.orange, Icons.hourglass_top_rounded);
    }
    // Semua status "dalam proses": dibayar, diverifikasi, diteruskan, pending
    return _StatusInfo('Diproses', Colors.blue[600]!, Icons.pending_actions_rounded);
  }

  // ── Format helpers ─────────────────────────────────────────────────────────

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

  String _formatTanggal(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      const bulan = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${bulan[dt.month]} ${dt.year}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Helper class untuk status ──────────────────────────────────────────────

class _StatusInfo {
  final String label;
  final Color  color;
  final IconData icon;
  const _StatusInfo(this.label, this.color, this.icon);
}