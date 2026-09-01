// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'qr_pembayaran_screen.dart';

class KalkulasiScreen extends StatefulWidget {
  final String userId;
  final String negaraTujuan;
  final String currencyTujuan;
  final String namaPenerima;
  final String noRekening;
  final String bankPenerima;
  final double limitTransaksi;
  final String tujuanTransfer;
  final String sumberDana;

  const KalkulasiScreen({
    super.key,
    required this.userId,
    required this.negaraTujuan,
    required this.currencyTujuan,
    required this.namaPenerima,
    required this.noRekening,
    required this.bankPenerima,
    required this.limitTransaksi,
    required this.tujuanTransfer,
    required this.sumberDana,
  });

  @override
  State<KalkulasiScreen> createState() => _KalkulasiScreenState();
}

class _KalkulasiScreenState extends State<KalkulasiScreen> {
  final _nominalCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoadingMitra = false;
  bool _isNominalValid = false;
  double _nominalIDR    = 0;
  double _totalBulanIni  = 0;     // Total nominal IDR transaksi user bulan ini
  double _kursUSDtoIDR   = 16000; // Kurs USD→IDR live, default fallback
  // Limit regulasi: 50.000 USD / bulan per user
  static const double _limitUSD = 50000;

  // Hasil rekomendasi — hanya 1 mitra terbaik yang ditampilkan ke user
  Map<String, dynamic>? _mitraRekomen;
  // Data semua mitra (untuk tampilan perbandingan transparan)
  List<Map<String, dynamic>> _semuaMitra = [];

  // ── Kurs referensi fallback ────────────────────────────────────────────────
  final Map<String, double> _kursReferensi = {
    'MYR': 3969.0,  'SGD': 12789.0, 'THB': 505.0,   'PHP': 278.0,
    'VND': 0.65,    'KHR': 4.05,    'MMK': 4.33,     'JPY': 106.0,
    'KRW': 11.4,    'CNY': 2389.0,  'HKD': 2065.0,   'INR': 183.0,
    'BDT': 134.0,   'NPR': 116.0,   'PKR': 61.0,     'LKR': 54.0,
    'SAR': 4519.0,  'AED': 4676.0,  'EGP': 316.0,    'USD': 16185.0,
    'GBP': 16898.0, 'EUR': 19695.0, 'AUD': 11327.0,  'CAD': 11964.0,
    'BRL': 3370.0,  'TRY': 387.0,   'NGN': 11.9,     'GHS': 1373.0,
    'MNT': 4.83,
  };

  @override
  void dispose() {
    _nominalCtrl.dispose();
    super.dispose();
  }

  // ── Logika rekomendasi (identik dengan notebook Python teman) ─────────────
  //
  // Untuk setiap mitra dengan kurs > 0, hitung "skor total":
  //   - Transferku : total = kurs × (1 + margin) + fee
  //   - Mitra lain : total = kurs + fee
  // Pemenang = mitra dengan skor total TERKECIL.
  //
  // Catatan: skor ini bukan biaya yang dibayar user — ini adalah "kurs efektif"
  // per 1 unit valas. Skor terkecil = user dapat valas terbanyak per rupiah.
  // ─────────────────────────────────────────────────────────────────────────

  Map<String, dynamic> _hitungSkorMitra(Map<String, dynamic> row, double nominalIdr) {
    final String namaMitra = row['nama_mitra']?.toString() ?? '';
    final double kurs      = (row['kurs_jual']  as num?)?.toDouble() ?? 0;
    final double margin    = (row['fx_margin']  as num?)?.toDouble() ?? 0;
    final double fee       = (row['biaya_fee']  as num?)?.toDouble() ?? 0;

    if (kurs == 0) return {...row, 'valid': false, 'skor': double.infinity};

    // Biaya FX hanya untuk Transferku (sesuai notebook)
    final bool isTransferku = namaMitra.toLowerCase().contains('transferku');
    final double biayaFx    = isTransferku ? nominalIdr * margin : 0;
    final double totalBiaya = fee + biayaFx;
    final double totalBayar = nominalIdr + totalBiaya;
    final double valas      = nominalIdr / kurs;

    // Skor rekomendasi (lebih kecil = lebih baik)
    // Mengikuti formula notebook: kurs*(1+margin)+fee untuk Transferku, kurs+fee untuk lainnya
    final double skor = isTransferku ? (kurs * (1 + margin)) + fee : kurs + fee;

    return {
      ...row,
      'valid'        : true,
      'skor'         : skor,
      'kurs'         : kurs,
      'fee'          : fee,
      'biaya_fx'     : biayaFx,
      'total_biaya'  : totalBiaya,
      'total_bayar'  : totalBayar,
      'valas_diterima': valas,
      'is_transferku': isTransferku,
    };
  }

