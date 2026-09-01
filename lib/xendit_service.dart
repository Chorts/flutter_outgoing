import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class XenditService {
  // ⚠️  SEGERA ganti key ini — key lama sudah ter-expose, harus di-revoke
  // dan generate key baru di Xendit Dashboard → Settings → API Keys
  static const String _secretKey = 'xnd_development_m786avPwKfIUuMki4lUNUYZA42FardHsN8HWD3PieCDiEv1tVssegaA9o6oTuDe';

  static const String _baseUrl = 'https://api.xendit.co';

  static String get _authHeader {
    final credentials = base64Encode(utf8.encode('$_secretKey:'));
    return 'Basic $credentials';
  }

  static Future<Map<String, dynamic>> buatQrisCode({
    required String referensiTransaksi,
    required double nominalIDR,
    required String deskripsi,
  }) async {
    final uri = Uri.parse('$_baseUrl/qr_codes');

    // FIX 1: reference_id harus unik setiap request — tambah timestamp
    // agar tidak ditolak Xendit saat retry/test ulang
    final uniqueRefId =
        '${referensiTransaksi}_${DateTime.now().millisecondsSinceEpoch}';

    // FIX 2: amount harus integer bulat, gunakan round() bukan toInt()
    // toInt() membuang desimal (7051463.9 → 7051463)
    // round() membulatkan dengan benar (7051463.9 → 7051464)
    final int amount = nominalIDR.round();

    // Xendit QRIS: minimum Rp 1.500, maksimum Rp 10.000.000 per transaksi
    if (amount < 1500) {
      throw Exception('Nominal minimum transfer adalah Rp 1.500');
    }
    // Limit nominal: Xendit akan menolak jika amount melebihi batas

    final body = {
      'reference_id' : uniqueRefId,
      'type'         : 'DYNAMIC',
      'currency'     : 'IDR',
      'amount'       : amount,         // ✅ integer, bukan double
      // channel_code dihapus — tidak diperlukan di QR Codes API Xendit
      'expires_at'   : DateTime.now()
          .add(const Duration(minutes: 15))
          .toUtc()
          .toIso8601String(),
    };

    // FIX 4: Log request body agar mudah debug kalau error lagi
    debugPrint('=== Xendit Request ===');
    debugPrint('URL: $uri');
    debugPrint('Body: ${jsonEncode(body)}');

    final response = await http.post(
      uri,
      headers: {
        'Authorization' : _authHeader,
        'Content-Type'  : 'application/json',
        'api-version'   : '2022-07-31',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));

    debugPrint('=== Xendit Response ===');
    debugPrint('Status: ${response.statusCode}');
    debugPrint('Body: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return {
        'xendit_qr_id' : data['id']?.toString() ?? '',
        'qr_string'    : data['qr_string']?.toString() ?? '',
        'status'       : data['status']?.toString() ?? 'ACTIVE',
        'expires_at'   : data['expires_at']?.toString() ?? '',
      };
    } else {
      // FIX 5: Tampilkan error detail dari Xendit agar mudah debug
      final err = jsonDecode(response.body) as Map<String, dynamic>;
      final errorCode    = err['error_code'] ?? '';
      final errorMessage = err['message']    ?? response.body;
      debugPrint('Xendit error_code: $errorCode');
      debugPrint('Xendit message: $errorMessage');
      throw Exception('Xendit error ${response.statusCode} [$errorCode]: $errorMessage');
    }
  }

  static Future<String> cekStatusQr(String xenditQrId) async {
    final uri = Uri.parse('$_baseUrl/qr_codes/$xenditQrId');

    final response = await http.get(
      uri,
      headers: {
        'Authorization' : _authHeader,
        'api-version'   : '2022-07-31',
      },
    ).timeout(const Duration(seconds: 10));

    debugPrint('Polling QR $xenditQrId → ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['status']?.toString() ?? 'ACTIVE';
    } else {
      throw Exception('Gagal cek status QR: ${response.statusCode}');
    }
  }
}