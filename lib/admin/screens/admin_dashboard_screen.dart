import 'package:flutter/material.dart';
import '../models/admin_user_model.dart';
import '../services/admin_auth_service.dart';
import '../services/admin_transaction_service.dart';
import '../widgets/admin_header.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/status_badge.dart';
import 'admin_detail_transaksi_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminUser? _currentAdmin;
  bool _isCheckingAuth = true;

  // ── State Transaksi ──
  List<Map<String, dynamic>> _transaksiList = [];
  bool _isLoadingTransaksi = true;
  String _errorMessage = '';

  // ── Filter State ──
  String _selectedStatus = 'Semua';
  final TextEditingController _searchCtrl = TextEditingController();

  // ── Statistik State ──
  Map<String, int> _stats = {
    'total': 0,
    'diproses': 0,
    'diverifikasi': 0,
    'diteruskan': 0,
    'selesai': 0,
  };

  @override
  void initState() {
    super.initState();
    _checkAdminAuth();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAuth() async {
    final loggedIn = await AdminAuthService.isLoggedIn();
    if (!loggedIn) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/admin/login');
      }
      return;
    }

    final admin = await AdminAuthService.getCurrentAdmin();
    if (mounted) {
      setState(() {
        _currentAdmin = admin;
        _isCheckingAuth = false;
      });
      _loadDashboardData();
    }
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoadingTransaksi = true;
      _errorMessage = '';
    });

    try {
      final results = await Future.wait([
        AdminTransactionService.getAntreanTransaksi(
          filterStatus: _selectedStatus,
          searchQuery: _searchCtrl.text,
        ),
        AdminTransactionService.getStatistikAntrean(),
      ]);

      if (mounted) {
        setState(() {
          _transaksiList = results[0] as List<Map<String, dynamic>>;
          _stats = results[1] as Map<String, int>;
          _isLoadingTransaksi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal memuat antrean transaksi: $e';
          _isLoadingTransaksi = false;
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
    return '$day/$month/$year $hour:$min';
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: Row(
        children: [
          // ── Sidebar Navigasi ──
          AdminSidebar(
            selectedIndex: 0,
            onItemSelected: (idx) {},
          ),

          // ── Konten Utama ──
          Expanded(
            child: Column(
              children: [
                // Header Bar
                AdminHeader(
                  title: 'Antrean Transaksi Outgoing',
                  subtitle: 'Verifikasi bukti transfer dan pencatatan penerusan dana ke mitra luar negeri',
                  admin: _currentAdmin,
                  onRefresh: _loadDashboardData,
                ),

                // Area Konten
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Kartu Metrik Ringkasan ──
                        _buildMetricCards(),

                        const SizedBox(height: 28),

                        // ── Filter & Search Bar ──
                        _buildFilterAndSearchRow(),

                        const SizedBox(height: 16),

                        // ── Tabel Antrean Transaksi ──
                        _buildTransactionTableCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Komponen Kartu Statistik ──
  Widget _buildMetricCards() {
    return Row(
      children: [
        _buildStatCard(
          title: 'Perlu Verifikasi',
          count: _stats['diproses'] ?? 0,
          color: Colors.amber.shade700,
          bgColor: Colors.amber.shade50,
          icon: Icons.pending_actions_rounded,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: 'Siap Diteruskan',
          count: _stats['diverifikasi'] ?? 0,
          color: Colors.blue.shade700,
          bgColor: Colors.blue.shade50,
          icon: Icons.verified_rounded,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: 'Dalam Proses Mitra',
          count: _stats['diteruskan'] ?? 0,
          color: Colors.purple.shade700,
          bgColor: Colors.purple.shade50,
          icon: Icons.send_rounded,
        ),
        const SizedBox(width: 16),
        _buildStatCard(
          title: 'Selesai',
          count: _stats['selesai'] ?? 0,
          color: Colors.green.shade700,
          bgColor: Colors.green.shade50,
          icon: Icons.check_circle_rounded,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  count.toString(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Filter dan Search Row ──
  Widget _buildFilterAndSearchRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Search Input
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari no. referensi, nama nasabah, atau penerima...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _loadDashboardData();
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => _loadDashboardData(),
            ),
          ),
          const SizedBox(width: 16),

          // Dropdown Status Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'Semua', child: Text('Semua Status')),
                  DropdownMenuItem(value: 'Diproses', child: Text('Diproses (Menunggu Verifikasi)')),
                  DropdownMenuItem(value: 'Diverifikasi', child: Text('Diverifikasi (Siap Kirim)')),
                  DropdownMenuItem(value: 'Diteruskan', child: Text('Diteruskan ke Mitra')),
                  DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
                  DropdownMenuItem(value: 'Gagal', child: Text('Ditolak / Gagal')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedStatus = val);
                    _loadDashboardData();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tabel Transaksi ──
  Widget _buildTransactionTableCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Table Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Daftar Transaksi (${_transaksiList.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Body Table
          if (_isLoadingTransaksi)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            )
          else if (_transaksiList.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: const [
                    Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text(
                      'Tidak ada transaksi yang cocok dengan filter.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                dataRowMinHeight: 64,
                dataRowMaxHeight: 64,
                columns: const [
                  DataColumn(label: Text('Waktu')),
                  DataColumn(label: Text('No. Referensi')),
                  DataColumn(label: Text('Pengirim (Nasabah)')),
                  DataColumn(label: Text('Nominal IDR')),
                  DataColumn(label: Text('Penerima & Valas')),
                  DataColumn(label: Text('Status Bayar')),
                  DataColumn(label: Text('Status Transfer')),
                  DataColumn(label: Text('Aksi')),
                ],
                rows: _transaksiList.map((tx) {
                  final ref = tx['referensi_transaksi']?.toString() ??
                      tx['referensi_trans']?.toString() ??
                      '-';
                  final pengguna = tx['pengguna'] as Map<String, dynamic>?;
                  final pengirimNama = pengguna?['nama_lengkap']?.toString() ?? 'Nasabah';
                  final pengirimEmail = pengguna?['email']?.toString() ?? '-';

                  final nominalIdr = tx['nominal_idr'] as num?;
                  final valas = tx['nominal_asing'] as num?;
                  final cur = tx['mata_uang_tujuan']?.toString() ?? '';
                  final penerima = tx['nama_penerima']?.toString() ?? '-';

                  final sp = tx['status_pembayaran']?.toString() ?? 'menunggu_pembayaran';
                  final st = tx['status_transfer']?.toString() ?? 'diproses';

                  return DataRow(
                    cells: [
                      // Waktu
                      DataCell(
                        Text(
                          _formatTanggal(tx['dibuat_pada']?.toString()),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                      // Referensi
                      DataCell(
                        Text(
                          ref,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                      // Pengirim
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              pengirimNama,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              pengirimEmail,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      // Nominal IDR
                      DataCell(
                        Text(
                          _formatRupiah(nominalIdr),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Penerima & Valas
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              penerima,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${valas != null ? valas.toStringAsFixed(2) : "0"} $cur',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status Bayar
                      DataCell(StatusBadge(status: sp, isPaymentStatus: true)),
                      // Status Transfer
                      DataCell(StatusBadge(status: st, isPaymentStatus: false)),
                      // Tombol Aksi
                      DataCell(
                        ElevatedButton.icon(
                          onPressed: () async {
                            final changed = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AdminDetailTransaksiScreen(
                                  transaksiId: tx['id'].toString(),
                                  adminUser: _currentAdmin,
                                ),
                              ),
                            );
                            if (changed == true) {
                              _loadDashboardData();
                            }
                          },
                          icon: const Icon(Icons.visibility_outlined, size: 14),
                          label: const Text('Periksa'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
