import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bukti_transfer_screen.dart';

class KonfirmasiPinScreen extends StatefulWidget {
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

  const KonfirmasiPinScreen({
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
  });

  @override
  State<KonfirmasiPinScreen> createState() => _KonfirmasiPinScreenState();
}

class _KonfirmasiPinScreenState extends State<KonfirmasiPinScreen>
    with SingleTickerProviderStateMixin {
  // ── PIN state ──────────────────────────────────────────────────────────────
  final List<String> _pinDigits = List.filled(6, '');
  int _currentIndex = 0;
  bool _isLoading = false;
  bool _obscurePin = true;
  int _gagalCount = 0;
  static const int _maxGagal = 3;

  // ── Shake animation ────────────────────────────────────────────────────────
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Hash PIN ───────────────────────────────────────────────────────────────
  String _hashPin(String pin) {
    final bytes  = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ── Input digit ───────────────────────────────────────────────────────────
  void _inputDigit(String digit) {
    if (_currentIndex >= 6 || _isLoading) return;
    setState(() {
      _pinDigits[_currentIndex] = digit;
      _currentIndex++;
    });
    if (_currentIndex == 6) _verifikasiPin();
  }

  void _hapusDigit() {
    if (_currentIndex <= 0 || _isLoading) return;
    setState(() {
      _currentIndex--;
      _pinDigits[_currentIndex] = '';
    });
  }

  void _resetPin() {
    setState(() {
      for (int i = 0; i < 6; i++) _pinDigits[i] = '';
      _currentIndex = 0;
    });
  }

  // ── Verifikasi PIN ke Supabase ─────────────────────────────────────────────
  Future<void> _verifikasiPin() async {
    final pinInput = _pinDigits.join();
    if (pinInput.length != 6) return;

    setState(() => _isLoading = true);

    try {
      final data = await Supabase.instance.client
          .from('pengguna')
          .select('pin_hash')
          .eq('id', widget.userId)
          .maybeSingle();

      if (data == null) throw Exception('User tidak ditemukan');

      final storedHash = data['pin_hash']?.toString() ?? '';
      final inputHash  = _hashPin(pinInput);

      if (storedHash == inputHash) {
        // ✅ PIN benar — update status transaksi
        await Supabase.instance.client.from('transaksi').update({
          'status_pembayaran': 'dibayar',
          'status_transfer'  : 'diproses',
          'diperbarui_pada'  : DateTime.now().toIso8601String(),
        }).eq('id', widget.transaksiId);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BuktiTransferScreen(
                transaksiId   : widget.transaksiId,
                referensiTrans: widget.referensiTrans,
                userId        : widget.userId,
                nominalIDR    : widget.nominalIDR,
                totalBayar    : widget.totalBayar,
                namaPenerima  : widget.namaPenerima,
                negaraTujuan  : widget.negaraTujuan,
                currencyTujuan: widget.currencyTujuan,
                valas         : widget.valas,
                namaMitra     : widget.namaMitra,
                waktuTransaksi: DateTime.now(),
              ),
            ),
          );
        }
      } else {
        // ❌ PIN salah
        _gagalCount++;
        await _shakeCtrl.forward(from: 0);
        _resetPin();

        if (mounted) {
          final sisaCoba = _maxGagal - _gagalCount;
          if (sisaCoba <= 0) {
            // Tandai transaksi gagal
            await Supabase.instance.client.from('transaksi').update({
              'status_pembayaran': 'gagal',
              'status_transfer'  : 'gagal',
            }).eq('id', widget.transaksiId);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN salah 3 kali. Transaksi dibatalkan.'),
                backgroundColor: Colors.red,
              ),
            );
            // Kembali ke halaman utama
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PIN salah. Sisa percobaan: $sisaCoba'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
        );
        _resetPin();
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
          'Konfirmasi PIN',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // ── Info transaksi ringkas ───────────────────────────────────
              _buildInfoCard(),
              const SizedBox(height: 32),

              // ── Header PIN ─────────────────────────────────────────────
              const Icon(Icons.lock_person_rounded, size: 52, color: Colors.blue),
              const SizedBox(height: 12),
              const Text(
                'Masukkan PIN Anda',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Masukkan PIN 6 digit untuk mengkonfirmasi transaksi',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 28),

              // ── Indikator PIN dot ──────────────────────────────────────
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                ),
                child: _buildPinDots(),
              ),
              const SizedBox(height: 8),

              // ── Tombol show/hide ───────────────────────────────────────
              TextButton.icon(
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
                icon: Icon(
                  _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 16,
                  color: Colors.grey[400],
                ),
                label: Text(
                  _obscurePin ? 'Tampilkan PIN' : 'Sembunyikan PIN',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),

              if (_gagalCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Percobaan gagal: $_gagalCount / $_maxGagal',
                    style: TextStyle(color: Colors.red[600], fontSize: 12),
                  ),
                ),

              const SizedBox(height: 16),

              // ── Keypad ─────────────────────────────────────────────────
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Memverifikasi PIN...', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              else
                _buildKeypad(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── PIN Dots ───────────────────────────────────────────────────────────────

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final isFilled = i < _currentIndex;
        final digit = _pinDigits[i];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: isFilled ? Colors.blue[50] : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFilled
                  ? (i == _currentIndex - 1 ? Colors.blue[700]! : Colors.blue[300]!)
                  : Colors.grey.shade300,
              width: isFilled && i == _currentIndex - 1 ? 2 : 1,
            ),
          ),
          child: Center(
            child: isFilled
                ? Text(
                    _obscurePin ? '●' : digit,
                    style: TextStyle(
                      fontSize: _obscurePin ? 20 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }

  // ── Keypad ─────────────────────────────────────────────────────────────────

  Widget _buildKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 80, height: 72);
            return _buildKey(key);
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildKey(String key) {
    final isDel = key == 'del';
    return GestureDetector(
      onTap: isDel ? _hapusDigit : () => _inputDigit(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: const EdgeInsets.all(6),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isDel ? Colors.red[50] : Colors.grey[100],
          shape: BoxShape.circle,
          border: Border.all(
            color: isDel ? Colors.red[200]! : Colors.grey.shade200,
          ),
        ),
        child: Center(
          child: isDel
              ? Icon(Icons.backspace_outlined, size: 22, color: Colors.red[400])
              : Text(
                  key,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Info Card ──────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.send_rounded, color: Colors.blue[700], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.namaPenerima,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  '${widget.negaraTujuan} • ${widget.namaMitra}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatRupiah(widget.totalBayar),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                '${_formatValas(widget.valas)} ${widget.currencyTujuan}',
                style: TextStyle(color: Colors.green[600], fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
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