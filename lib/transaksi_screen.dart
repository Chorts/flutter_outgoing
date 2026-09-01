// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profil_risiko_screen.dart';

class TransaksiScreen extends StatefulWidget {
  const TransaksiScreen({super.key});

  @override
  State<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends State<TransaksiScreen> {
  final _formKey = GlobalKey<FormState>();

  // ── Controllers ──────────────────────────────────────────────────────────
  final _namaPenerimaCtrl = TextEditingController();
  final _noRekeningCtrl = TextEditingController();
  final _bankPenerimaCtrl = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  String? _selectedNegara;
  String? _selectedCurrency;
  bool _isLoading = false;
  double _limitTransaksi = 0;
  String _userId = '';

  // ── Daftar negara tujuan ──────────────────────────────────────────────────
  // Nama negara (key "name") HARUS match dengan kolom `negara` di tabel mitra_kurs
  // agar bisa dipakai sebagai filter tambahan bila diperlukan.
  // Query utama tetap pakai target_currency, tapi konsistensi penting.
  final List<Map<String, String>> _negaraList = [
    // ── Populer / Asia Tenggara ──────────────────────────────────────────
    {"name": "Malaysia",              "currency": "MYR", "flag": "🇲🇾"},
    {"name": "Singapore",             "currency": "SGD", "flag": "🇸🇬"},
    {"name": "Thailand",              "currency": "THB", "flag": "🇹🇭"},
    {"name": "Philippines",           "currency": "PHP", "flag": "🇵🇭"},
    {"name": "Vietnam",               "currency": "VND", "flag": "🇻🇳"},
    {"name": "Cambodia",              "currency": "KHR", "flag": "🇰🇭"},
    {"name": "Myanmar",               "currency": "MMK", "flag": "🇲🇲"},
    // ── Asia Timur ───────────────────────────────────────────────────────
    {"name": "Japan",                 "currency": "JPY", "flag": "🇯🇵"},
    {"name": "South Korea",           "currency": "KRW", "flag": "🇰🇷"},
    {"name": "China",                 "currency": "CNY", "flag": "🇨🇳"},
    {"name": "Hong Kong",             "currency": "HKD", "flag": "🇭🇰"},
    // ── Asia Selatan ─────────────────────────────────────────────────────
    {"name": "India",                 "currency": "INR", "flag": "🇮🇳"},
    {"name": "Bangladesh",            "currency": "BDT", "flag": "🇧🇩"},
    {"name": "Nepal",                 "currency": "NPR", "flag": "🇳🇵"},
    {"name": "Pakistan",              "currency": "PKR", "flag": "🇵🇰"},
    {"name": "Sri Lanka",             "currency": "LKR", "flag": "🇱🇰"},
    // ── Timur Tengah ─────────────────────────────────────────────────────
    {"name": "Saudi Arabia",          "currency": "SAR", "flag": "🇸🇦"},
    {"name": "United Arab Emirates",  "currency": "AED", "flag": "🇦🇪"},
    {"name": "Egypt",                 "currency": "EGP", "flag": "🇪🇬"},
    // ── Barat / Oseania ──────────────────────────────────────────────────
    {"name": "United States",         "currency": "USD", "flag": "🇺🇸"},
    {"name": "United Kingdom",        "currency": "GBP", "flag": "🇬🇧"},
    {"name": "Europe",                "currency": "EUR", "flag": "🇪🇺"},
    {"name": "Australia",             "currency": "AUD", "flag": "🇦🇺"},
    {"name": "Canada",                "currency": "CAD", "flag": "🇨🇦"},
    {"name": "Brazil",                "currency": "BRL", "flag": "🇧🇷"},
    {"name": "Turkey",                "currency": "TRY", "flag": "🇹🇷"},
    // ── Afrika ───────────────────────────────────────────────────────────
    {"name": "Nigeria",               "currency": "NGN", "flag": "🇳🇬"},
    {"name": "Ghana",                 "currency": "GHS", "flag": "🇬🇭"},
    // ── Lainnya ──────────────────────────────────────────────────────────
    {"name": "Mongolia",              "currency": "MNT", "flag": "🇲🇳"},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _namaPenerimaCtrl.dispose();
    _noRekeningCtrl.dispose();
    _bankPenerimaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    if (userId.isEmpty) return;

    setState(() => _userId = userId);

    try {
      final data = await Supabase.instance.client
          .from('pengguna')
          .select('limit_transaksi')
          .eq('id', userId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _limitTransaksi = (data['limit_transaksi'] as num?)?.toDouble() ?? 10000000;
        });
      }
    } catch (_) {
      setState(() => _limitTransaksi = 10000000); 
    }
  }

  void _lanjutkanKeProfilRisiko() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedNegara == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih negara tujuan terlebih dahulu')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilRisikoScreen(
          userId: _userId,
          negaraTujuan: _selectedNegara!,
          currencyTujuan: _selectedCurrency!,
          namaPenerima: _namaPenerimaCtrl.text.trim(),
          noRekening: _noRekeningCtrl.text.trim(),
          bankPenerima: _bankPenerimaCtrl.text.trim(),
          limitTransaksi: _limitTransaksi,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: const Text(
          'Transfer ke Luar Negeri',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Info limit ─────────────────────────────────────────
                    if (_limitTransaksi > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.blue[700], size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Limit transfer Anda: Rp 10.000.000 / transaksi',
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── Pilih negara tujuan ────────────────────────────────
                    _buildSectionLabel('Negara Tujuan', Icons.public_rounded),
                    const SizedBox(height: 10),
                    _buildNegaraPicker(),

                    const SizedBox(height: 24),

                    // ── Data penerima ──────────────────────────────────────
                    _buildSectionLabel('Data Penerima', Icons.person_outline_rounded),
                    const SizedBox(height: 10),

                    _buildTextField(
                      controller: _namaPenerimaCtrl,
                      label: 'Nama Lengkap Penerima',
                      hint: 'Sesuai rekening bank penerima',
                      icon: Icons.person_rounded,
                      validator: (val) => val == null || val.isEmpty
                          ? 'Nama penerima tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _noRekeningCtrl,
                      label: 'Nomor Rekening Penerima',
                      hint: 'Masukkan nomor rekening',
                      icon: Icons.account_balance_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (val) => val == null || val.isEmpty
                          ? 'Nomor rekening tidak boleh kosong'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      controller: _bankPenerimaCtrl,
                      label: 'Nama Bank Penerima',
                      hint: 'Contoh: Maybank, CIMB, DBS...',
                      icon: Icons.account_balance_wallet_rounded,
                      validator: (val) => val == null || val.isEmpty
                          ? 'Nama bank tidak boleh kosong'
                          : null,
                    ),

                    const SizedBox(height: 36),

                    // ── Tombol lanjut ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _lanjutkanKeProfilRisiko,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Lanjutkan',
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

  // ── UI Helpers ─────────────────────────────────────────────────────────────

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

  Widget _buildNegaraPicker() {
    return DropdownButtonFormField<String>(
      value: _selectedNegara,
      hint: const Text('Pilih negara tujuan'),
      decoration: InputDecoration(
        prefixIcon: _selectedNegara == null
            ? const Icon(Icons.flag_outlined)
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _negaraList.firstWhere(
                    (n) => n['name'] == _selectedNegara,
                    orElse: () => {"flag": "🌍"},
                  )['flag']!,
                  style: const TextStyle(fontSize: 20),
                ),
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
      items: _negaraList.map((negara) {
        return DropdownMenuItem<String>(
          value: negara['name'],
          child: Row(
            children: [
              Text(negara['flag']!, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Text(negara['name']!),
              const SizedBox(width: 8),
              Text(
                '(${negara['currency']})',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedNegara = val;
          _selectedCurrency = _negaraList
              .firstWhere((n) => n['name'] == val)['currency'];
        });
      },
      validator: (val) => val == null ? 'Pilih negara tujuan' : null,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
      ),
      validator: validator,
    );
  }

  String _formatRupiah(double value) {
    final parts = value.toStringAsFixed(0).split('');
    String formatted = '';
    for (int i = 0; i < parts.length; i++) {
      if (i > 0 && (parts.length - i) % 3 == 0) formatted += '.';
      formatted += parts[i];
    }
    return 'Rp $formatted';
  }
}