  // Fetch kurs USD→IDR live dari exchangerate-api.com
  Future<void> _fetchKursUSD() async {
    try {
      const apiKey = '10aa2066bb6854bd2d8f0199';
      final uri = Uri.parse(
        'https://v6.exchangerate-api.com/v6/$apiKey/pair/USD/IDR',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rate = (data['conversion_rate'] as num?)?.toDouble();
        if (rate != null && rate > 0 && mounted) {
          setState(() => _kursUSDtoIDR = rate);
          debugPrint('Kurs USD→IDR live: $_kursUSDtoIDR');
        }
      }
    } catch (e) {
      debugPrint('Gagal fetch kurs USD (pakai fallback): $e');
    }
  }

  // Ambil total nominal IDR transaksi user bulan berjalan dari Supabase
  // Reset otomatis setiap ganti bulan kalender
  Future<void> _hitungTotalBulanIni() async {
    try {
      final now  = DateTime.now();
      final awal = DateTime(now.year, now.month, 1).toIso8601String();
      final akhir = DateTime(now.year, now.month + 1, 1).toIso8601String();

      final rows = await Supabase.instance.client
          .from('transaksi')
          .select('nominal_idr')
          .eq('id_pengguna', widget.userId)
          .neq('status_pembayaran', 'gagal')
          .gte('dibuat_pada', awal)
          .lt('dibuat_pada', akhir);

      double total = 0;
      for (final r in rows) {
        total += (r['nominal_idr'] as num?)?.toDouble() ?? 0;
      }
      if (mounted) setState(() => _totalBulanIni = total);
    } catch (e) {
      debugPrint('Gagal ambil total bulan ini: $e');
    }
  }

  Future<void> _hitungDanRekomen() async {
    final raw    = _nominalCtrl.text.replaceAll('.', '').trim();
    final nominal = double.tryParse(raw) ?? 0;

    if (nominal <= 0) {
      setState(() { _isNominalValid = false; _mitraRekomen = null; });
      return;
    }

    // ── Cek sisa kuota transfer bulan ini (limit 50.000 USD/bulan) ──────────
    await Future.wait([_fetchKursUSD(), _hitungTotalBulanIni()]);

    // Konversi limit USD → IDR menggunakan kurs live
    final limitIDR   = _limitUSD * _kursUSDtoIDR;
    final sisaKuota  = limitIDR - _totalBulanIni;
    final sisaUSD    = sisaKuota / _kursUSDtoIDR;

    debugPrint('Limit: \$${_limitUSD.toStringAsFixed(0)} USD = ${_formatRupiah(limitIDR)}');
    debugPrint('Terpakai: ${_formatRupiah(_totalBulanIni)} | Sisa: ${_formatRupiah(sisaKuota)}');

    if (nominal > sisaKuota) {
      final sisaFormatted    = _formatRupiah(sisaKuota > 0 ? sisaKuota : 0);
      final sisaUSDFormatted = sisaUSD > 0 ? ' (\$${sisaUSD.toStringAsFixed(0)} USD)' : '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          sisaKuota <= 0
              ? 'Kuota transfer bulan ini sudah habis. Reset awal bulan depan.'
              : 'Kuota transfer Anda tersisa $sisaFormatted$sisaUSDFormatted bulan ini',
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
      return;
    }

    setState(() {
      _nominalIDR      = nominal;
      _isNominalValid  = true;
      _isLoadingMitra  = true;
      _mitraRekomen    = null;
      _semuaMitra      = [];
    });

    await _fetchDanRekomen(nominal);
  }

  Future<void> _fetchDanRekomen(double nominalIdr) async {
    try {
      final rows = await Supabase.instance.client
          .from('mitra_kurs')
          .select()
          .eq('target_currency', widget.currencyTujuan);

      if (rows.isEmpty) {
        _gunakanFallback(nominalIdr);
        return;
      }

      // Hitung skor semua mitra
      final List<Map<String, dynamic>> scored = rows
          .map((r) => _hitungSkorMitra(r, nominalIdr))
          .where((r) => r['valid'] == true)
          .toList();

      if (scored.isEmpty) {
        _gunakanFallback(nominalIdr);
        return;
      }

      // Sort by skor ascending — terbaik di index 0
      scored.sort((a, b) => (a['skor'] as double).compareTo(b['skor'] as double));

      if (mounted) {
        setState(() {
          _semuaMitra     = scored;
          _mitraRekomen   = scored.first; // rekomendasi otomatis = yang terbaik
          _isLoadingMitra = false;
        });
      }
    } catch (e) {
      if (mounted) _gunakanFallback(nominalIdr);
    }
  }

