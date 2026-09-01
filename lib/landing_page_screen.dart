// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'register_account_screen.dart';
import 'login_screen.dart';
import 'riwayat_page.dart';
import 'profile_page.dart';
import 'transaksi_screen.dart';

class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({super.key});

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  int _currentIndex = 0;
  bool _isKursExpanded = false;
  bool isLoggedIn = false;
  bool _isLoading = true;
  String _userName = "";

  // ── KURS STATE ──────────────────────────────────────────────────────────
  bool _isLoadingKurs = false;
  String _kursLastUpdate = "";

  // ── AUTH LISTENER ────────────────────────────────────────────────────────
  late final StreamSubscription<AuthState> _authSubscription;

  // ── KALKULATOR STATE ─────────────────────────────────────────────────────
  // true  = IDR → valas (user input IDR, lihat hasil valas)
  // false = valas → IDR (user input valas, lihat hasil IDR)
  bool _idrToForeign = true;
  String _selectedCurrency = "SGD"; // default Singapore
  final TextEditingController _kalkulatorCtrl = TextEditingController();
  String _kalkulatorResult = "";
  String _kalkulatorRateInfo = "";

  // ─────────────────────────────────────────────────────────────────────────
  //  DATA KURS REFERENSI
  // ─────────────────────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _kursReferensi = [
    {"code": "MYR/IDR", "currency": "MYR", "name": "Malaysia", "ref": 3425.0},
    {"code": "SGD/IDR", "currency": "SGD", "name": "Singapura", "ref": 12012.0},
    {"code": "THB/IDR", "currency": "THB", "name": "Thailand", "ref": 442.0},
    {"code": "PHP/IDR", "currency": "PHP", "name": "Filipina", "ref": 282.0},
    {"code": "CNY/IDR", "currency": "CNY", "name": "China", "ref": 2245.0},
    {"code": "JPY/IDR", "currency": "JPY", "name": "Jepang", "ref": 104.5},
    {"code": "AUD/IDR", "currency": "AUD", "name": "Australia", "ref": 10750.0},
    {"code": "CAD/IDR", "currency": "CAD", "name": "Kanada", "ref": 11855.0},
    {"code": "VND/IDR", "currency": "VND", "name": "Vietnam", "ref": 0.64},
    {"code": "HKD/IDR", "currency": "HKD", "name": "Hong Kong", "ref": 2078.0},
    {
      "code": "USD/IDR",
      "currency": "USD",
      "name": "Amerika Serikat",
      "ref": 16240.0,
    },
    {"code": "INR/IDR", "currency": "INR", "name": "India", "ref": 194.5},
    {
      "code": "KRW/IDR",
      "currency": "KRW",
      "name": "Korea Selatan",
      "ref": 11.8,
    },
    {"code": "EUR/IDR", "currency": "EUR", "name": "Eropa", "ref": 17455.0},
    {"code": "SAR/IDR", "currency": "SAR", "name": "Arab Saudi", "ref": 4330.0},
    {
      "code": "AED/IDR",
      "currency": "AED",
      "name": "Uni Emirat Arab",
      "ref": 4421.0,
    },
  ];

  List<Map<String, dynamic>> _kursData = [];

  // ─────────────────────────────────────────────────────────────────────────
  //  INIT & DISPOSE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Isi kurs dari referensi dulu agar grid tidak kosong saat pertama buka
    _kursData = _kursReferensi
        .map(
          (item) => {
            "code": item["code"],
            "name": item["name"],
            "currency": item["currency"],
            "val": _formatKurs(item["ref"] as double),
            "up": true,
            "raw": item["ref"] as double,
            "live": false,
          },
        )
        .toList();

    _checkCurrentSession();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final Session? session = data.session;
      if (!mounted) return;
      // Hanya update state jika ada Supabase Auth session (login via OTP/OAuth).
      // Login manual via PIN tidak membuat session Supabase Auth,
      // jadi jangan reset isLoggedIn saat session == null.
      if (session != null) {
        _loadUserName(session.user.id);
        setState(() {
          isLoggedIn = true;
          _isLoading = false;
        });
      }
    });

    _fetchLiveKurs();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _kalkulatorCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  AUTH HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _checkCurrentSession() async {
    try {
      // Cek Supabase Auth session dulu (untuk login via OTP/OAuth)
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        await _loadUserName(session.user.id);
        if (mounted)
          setState(() {
            isLoggedIn = true;
            _isLoading = false;
          });
        return;
      }

      // ✅ Fallback: cek SharedPreferences (untuk login manual via tabel pengguna + PIN)
      final prefs = await SharedPreferences.getInstance();
      final loggedIn = prefs.getBool('isLoggedIn') ?? false;
      final userName = prefs.getString('userName') ?? '';

      if (mounted) {
        setState(() {
          isLoggedIn = loggedIn;
          _userName = userName;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUserName(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('pengguna')
          .select('nama_lengkap')
          .eq('id', userId)
          .maybeSingle();
      if (!mounted) return;
      if (response != null) {
        setState(() => _userName = response['nama_lengkap'] ?? "");
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  LIVE KURS
  // ─────────────────────────────────────────────────────────────────────────

  // ⚙️  Ganti YOUR_API_KEY dengan API key dari https://app.exchangerate-api.com/sign-up
  static const String _exchangeRateApiKey = '10aa2066bb6854bd2d8f0199';

  Future<void> _fetchLiveKurs() async {
    if (!mounted) return;
    setState(() => _isLoadingKurs = true);
    try {
      // Menggunakan exchangerate-api.com — base IDR, ambil semua kurs sekaligus
      final uri = Uri.parse(
        'https://v6.exchangerate-api.com/v6/$_exchangeRateApiKey/latest/IDR',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200)
        throw Exception('HTTP ${response.statusCode}');

      final Map<String, dynamic> body = jsonDecode(response.body);
      if (body['result'] != 'success') {
        throw Exception('API error: ${body['error-type'] ?? 'unknown'}');
      }

      final Map<String, dynamic> rates = body['conversion_rates'];

      final List<Map<String, dynamic>> updated = _kursReferensi.map((item) {
        final String curr = item['currency'] as String;
        final double ref = item['ref'] as double;

        // rates[curr] = berapa unit valas per 1 IDR
        // Kita balik: berapa IDR per 1 unit valas
        if (rates.containsKey(curr) && (rates[curr] as num) != 0) {
          final double live = 1.0 / (rates[curr] as num).toDouble();
          return {
            "code": item["code"],
            "name": item["name"],
            "currency": curr,
            "val": _formatKurs(live),
            "up": live >= ref,
            "raw": live,
            "live": true,
          };
        }
        // Fallback ke nilai referensi jika currency tidak ada di response
        return {
          "code": item["code"],
          "name": item["name"],
          "currency": curr,
          "val": _formatKurs(ref),
          "up": true,
          "raw": ref,
          "live": false,
        };
      }).toList();

      // Format: "Wed, 10 Jun 2026 00:00:00 +0000" → ambil 16 karakter pertama
      final String updateTime =
          body['time_last_update_utc']?.toString().substring(0, 16) ?? "";

      if (!mounted) return;
      setState(() {
        _kursData = updated;
        _kursLastUpdate = updateTime;
        _isLoadingKurs = false;
      });

      // Hitung ulang kalkulator jika user sudah input angka
      if (_kalkulatorCtrl.text.isNotEmpty) _hitungKonversi();
    } catch (e) {
      debugPrint('_fetchLiveKurs error: $e');
      if (!mounted) return;
      setState(() => _isLoadingKurs = false);
      // Kurs tetap tampil dari nilai referensi (fallback sudah diisi di initState)
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  REKOMENDASI MITRA (dari Supabase)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _getRekomendasi(
    String negara,
    double nominalIdr,
  ) async {
    try {
      final rows = await Supabase.instance.client
          .from('mitra_kurs')
          .select()
          .eq('negara', negara);
      if (rows.isEmpty) return null;

      Map<String, dynamic>? best;
      double bestTotal = double.infinity;
      for (final row in rows) {
        final double kurs = (row['kurs_jual'] as num?)?.toDouble() ?? 0;
        final double fee = (row['biaya_fee'] as num?)?.toDouble() ?? 0;
        final double margin = (row['fx_margin'] as num?)?.toDouble() ?? 0;
        if (kurs == 0) continue;
        final double biayaFx =
            row['nama_mitra'].toString().toLowerCase().contains('transferku')
            ? nominalIdr * margin
            : 0;
        final double total = nominalIdr + fee + biayaFx;
        if (total < bestTotal) {
          bestTotal = total;
          best = {
            ...row,
            'total_biaya': total,
            'biaya_fx': biayaFx,
            'valas_diterima': nominalIdr / kurs,
          };
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  KALKULATOR LOGIKA
  // ─────────────────────────────────────────────────────────────────────────

  /// Ambil kurs (IDR per 1 unit valas) untuk currency yang dipilih
  double _getRateFor(String currency) {
    for (final item in _kursData) {
      if (item['currency'] == currency) {
        return (item['raw'] as double?) ?? 0.0;
      }
    }
    return 0.0;
  }

  void _hitungKonversi() {
    final String input = _kalkulatorCtrl.text.replaceAll('.', '').trim();
    final double? nominal = double.tryParse(input);

    if (nominal == null || nominal <= 0) {
      setState(() {
        _kalkulatorResult = "";
        _kalkulatorRateInfo = "";
      });
      return;
    }

    final double rate = _getRateFor(_selectedCurrency);
    if (rate <= 0) {
      setState(() {
        _kalkulatorResult = "Kurs tidak tersedia";
        _kalkulatorRateInfo = "";
      });
      return;
    }

    double hasil;
    String resultLabel;
    String fromLabel;
    String toLabel;

    if (_idrToForeign) {
      // IDR → valas: bagi dengan kurs
      hasil = nominal / rate;
      fromLabel = "IDR";
      toLabel = _selectedCurrency;
      resultLabel = _formatHasil(hasil, _selectedCurrency);
    } else {
      // valas → IDR: kali dengan kurs
      hasil = nominal * rate;
      fromLabel = _selectedCurrency;
      toLabel = "IDR";
      resultLabel = _formatRupiah(hasil);
    }

    setState(() {
      _kalkulatorResult = resultLabel;
      _kalkulatorRateInfo = "1 $_selectedCurrency = ${_formatRupiah(rate)}";
    });
  }

  /// Format angka menjadi Rupiah (Rp 16.240,00)
  String _formatRupiah(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final ribuan = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp $ribuan,${parts[1]}';
  }

  /// Format hasil valas dengan presisi yang sesuai
  String _formatHasil(double value, String currency) {
    // Mata uang dengan nilai sangat kecil per IDR (VND, KRW, IDR)
    final kecil = ['VND', 'KRW', 'IDR'];
    if (kecil.contains(currency)) {
      return '${_formatAngka(value, 2)} $currency';
    }
    // Standar: 4 desimal untuk presisi
    return '${value.toStringAsFixed(4)} $currency';
  }

  String _formatAngka(double value, int desimal) {
    final parts = value.toStringAsFixed(desimal).split('.');
    final ribuan = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return desimal > 0 ? '$ribuan,${parts[1]}' : ribuan;
  }

  /// Format angka kurs untuk grid
  String _formatKurs(double value) {
    if (value >= 1000) {
      return value
          .toStringAsFixed(0)
          .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]}.',
          );
    } else if (value >= 1) {
      return value.toStringAsFixed(value >= 100 ? 1 : 2);
    } else {
      return value.toStringAsFixed(4);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        
        backgroundColor: Colors.white,
        elevation: 0,
        actions: _isLoading
            ? []
            : isLoggedIn
            ? [
                
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text(
                    "Login",
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16, left: 8),
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterAccountScreen(),
                      ),
                    ),
                    child: const Text("Daftar"),
                  ),
                ),
              ],
      ),
      body: _currentIndex == 0 ? _buildHomeBody() : _buildBody(),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) async {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[800],

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz_rounded),
            label: 'Transaksi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ─── Body router ─────────────────────────────────────────────────────────

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeBody();
      case 1:
        return _buildProtectedPage(const TransaksiScreen(), "transaksi");
      case 2:
        return _buildProtectedPage(const RiwayatPage(), "riwayat transaksi");
      case 3:
        return _buildProtectedPage(const ProfilePage(), "Halaman Profil");
      default:
        return _buildHomeBody();
    }
  }

  // ─── Protected page ───────────────────────────────────────────────────────

  Widget _buildProtectedPage(Widget pageContent, String featureName) {
    if (isLoggedIn) return pageContent;
    return Stack(
      children: [
        AbsorbPointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.1),
                BlendMode.darken,
              ),
              child: pageContent,
            ),
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 64,
                  color: Colors.blue[700],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Akses Terkunci",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Silakan masuk ke akun Anda atau daftar baru untuk melihat detail $featureName.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Masuk (Login)",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterAccountScreen(),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blue[700]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      "Daftar Akun Baru",
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 0),
                  child: const Text(
                    "Nanti Saja, Kembali ke Beranda",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Home body ────────────────────────────────────────────────────────────

  Widget _buildHomeBody() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          // Greeting
          if (isLoggedIn && _userName.isNotEmpty) ...[
            Text(
              "Hi, $_userName 👋",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Header kurs ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Kurs Saat Ini",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  if (_isLoadingKurs)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_kursData.isNotEmpty &&
                      _kursData.first['live'] == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "LIVE",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoadingKurs ? null : _fetchLiveKurs,
                    child: Icon(
                      Icons.refresh_rounded,
                      color: _isLoadingKurs ? Colors.grey : Colors.blue,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (_kursLastUpdate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                "Update: $_kursLastUpdate UTC",
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),

          const SizedBox(height: 12),
          _buildExpandableKurs(),
          const SizedBox(height: 24),

          // ── KALKULATOR KONVERSI (menggantikan artikel) ───────────────────
          _buildKalkulator(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Expandable kurs grid ─────────────────────────────────────────────────

  Widget _buildExpandableKurs() {
    final int itemsToShow = _isKursExpanded ? _kursData.length : 4;

    return Container(
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: itemsToShow,
            itemBuilder: (context, index) {
              final data = _kursData[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.blue[100],
                      child: Text(
                        (data['code'] as String)[0],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['code'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            data['val'],
                            style: TextStyle(
                              color: (data['up'] as bool)
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          InkWell(
            onTap: () => setState(() => _isKursExpanded = !_isKursExpanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue[100]!.withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isKursExpanded
                        ? "Tampilkan Sedikit"
                        : "Lihat Semua 16 Mata Uang",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
                    _isKursExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  KALKULATOR KONVERSI
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildKalkulator() {
    // Ambil nama negara dari currency yang dipilih
    final selectedItem = _kursReferensi.firstWhere(
      (e) => e['currency'] == _selectedCurrency,
      orElse: () => _kursReferensi[0],
    );
    final String selectedName = selectedItem['name'] as String;
    final String fromCurrency = _idrToForeign ? "IDR" : _selectedCurrency;
    final String toCurrency = _idrToForeign ? _selectedCurrency : "IDR";
    final String inputHint = _idrToForeign
        ? "Masukkan nominal IDR"
        : "Masukkan nominal $_selectedCurrency";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[500]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calculate_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Kalkulator Konversi",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                // Badge kurs live/fallback
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _kursData.isNotEmpty && _kursData.first['live'] == true
                        ? "Kurs Live"
                        : "Kurs Referensi",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Toggle arah konversi ─────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _buildToggleBtn(
                        label: "IDR → Valas",
                        icon: Icons.arrow_forward_rounded,
                        isActive: _idrToForeign,
                        onTap: () {
                          setState(() {
                            _idrToForeign = true;
                            _kalkulatorCtrl.clear();
                            _kalkulatorResult = "";
                            _kalkulatorRateInfo = "";
                          });
                        },
                      ),
                      _buildToggleBtn(
                        label: "Valas → IDR",
                        icon: Icons.arrow_back_rounded,
                        isActive: !_idrToForeign,
                        onTap: () {
                          setState(() {
                            _idrToForeign = false;
                            _kalkulatorCtrl.clear();
                            _kalkulatorResult = "";
                            _kalkulatorRateInfo = "";
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Pilih mata uang tujuan ───────────────────────────────
                const Text(
                  "Mata Uang Tujuan",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue[200]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedCurrency,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.blue,
                      ),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _selectedCurrency = val;
                          _kalkulatorResult = "";
                          _kalkulatorRateInfo = "";
                        });
                        if (_kalkulatorCtrl.text.isNotEmpty) {
                          _hitungKonversi();
                        }
                      },
                      items: _kursReferensi.map((item) {
                        final String curr = item['currency'] as String;
                        final String name = item['name'] as String;
                        // Cari rate live
                        final kursItem = _kursData.firstWhere(
                          (k) => k['currency'] == curr,
                          orElse: () => {"val": "-"},
                        );
                        return DropdownMenuItem<String>(
                          value: curr,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 13,
                                backgroundColor: Colors.blue[50],
                                child: Text(
                                  curr[0],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "$curr — $name",
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                kursItem['val'].toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Input nominal ────────────────────────────────────────
                const Text(
                  "Nominal",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _kalkulatorCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    // Format ribuan otomatis saat mengetik
                    _ThousandsSeparatorInputFormatter(),
                  ],
                  onChanged: (_) => _hitungKonversi(),
                  decoration: InputDecoration(
                    hintText: inputHint,
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Text(
                        fromCurrency,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 0,
                      minHeight: 0,
                    ),
                    suffixIcon: _kalkulatorCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              _kalkulatorCtrl.clear();
                              setState(() {
                                _kalkulatorResult = "";
                                _kalkulatorRateInfo = "";
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.blue[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.blue[600]!,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),

                // ── Hasil konversi ───────────────────────────────────────
                if (_kalkulatorResult.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue[50]!,
                          Colors.blue[100]!.withOpacity(0.4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label arah konversi
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 16,
                              color: Colors.blue[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "$fromCurrency → $toCurrency",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Nominal asal
                        Text(
                          _idrToForeign
                              ? "${_kalkulatorCtrl.text} IDR"
                              : "${_kalkulatorCtrl.text} $_selectedCurrency",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Hasil konversi (besar)
                        Text(
                          "= $_kalkulatorResult",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        if (_kalkulatorRateInfo.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _kalkulatorRateInfo,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // ── Info kurs referensi terpilih ─────────────────────────
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final rate = _getRateFor(_selectedCurrency);
                    if (rate <= 0) return const SizedBox.shrink();
                    return Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 13,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Kurs tengah: 1 $_selectedCurrency ($selectedName) = ${_formatRupiah(rate)}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Toggle button helper ─────────────────────────────────────────────────

  Widget _buildToggleBtn({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.blue[700] : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INPUT FORMATTER — Otomatis tambahkan pemisah ribuan saat mengetik
//  Contoh: "16000000" → "16.000.000"
// ─────────────────────────────────────────────────────────────────────────────

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Hapus titik yang sudah ada, lalu format ulang
    final String digits = newValue.text.replaceAll('.', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    // Jangan format jika bukan angka
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
