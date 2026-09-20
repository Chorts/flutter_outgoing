import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTransactionService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Mengambil daftar antrean transaksi beserta relasi data pengirim (pengguna)
  static Future<List<Map<String, dynamic>>> getAntreanTransaksi({
    String filterStatus = 'Semua',
    String searchQuery = '',
  }) async {
    try {
      // Query transaksi join pengguna
      final response = await _supabase
          .from('transaksi')
          .select('*, pengguna:id_pengguna(*)')
          .order('dibuat_pada', ascending: false);

      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(response);

      // Filter berdasarkan status
      if (filterStatus != 'Semua') {
        final filterLower = filterStatus.toLowerCase();
        items = items.where((t) {
          final st = (t['status_transfer']?.toString() ?? '').toLowerCase();
          final sp = (t['status_pembayaran']?.toString() ?? '').toLowerCase();

          if (filterLower == 'diproses') {
            return st == 'diproses' || (st == 'pending' && sp == 'dibayar');
          } else if (filterLower == 'diverifikasi') {
            return st == 'diverifikasi';
          } else if (filterLower == 'diteruskan') {
            return st == 'diteruskan';
          } else if (filterLower == 'selesai') {
            return st == 'selesai';
          } else if (filterLower == 'gagal') {
            return st == 'gagal' || sp == 'gagal' || sp == 'expired';
          }
          return st == filterLower || sp == filterLower;
        }).toList();
      }

      // Filter pencarian teks
      if (searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        items = items.where((t) {
          final ref = (t['referensi_transaksi']?.toString() ?? t['referensi_trans']?.toString() ?? '').toLowerCase();
          final penerima = (t['nama_penerima']?.toString() ?? '').toLowerCase();
          final penggunaMap = t['pengguna'] as Map<String, dynamic>?;
          final pengirim = (penggunaMap?['nama_lengkap']?.toString() ?? '').toLowerCase();
          final email = (penggunaMap?['email']?.toString() ?? '').toLowerCase();

          return ref.contains(q) ||
              penerima.contains(q) ||
              pengirim.contains(q) ||
              email.contains(q);
        }).toList();
      }

      return items;
    } catch (e) {
      debugPrint('Error getAntreanTransaksi: $e');
      rethrow;
    }
  }

  /// Mengambil detail satu transaksi secara komprehensif
  static Future<Map<String, dynamic>?> getDetailTransaksi(String transaksiId) async {
    try {
      final response = await _supabase
          .from('transaksi')
          .select('*, pengguna:id_pengguna(*)')
          .eq('id', transaksiId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error getDetailTransaksi: $e');
      rethrow;
    }
  }

  /// Aksi Verifikasi Bukti Pembayaran: Setujui atau Tolak
  static Future<void> verifikasiPembayaran({
    required String transaksiId,
    required bool disetujui,
    required String adminId,
    String? catatan,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      if (disetujui) {
        // Status transfer diubah menjadi 'diverifikasi' (sudah dipetakan di riwayat nasabah)
        await _supabase.from('transaksi').update({
          'status_transfer': 'diverifikasi',
          'diverifikasi_oleh': adminId,
          'diverifikasi_pada': now,
          'catatan_admin': catatan,
          'diperbarui_pada': now,
        }).eq('id', transaksiId);

        // Catat ke jejak_audit_admin
        await _catatAuditLog(
          adminId: adminId,
          aksi: 'VERIFIKASI_PEMBAYARAN_DISETUJUI',
          deskripsi: 'Bukti pembayaran nasabah diverifikasi dan disetujui oleh admin operasional.',
          transaksiId: transaksiId,
        );
      } else {
        // Status diubah menjadi 'gagal'
        await _supabase.from('transaksi').update({
          'status_transfer': 'gagal',
          'status_pembayaran': 'gagal',
          'diverifikasi_oleh': adminId,
          'diverifikasi_pada': now,
          'catatan_admin': catatan ?? 'Pembayaran ditolak oleh admin.',
          'diperbarui_pada': now,
        }).eq('id', transaksiId);

        // Catat ke jejak_audit_admin
        await _catatAuditLog(
          adminId: adminId,
          aksi: 'VERIFIKASI_PEMBAYARAN_DITOLAK',
          deskripsi: 'Bukti pembayaran ditolak oleh admin. Alasan: ${catatan ?? '-'}',
          transaksiId: transaksiId,
        );
      }
    } catch (e) {
      debugPrint('Error verifikasiPembayaran: $e');
      rethrow;
    }
  }

  /// Pencatatan Penerusan Dana ke Mitra Luar Negeri (Wallex / Instarem)
  static Future<void> catatPenerusanMitra({
    required String transaksiId,
    required String mitraRemitansi,
    required String referensiMitra,
    required String adminId,
    String? catatan,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Status transfer diubah menjadi 'diteruskan' (sudah dipetakan di riwayat nasabah)
      await _supabase.from('transaksi').update({
        'status_transfer': 'diteruskan',
        'mitra_remitansi': mitraRemitansi,
        'referensi_mitra': referensiMitra,
        'diteruskan_pada': now,
        if (catatan != null && catatan.isNotEmpty) 'catatan_admin': catatan,
        'diperbarui_pada': now,
      }).eq('id', transaksiId);

      // Catat ke jejak_audit_admin
      await _catatAuditLog(
        adminId: adminId,
        aksi: 'PENERUSAN_DANA_MITRA',
        deskripsi: 'Dana berhasil diteruskan ke mitra $mitraRemitansi dengan no referensi $referensiMitra.',
        transaksiId: transaksiId,
      );
    } catch (e) {
      debugPrint('Error catatPenerusanMitra: $e');
      rethrow;
    }
  }

  /// Tandai Transaksi Selesai (Dana telah diterima oleh penerima luar negeri)
  static Future<void> selesaikanTransaksi({
    required String transaksiId,
    required String adminId,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      await _supabase.from('transaksi').update({
        'status_transfer': 'selesai',
        'diperbarui_pada': now,
      }).eq('id', transaksiId);

      // Catat ke jejak_audit_admin
      await _catatAuditLog(
        adminId: adminId,
        aksi: 'TRANSAKSI_SELESAI',
        deskripsi: 'Pengiriman dana ke rekening penerima luar negeri telah selesai diproses oleh mitra.',
        transaksiId: transaksiId,
      );
    } catch (e) {
      debugPrint('Error selesaikanTransaksi: $e');
      rethrow;
    }
  }

  /// Helper untuk mencatat log audit admin
  static Future<void> _catatAuditLog({
    required String adminId,
    required String aksi,
    required String deskripsi,
    required String transaksiId,
  }) async {
    try {
      await _supabase.from('jejak_audit_admin').insert({
        'id_admin': adminId,
        'aksi': aksi,
        'deskripsi': deskripsi,
        'id_transaksi': transaksiId,
      });
    } catch (e) {
      // Jika tabel jejak_audit_admin belum dibuat di Supabase, jangan sampai menggagalkan alur utama
      debugPrint('Catatan audit admin gagal disimpan (pastikan tabel jejak_audit_admin sudah dimigrasikan): $e');
    }
  }

  /// Menghitung ringkasan statistik antrean transaksi
  static Future<Map<String, int>> getStatistikAntrean() async {
    try {
      final response = await _supabase
          .from('transaksi')
          .select('status_transfer, status_pembayaran');

      int diproses = 0;
      int diverifikasi = 0;
      int diteruskan = 0;
      int selesai = 0;
      int total = response.length;

      for (final row in response) {
        final st = row['status_transfer']?.toString().toLowerCase() ?? '';
        final sp = row['status_pembayaran']?.toString().toLowerCase() ?? '';

        if (st == 'diproses' || (st == 'pending' && sp == 'dibayar')) {
          diproses++;
        } else if (st == 'diverifikasi') {
          diverifikasi++;
        } else if (st == 'diteruskan') {
          diteruskan++;
        } else if (st == 'selesai') {
          selesai++;
        }
      }

      return {
        'total': total,
        'diproses': diproses,
        'diverifikasi': diverifikasi,
        'diteruskan': diteruskan,
        'selesai': selesai,
      };
    } catch (e) {
      debugPrint('Error getStatistikAntrean: $e');
      return {
        'total': 0,
        'diproses': 0,
        'diverifikasi': 0,
        'diteruskan': 0,
        'selesai': 0,
      };
    }
  }
}