  void _gunakanFallback(double nominalIdr) {
    final double kurs  = _kursReferensi[widget.currencyTujuan] ?? 1;
    final double valas = nominalIdr / kurs;
    final Map<String, dynamic> fallback = {
      'nama_mitra'    : 'Estimasi (data real-time tidak tersedia)',
      'kurs'          : kurs,
      'fee'           : 0.0,
      'biaya_fx'      : 0.0,
      'total_biaya'   : 0.0,
      'total_bayar'   : nominalIdr,
      'valas_diterima': valas,
      'is_transferku' : false,
      'valid'         : true,
      'skor'          : kurs,
    };
    setState(() {
      _semuaMitra     = [fallback];
      _mitraRekomen   = fallback;
      _isLoadingMitra = false;
    });
  }

  void _lanjutkanKePembayaran() {
    if (_mitraRekomen == null || !_isNominalValid) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => QrPembayaranScreen(
        userId        : widget.userId,
        negaraTujuan  : widget.negaraTujuan,
        currencyTujuan: widget.currencyTujuan,
        namaPenerima  : widget.namaPenerima,
        noRekening    : widget.noRekening,
        bankPenerima  : widget.bankPenerima,
        tujuanTransfer: widget.tujuanTransfer,
        sumberDana    : widget.sumberDana,
        nominalIDR    : _nominalIDR,
        mitra         : _mitraRekomen!,
      ),
    ));
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
          'Kalkulasi Transfer',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info destinasi ─────────────────────────────────────────
            _buildDestinationCard(),
            const SizedBox(height: 24),

            // ── Input nominal ──────────────────────────────────────────
            _buildSectionLabel('Nominal yang Dikirim (IDR)', Icons.payments_rounded),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _nominalCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _ThousandsSeparatorFormatter(),
                  ],
                  decoration: InputDecoration(
                    hintText: 'Contoh: 1.000.000',
                    prefixText: 'Rp ',
                    prefixStyle: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _hitungDanRekomen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Hitung',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      children: [
                        const TextSpan(text: 'Limit: USD 50.000/bulan'),
                        TextSpan(
                          text: '≈ ${_formatRupiah(_limitUSD * _kursUSDtoIDR)}  •  Terpakai: ${_formatRupiah(_totalBulanIni)}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Loading ────────────────────────────────────────────────
            if (_isLoadingMitra)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Mencari mitra terbaik untuk Anda...',
                        style: TextStyle(color: Colors.grey)),
                  ]),
                ),
              )

            // ── Hasil rekomendasi ──────────────────────────────────────
            else if (_isNominalValid && _mitraRekomen != null) ...[
              _buildRekomendasiCard(),
              const SizedBox(height: 16),
              _buildTransparansiSection(),
              const SizedBox(height: 24),
              _buildRingkasanCard(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _lanjutkanKePembayaran,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Lanjut ke Pembayaran',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      SizedBox(width: 8),
                      Icon(Icons.qr_code_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ── Widget: Rekomendasi utama ──────────────────────────────────────────────
  Widget _buildRekomendasiCard() {
    final m = _mitraRekomen!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge + nama mitra
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[400],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: const [
                  Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('Rekomendasi Terbaik',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            m['nama_mitra']?.toString() ?? '-',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Kurs
          Row(children: [
            const Icon(Icons.currency_exchange_rounded,
                color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            Text(
              '1 ${widget.currencyTujuan} = ${_formatRupiah(m['kurs'])}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ]),
          const SizedBox(height: 16),

          // Nominal kirim → valas diterima
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kamu kirim',
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(_formatRupiah(_nominalIDR),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ]),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white54, size: 20),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Penerima dapat',
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatValas(m['valas_diterima'])} ${widget.currencyTujuan}',
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget: Transparansi biaya ─────────────────────────────────────────────
  Widget _buildTransparansiSection() {
    final m = _mitraRekomen!;
    final bool adaFx = (m['biaya_fx'] as double) > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Rincian Biaya', Icons.receipt_long_rounded),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: [
            _buildBiayaRow(
              'Nominal Dikirim',
              _formatRupiah(_nominalIDR),
              icon: Icons.send_rounded,
              iconColor: Colors.blue[600]!,
            ),
            _buildBiayaRow(
              'Biaya Transfer',
              _formatRupiah(m['fee']),
              icon: Icons.account_balance_rounded,
              iconColor: Colors.orange[600]!,
            ),
            if (adaFx)
              _buildBiayaRow(
                'Biaya FX (margin kurs)',
                _formatRupiah(m['biaya_fx']),
                icon: Icons.currency_exchange_rounded,
                iconColor: Colors.purple[500]!,
                tooltip:
                    'Selisih kurs yang dikenakan mitra. Dibebankan sebagai persentase dari nominal.',
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(height: 1),
            ),
            _buildBiayaRow(
              'Total yang Dibayar',
              _formatRupiah(m['total_bayar']),
              icon: Icons.payments_rounded,
              iconColor: Colors.blue[800]!,
              isBold: true,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(Icons.check_circle_rounded,
                        color: Colors.green[600], size: 16),
                    const SizedBox(width: 6),
                    const Text('Penerima Mendapat',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                  Text(
                    '${_formatValas(m['valas_diterima'])} ${widget.currencyTujuan}',
                    style: TextStyle(
                        color: Colors.green[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
          ]),
        ),

        // ── Perbandingan mitra lain (transparan, collapsible) ──────────────
        if (_semuaMitra.length > 1) ...[
          const SizedBox(height: 12),
          _buildPerbandinganMitra(),
        ],
      ],
    );
  }

  // ── Widget: Perbandingan semua mitra (transparan, bisa dilipat) ────────────
  Widget _buildPerbandinganMitra() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Row(children: [
          Icon(Icons.compare_arrows_rounded,
              color: Colors.grey[500], size: 16),
          const SizedBox(width: 6),
          Text(
            'Lihat perbandingan mitra lain',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500),
          ),
        ]),
        children: [
          const SizedBox(height: 8),
          ..._semuaMitra.asMap().entries.map((e) {
            final i    = e.key;
            final mitra = e.value;
            final isRekomen = i == 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isRekomen ? Colors.blue[50] : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isRekomen ? Colors.blue[200]! : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    if (isRekomen)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.star_rounded,
                            color: Colors.amber[600], size: 16),
                      ),
                    Text(
                      mitra['nama_mitra']?.toString() ?? '-',
                      style: TextStyle(
                        fontWeight: isRekomen
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                      '${_formatValas(mitra['valas_diterima'])} ${widget.currencyTujuan}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isRekomen
                            ? Colors.blue[700]
                            : Colors.black87,
                      ),
                    ),
                    Text(
                      'Biaya: ${_formatRupiah(mitra['total_biaya'])}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                  ]),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Text(
            '* Rekomendasi dipilih otomatis berdasarkan nilai valas terbanyak yang diterima penerima.',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Widget: Ringkasan (card biru bawah) ───────────────────────────────────
  Widget _buildRingkasanCard() {
    final m = _mitraRekomen!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ringkasan Transaksi',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        _buildRingkasanRow('Nominal Dikirim', _formatRupiah(_nominalIDR)),
        _buildRingkasanRow('Biaya Transfer', _formatRupiah(m['fee'])),
        if ((m['biaya_fx'] as double) > 0)
          _buildRingkasanRow('FX Margin', _formatRupiah(m['biaya_fx'])),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(color: Colors.white30, height: 1),
        ),
        _buildRingkasanRow('Total Dibayar', _formatRupiah(m['total_bayar']),
            isBold: true),
        const SizedBox(height: 6),
        _buildRingkasanRow(
          'Penerima Mendapat',
          '${_formatValas(m['valas_diterima'])} ${widget.currencyTujuan}',
          isBold: true,
          valueColor: Colors.greenAccent,
        ),
        const SizedBox(height: 4),
        Text(
          'via ${m['nama_mitra']}',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ]),
    );
  }

  // ── UI Helpers ─────────────────────────────────────────────────────────────

  Widget _buildDestinationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.send_rounded, color: Colors.blue[700], size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.namaPenerima,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            Text(
              '${widget.bankPenerima} • ${widget.noRekening}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            Text(
              '${widget.negaraTujuan} (${widget.currencyTujuan})',
              style: TextStyle(
                  color: Colors.blue[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBiayaRow(
    String label,
    String value, {
    required IconData icon,
    required Color iconColor,
    bool isBold = false,
    String? tooltip,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: isBold ? Colors.black87 : Colors.grey[600],
                    fontWeight:
                        isBold ? FontWeight.bold : FontWeight.normal)),
            if (tooltip != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: tooltip,
                child: Icon(Icons.help_outline_rounded,
                    size: 13, color: Colors.grey[400]),
              ),
            ],
          ]),
          Text(value,
              style: TextStyle(
                  fontSize: isBold ? 15 : 13,
                  fontWeight:
                      isBold ? FontWeight.bold : FontWeight.w500,
                  color: Colors.black87)),
        ],
      ),
    );
    return row;
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: Colors.blue[700]),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87)),
    ]);
  }

  Widget _buildRingkasanRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: isBold ? 15 : 13,
                  fontWeight:
                      isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
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
}

// ── Input Formatter ────────────────────────────────────────────────────────

class _ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final digits = newValue.text.replaceAll('.', '');
    if (int.tryParse(digits) == null) return oldValue;
    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}