import 'dart:io';
import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ktp_data_final_screen.dart';

class KtpScanScreen extends StatefulWidget {
  // Diteruskan dari OtpVerificationScreen → agar bisa disimpan ke Supabase
  // di tahap KtpDataFinalScreen bersama data KTP lainnya.
  final bool setujuSnk;

  const KtpScanScreen({super.key, this.setujuSnk = false});

  @override
  State<KtpScanScreen> createState() => _KtpScanScreenState();
}

class _KtpScanScreenState extends State<KtpScanScreen> {
  CameraController? _controller;
  bool _isBusy = false;
  bool _hasNavigated = false;
  final TextRecognizer _textRecognizer = TextRecognizer();
  Timer? _navigationTimer;

  // --- Semua field KTP ---
  String foundNik = "";
  String foundNamaLengkap = "";
  String foundTempatLahir = "";
  String foundTglLahir = "";
  String foundJenisKelamin = "";
  String foundGolDarah = "";
  String foundAlamat = "";
  String foundRtrw = "";
  String foundKelDesa = "";
  String foundKecamatan = "";
  String foundAgama = "";
  String foundStatusPerkawinan = "";
  String foundPekerjaan = "";
  String foundKewarganegaraan = "";
  String foundBerlakuHingga = "";

  // Lock agar field tidak di-overwrite setelah berhasil dideteksi
  final Set<String> _lockedFields = {};

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      // PERBAIKAN: set format sesuai platform agar ML Kit bisa baca dengan benar
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.nv21,
    );

    try {
      await _controller!.initialize();
      if (!mounted) return;
      _controller!.startImageStream(_processCameraImage);
      setState(() {});
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || _hasNavigated) return;
    _isBusy = true;

    try {
      final InputImage? inputImage = _buildInputImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      _extractData(recognizedText);
    } catch (e) {
      debugPrint("OCR Error: $e");
    } finally {
      _isBusy = false;
    }
  }

  /// Konversi CameraImage ke InputImage yang benar untuk Android & iOS
  InputImage? _buildInputImage(CameraImage image) {
    final camera = _controller?.description;
    if (camera == null) return null;

    // ── Tentukan rotasi berdasarkan platform & arah sensor ──
    InputImageRotation rotation;
    if (Platform.isIOS) {
      // iOS: sensor orientation langsung dipakai
      rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation)
          ?? InputImageRotation.rotation0deg;
    } else {
      // Android: kompensasi rotasi untuk kamera depan vs belakang
      int rotationCompensation = camera.sensorOrientation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (360 - rotationCompensation) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation)
          ?? InputImageRotation.rotation90deg;
    }

    // ── Tentukan format gambar berdasarkan platform ──
    if (Platform.isIOS) {
      // iOS menggunakan bgra8888, hanya 1 plane
      if (image.planes.isEmpty) return null;
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } else {
      // Android menggunakan nv21, gabungkan semua plane
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      return InputImage.fromBytes(
        bytes: allBytes.done().buffer.asUint8List(),
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────
  //  UTILITAS
  // ─────────────────────────────────────────────

  /// Ambil nilai setelah tanda pemisah (: - =) pada baris yang sama
  String _valueAfterSeparator(String line) {
    // Pisah dari separator pertama yang ditemukan
    final parts = line.split(RegExp(r'[:=]'));
    if (parts.length > 1) {
      return parts.sublist(1).join(':').trim();
    }
    return '';
  }

  /// Cek apakah teks ini adalah label KTP (bukan nilai data)
  bool _isKtpLabel(String text) {
    return RegExp(
      r'^(NIK|NAMA|TEMPAT|LAHIR|JENIS|KELAMIN|GOL|DARAH|ALAMAT|RT/?RW|'
      r'KEL/?DESA|KECAMATAN|AGAMA|STATUS|PERKAWINAN|PEKERJAAN|'
      r'KEWARGANEGARAAN|BERLAKU|PROVINSI|KABUPATEN|KOTA)$',
      caseSensitive: false,
    ).hasMatch(text.trim());
  }

  // ─────────────────────────────────────────────
  //  EKSTRAKSI UTAMA (diperbaiki)
  // ─────────────────────────────────────────────

  void _extractData(RecognizedText recognizedText) {
    // Kumpulkan semua baris
    final List<String> lines = [];
    for (final TextBlock block in recognizedText.blocks) {
      for (final TextLine line in block.lines) {
        final trimmed = line.text.trim();
        if (trimmed.isNotEmpty) lines.add(trimmed);
      }
    }

    // ── DEBUG LOG: tampilkan semua teks yang berhasil dibaca OCR ──
    if (lines.isNotEmpty) {
      debugPrint("=== OCR RAW LINES (${lines.length} baris) ===");
      for (int idx = 0; idx < lines.length; idx++) {
        debugPrint("[$idx] ${lines[idx]}");
      }
      debugPrint("=== END OCR ===");
    } else {
      debugPrint("OCR: tidak ada teks terdeteksi (lines kosong)");
    }

    for (int i = 0; i < lines.length; i++) {
      final String raw = lines[i];
      final String upper = raw.toUpperCase().trim();

      // ── 1. NIK ──────────────────────────────────────────────────────────
      // PERBAIKAN: Hanya ambil NIK jika ada kata "NIK" di baris tsb atau baris sebelumnya
      // Ini mencegah angka lain (tanggal, RT/RW) dianggap NIK
      if (!_lockedFields.contains('nik')) {
        // Ambil semua baris yang mengandung "NIK" atau baris dengan pola 16 digit NIK
        if (upper.contains('NIK') || RegExp(r'\b\d[\d\s]{14,17}\b').hasMatch(upper)) {
          // Coba ambil angka dari baris yang sama dulu
          // Toleran terhadap OCR yang membaca huruf mirip angka (D→0, O→0, I→1, S→5)
          String normalized = upper
              .replaceAll('O', '0').replaceAll('D', '0')
              .replaceAll('I', '1').replaceAll('S', '5')
              .replaceAll('B', '8').replaceAll('G', '6');
          final sameLineDig = normalized.replaceAll(RegExp(r'[^0-9]'), '');
          // NIK bisa 16 digit, tapi kadang OCR bikin 15 karena 1 digit miss
          if (sameLineDig.length >= 15 && sameLineDig.length <= 17) {
            foundNik = sameLineDig.substring(0, sameLineDig.length > 16 ? 16 : sameLineDig.length);
            _lockedFields.add('nik');
          } else if (upper.contains('NIK') && i + 1 < lines.length) {
            // Kalau tidak ada di baris ini, cek baris berikutnya
            String nextNorm = lines[i + 1].toUpperCase()
                .replaceAll('O', '0').replaceAll('D', '0')
                .replaceAll('I', '1').replaceAll('S', '5');
            final nextDig = nextNorm.replaceAll(RegExp(r'[^0-9]'), '');
            if (nextDig.length >= 15 && nextDig.length <= 17) {
              foundNik = nextDig.substring(0, nextDig.length > 16 ? 16 : nextDig.length);
              _lockedFields.add('nik');
            }
          }
        }
      }

      // ── 2. NAMA ─────────────────────────────────────────────────────────
      // PERBAIKAN: pastikan yang diambil bukan baris yg mengandung "GOL" atau angka murni
      if (!_lockedFields.contains('nama_lengkap') && upper.contains('NAMA')) {
        String val = _valueAfterSeparator(upper);

        // Jika nilai kosong atau sama dengan label, ambil dari baris berikutnya
        if (val.isEmpty || val == 'NAMA') {
          if (i + 1 < lines.length) {
            val = lines[i + 1].toUpperCase().trim();
          }
        }

        // Buang segmen "GOL DARAH" yang sering muncul di baris yang sama dengan nama
        val = val.replaceAll(RegExp(r'GOL\.?\s?DARAH.*'), '').trim();
        // Buang sisa label lain
        val = val.replaceAll(RegExp(r'\b(NAMA|LENGKAP)\b'), '').trim();

        if (val.length > 2 && !RegExp(r'^\d+$').hasMatch(val) && !_isKtpLabel(val)) {
          foundNamaLengkap = val;
          _lockedFields.add('nama_lengkap');
        }
      }

      // ── 3. TEMPAT & TANGGAL LAHIR ────────────────────────────────────────
      if ((!_lockedFields.contains('tempatlahir') || !_lockedFields.contains('tgllahir')) &&
          (upper.contains('TEMPAT') || upper.contains('TGL') || upper.contains('TANGGAL') ||
           upper.contains('LAHIR'))) {
        // Hapus semua label yang mungkin nempel
        String val = upper
            .replaceAll(RegExp(r'TEMPAT\s*/?'), '')
            .replaceAll(RegExp(r'TGL\.?\s*LAHIR\s*'), '')
            .replaceAll(RegExp(r'TANGGAL\s*LAHIR\s*'), '')
            .replaceAll(RegExp(r'^LAHIR\s*'), '')
            .replaceAll(RegExp(r'[:=]\s*'), '')
            .trim();

        if (val.isEmpty && i + 1 < lines.length) {
          val = lines[i + 1].toUpperCase().trim();
        }

        // Cari tanggal dengan format: DD-MM-YYYY, DD/MM/YYYY
        final dateMatch = RegExp(r'(\d{1,2})[-/\s](\d{1,2})[-/\s](\d{4})').firstMatch(val);
        if (dateMatch != null) {
          final dd = dateMatch.group(1)!.padLeft(2, '0');
          final mm = dateMatch.group(2)!.padLeft(2, '0');
          final yyyy = dateMatch.group(3)!;
          foundTglLahir = '$dd-$mm-$yyyy';
          foundTempatLahir = val
              .substring(0, dateMatch.start)
              .replaceAll(RegExp(r'[,\s]+$'), '')
              .trim();
          if (foundTempatLahir.isEmpty && i > 0) {
            final prevVal = _valueAfterSeparator(lines[i - 1].toUpperCase());
            if (prevVal.isNotEmpty && !_isKtpLabel(prevVal)) {
              foundTempatLahir = prevVal;
            }
          }
          if (foundTempatLahir.isNotEmpty) _lockedFields.add('tempatlahir');
          if (foundTglLahir.isNotEmpty) _lockedFields.add('tgllahir');
        }
      }

      // ── 4. JENIS KELAMIN ─────────────────────────────────────────────────
      if (!_lockedFields.contains('jeniskelamin') &&
          (upper.contains('KELAMIN') || upper.contains('JENIS') ||
           upper.contains('LAKI') || upper.contains('LAK') || upper.contains('PEREMPUAN'))) {
        final combined = i + 1 < lines.length
            ? '$upper ${lines[i + 1].toUpperCase()}'
            : upper;
        if (combined.contains('PEREMPUAN') || combined.contains('WANITA')) {
          foundJenisKelamin = 'PEREMPUAN';
          _lockedFields.add('jeniskelamin');
        } else if (combined.contains('LAKI') || combined.contains('LAK1') ||
                   RegExp(r'LAK\w*LAKI').hasMatch(combined)) {
          foundJenisKelamin = 'LAKI-LAKI';
          _lockedFields.add('jeniskelamin');
        }
      }

      // ── 5. GOL. DARAH ────────────────────────────────────────────────────
      if (!_lockedFields.contains('goldarah') &&
          (upper.contains('DARAH') || upper.contains('GOL') || upper.contains('GEL'))) {
        // Cari pola golongan darah: A, B, AB, O — hindari false positive dari "DARAH" itu sendiri
        final golMatch = RegExp(r'\b(AB|A|B|O)[+\-]?\b').firstMatch(
          upper.replaceAll('DARAH', '').replaceAll('GOL', '').replaceAll('AGAMA', ''),
        );
        if (golMatch != null) {
          foundGolDarah = golMatch.group(0)!.trim();
          _lockedFields.add('goldarah');
        } else if (i + 1 < lines.length) {
          final nextUpper = lines[i + 1].toUpperCase().trim();
          final nextGol = RegExp(r'^(AB|A|B|O)[+\-]?$').firstMatch(nextUpper);
          if (nextGol != null) {
            foundGolDarah = nextGol.group(0)!.trim();
            _lockedFields.add('goldarah');
          }
        }
      }

      // ── 6. ALAMAT ────────────────────────────────────────────────────────
      if (!_lockedFields.contains('alamat') && upper.contains('ALAMAT')) {
        // Bersihkan label dari baris saat ini
        String val = upper
            .replaceAll(RegExp(r'^ALAMAT[A-Z]?\s*[:=]?\s*'), '')
            .replaceAll(RegExp(r'^ALAMAT\s*'), '')
            .trim();

        // Jika nilai masih kosong/terlalu pendek, ambil dari baris berikutnya
        if (val.length < 4) {
          if (i + 1 < lines.length) val = lines[i + 1].toUpperCase().trim();
        }

        // Jika baris berikutnya juga label (RT/RW, KEL, dst), coba baris setelahnya
        if (val.length < 4 || _isKtpLabel(val)) {
          if (i + 2 < lines.length) val = lines[i + 2].toUpperCase().trim();
        }

        // Buang label RT/RW yang sering menempel di akhir
        val = val.replaceAll(RegExp(r'RT/?RW.*'), '').trim();

        if (val.length > 3 && !_isKtpLabel(val) && !RegExp(r'^\d+$').hasMatch(val)) {
          // Jika ada baris berikutnya yang masih bagian dari alamat (misal NO=05E)
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1].toUpperCase().trim();
            if (nextLine.contains('NO') || nextLine.contains('BLOK') || nextLine.contains('JL')) {
              val = '$val $nextLine'.trim();
            }
          }
          foundAlamat = val;
          _lockedFields.add('alamat');
        }
      }

      // ── 7. RT/RW ─────────────────────────────────────────────────────────
      if (!_lockedFields.contains('rtrw')) {
        // PERBAIKAN: regex lebih fleksibel, toleran spasi di sekitar "/"
        final rtrwMatch = RegExp(r'\b(\d{2,3})\s*/\s*(\d{2,3})\b').firstMatch(upper);
        if (rtrwMatch != null) {
          // Pastikan ini bukan dari baris NIK/tanggal yang kebetulan ada slash
          if (!upper.contains('NIK') && !upper.contains('TGL') && !upper.contains('BERLAKU')) {
            foundRtrw = '${rtrwMatch.group(1)}/${rtrwMatch.group(2)}';
            _lockedFields.add('rtrw');
          }
        }
      }

      // ── 8. KEL/DESA ──────────────────────────────────────────────────────
      // PERBAIKAN: perluas pendeteksian, OCR sering hasilkan variasi penulisan
      if (!_lockedFields.contains('keldesa') &&
          (upper.contains('KEL') && (upper.contains('DESA') || upper.contains('/') || upper.contains('KEL '))) ||
          upper.startsWith('KEL') && upper.length < 30) {
        String val = _valueAfterSeparator(upper);
        // Buang label "KEL/DESA" dari depan jika masih ada
        val = val.replaceAll(RegExp(r'^(KEL/?DESA|KEL|DESA)\s*'), '').trim();
        if (val.isEmpty) {
          if (i + 1 < lines.length) {
            val = lines[i + 1].toUpperCase().trim();
          }
        }
        if (val.length > 2 && !_isKtpLabel(val) && !RegExp(r'^\d+$').hasMatch(val)) {
          foundKelDesa = val;
          _lockedFields.add('keldesa');
        }
      }

      // ── 9. KECAMATAN ─────────────────────────────────────────────────────
      if (!_lockedFields.contains('kecamatan') && upper.contains('KECAMATAN')) {
        // Hapus label "KECAMATAN" dari baris, sisa = nilai
        String val = upper
            .replaceAll(RegExp(r'KECAMATAN\s*[:=]?\s*'), '')
            .trim();
        if (val.isEmpty) {
          if (i + 1 < lines.length) val = lines[i + 1].toUpperCase().trim();
        }
        if (val.length > 2 && !_isKtpLabel(val)) {
          foundKecamatan = val;
          _lockedFields.add('kecamatan');
        }
      }

      // ── 10. AGAMA ────────────────────────────────────────────────────────
      if (!_lockedFields.contains('agama') && upper.contains('AGAMA')) {
        String val = _valueAfterSeparator(upper);
        if (val.isEmpty || val == 'AGAMA') {
          if (i + 1 < lines.length) val = lines[i + 1].toUpperCase().trim();
        }
        // Normalisasi nama agama yang sering salah baca OCR
        final agamaList = ['ISLAM', 'KRISTEN', 'KATOLIK', 'KATHOLIK', 'CATHOLIC', 'HINDU', 'BUDDHA', 'BUDHA', 'KONGHUCU'];
        for (final agama in agamaList) {
          if (val.contains(agama)) {
            foundAgama = agama;
            _lockedFields.add('agama');
            break;
          }
        }
        // Jika tidak cocok dengan daftar tapi panjang memadai, simpan apa adanya
        if (!_lockedFields.contains('agama') && val.length > 2 && !_isKtpLabel(val)) {
          foundAgama = val;
          _lockedFields.add('agama');
        }
      }

      // ── 11. STATUS PERKAWINAN ─────────────────────────────────────────────
      if (!_lockedFields.contains('statusperkawinan') &&
          (upper.contains('STATUS') || upper.contains('PERKAWIN') || upper.contains('KAWIN'))) {
        final combined = i + 1 < lines.length
            ? '$upper ${lines[i + 1].toUpperCase()}'
            : upper;
        if (combined.contains('BELUM')) {
          foundStatusPerkawinan = 'BELUM KAWIN';
          _lockedFields.add('statusperkawinan');
        } else if (combined.contains('CERAI MATI')) {
          foundStatusPerkawinan = 'CERAI MATI';
          _lockedFields.add('statusperkawinan');
        } else if (combined.contains('CERAI HIDUP')) {
          foundStatusPerkawinan = 'CERAI HIDUP';
          _lockedFields.add('statusperkawinan');
        } else if (combined.contains('CERAI')) {
          foundStatusPerkawinan = 'CERAI';
          _lockedFields.add('statusperkawinan');
        } else if (combined.contains('KAWIN')) {
          foundStatusPerkawinan = 'KAWIN';
          _lockedFields.add('statusperkawinan');
        }
      }

      // ── 12. PEKERJAAN ────────────────────────────────────────────────────
      if (!_lockedFields.contains('pekerjaan') && upper.contains('PEKERJAAN')) {
        String val = upper
            .replaceAll(RegExp(r'PEKERJAAN\s*[:=]?\s*'), '')
            .trim();
        if (val.isEmpty) {
          if (i + 1 < lines.length) val = lines[i + 1].toUpperCase().trim();
        }
        // Normalisasi: "BELUMTIDAK BEKERJA" → "BELUM/TIDAK BEKERJA"
        val = val.replaceAll(RegExp(r'BELUM\s*TIDAK'), 'BELUM/TIDAK');
        if (val.length > 2 && !_isKtpLabel(val)) {
          foundPekerjaan = val;
          _lockedFields.add('pekerjaan');
        }
      }

      // ── 13. KEWARGANEGARAAN ──────────────────────────────────────────────
      if (!_lockedFields.contains('kewarganegaraan') &&
          (upper.contains('KEWARGANEGARAAN') || upper.contains('KEWARGANE'))) {
        String val = upper
            .replaceAll(RegExp(r'KEWARGANEGARAAN?\s*[:=]?\s*'), '')
            .trim();
        if (val.isEmpty) {
          if (i + 1 < lines.length) val = lines[i + 1].toUpperCase().trim();
        }
        // OCR sering baca "WNE" untuk "WNI"
        val = val.replaceAll(RegExp(r'\bWN[EI1]\b'), 'WNI');
        if (val.isEmpty || _isKtpLabel(val)) val = 'WNI';
        foundKewarganegaraan = val;
        _lockedFields.add('kewarganegaraan');
      }

      // ── 14. BERLAKU HINGGA ───────────────────────────────────────────────
      // PERBAIKAN: field ini sebelumnya tidak di-handle sama sekali
      if (!_lockedFields.contains('berlakuhingga') && upper.contains('BERLAKU')) {
        String val = _valueAfterSeparator(upper);
        if (val.isEmpty || val == 'BERLAKU HINGGA') {
          if (i + 1 < lines.length) val = lines[i + 1].toUpperCase().trim();
        }
        // Cek apakah nilai adalah "SEUMUR HIDUP" atau tanggal
        if (val.contains('SEUMUR') || val.contains('HIDUP')) {
          foundBerlakuHingga = 'SEUMUR HIDUP';
          _lockedFields.add('berlakuhingga');
        } else {
          // Cari format tanggal
          final dateMatch = RegExp(r'(\d{2})[-/\s](\d{2})[-/\s](\d{4})').firstMatch(val);
          if (dateMatch != null) {
            foundBerlakuHingga =
                '${dateMatch.group(1)}-${dateMatch.group(2)}-${dateMatch.group(3)}';
            _lockedFields.add('berlakuhingga');
          }
        }
      }
    }

    // ── PENTING: update UI agar progress bar bergerak ──
    if (mounted) setState(() {});

    _checkAndNavigate();
  }

  // ─────────────────────────────────────────────
  //  CEK KELENGKAPAN & NAVIGASI
  // ─────────────────────────────────────────────

  void _checkAndNavigate() {
    if (_hasNavigated) return;

    // NIK dianggap valid jika panjangnya 15-16 digit
    final bool nikValid = foundNik.length >= 15 && foundNik.length <= 16;

    final bool isReady =
        nikValid &&
        foundNamaLengkap.isNotEmpty &&
        foundAlamat.isNotEmpty;

    final bool isFullyComplete =
        isReady &&
        foundRtrw.isNotEmpty &&
        foundKelDesa.isNotEmpty &&
        foundKecamatan.isNotEmpty;

    // Semua 15 field terdeteksi → navigate segera (1 detik)
    final bool allFieldsDetected = _lockedFields.length >= 15;

    if (allFieldsDetected || isFullyComplete) {
      // Cancel timer lama yang mungkin sudah jalan (misal dari kondisi isReady sebelumnya)
      if (_navigationTimer != null) {
        _navigationTimer!.cancel();
        _navigationTimer = null;
      }
      setState(() {});
      _navigationTimer = Timer(const Duration(seconds: 1), () {
        if (!_hasNavigated) _navigateToFinal();
      });
    } else if (isReady && _navigationTimer == null) {
      // Cukup NIK+Nama+Alamat → navigate setelah 5 detik menunggu field tambahan
      setState(() {});
      _navigationTimer = Timer(const Duration(seconds: 5), () {
        if (!_hasNavigated) _navigateToFinal();
      });
    }
  }

  void _navigateToFinal() {
    _hasNavigated = true;
    _controller?.stopImageStream();
    _navigationTimer?.cancel();

    String cleanValue(String val) {
      return val
          .replaceAll(RegExp(r'^[:\-=\s]+|[:\-=\s]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KtpDataFinalScreen(
          nik: foundNik,
          nama: cleanValue(foundNamaLengkap),
          tempatLahir: cleanValue(foundTempatLahir),
          tglLahir: cleanValue(foundTglLahir),
          jenisKelamin: cleanValue(foundJenisKelamin),
          golDarah: cleanValue(foundGolDarah),
          alamat: cleanValue(foundAlamat),
          rtrw: cleanValue(foundRtrw),
          kelDesa: cleanValue(foundKelDesa),
          kecamatan: cleanValue(foundKecamatan),
          agama: cleanValue(foundAgama),
          statusPerkawinan: cleanValue(foundStatusPerkawinan),
          pekerjaan: cleanValue(foundPekerjaan),
          kewarganegaraan: cleanValue(foundKewarganegaraan),
          berlakuHingga: cleanValue(foundBerlakuHingga),
          // Teruskan nilai persetujuan S&K dari halaman registrasi
          setujuSnk: widget.setujuSnk,
        ),
      ),
    ).then((_) => _resetState());
  }

  void _resetState() {
    _lockedFields.clear();
    _hasNavigated = false;
    _navigationTimer = null;
    foundNik = '';
    foundNamaLengkap = '';
    foundTempatLahir = '';
    foundTglLahir = '';
    foundJenisKelamin = '';
    foundGolDarah = '';
    foundAlamat = '';
    foundRtrw = '';
    foundKelDesa = '';
    foundKecamatan = '';
    foundAgama = '';
    foundStatusPerkawinan = '';
    foundPekerjaan = '';
    foundKewarganegaraan = '';
    foundBerlakuHingga = '';
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.startImageStream(_processCameraImage);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    _navigationTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bool nikValid = foundNik.length >= 15 && foundNik.length <= 16;
    final bool isReady = nikValid && foundNamaLengkap.isNotEmpty && foundAlamat.isNotEmpty;
    final bool isFullyComplete =
        isReady && foundRtrw.isNotEmpty && foundKelDesa.isNotEmpty;

    final int totalFields = 15;
    final int foundCount = _lockedFields.length;
    final bool allDetected = foundCount >= totalFields;

    Color borderColor = Colors.white54;
    bool canConfirm = false;
    String statusMsg = "Arahkan kamera ke KTP Anda";
    if (allDetected || isFullyComplete) {
      borderColor = Colors.greenAccent;
      statusMsg = "✅ Konfirmasi Data KTP";
      canConfirm = true;
    } else if (isReady) {
      borderColor = Colors.amberAccent;
      statusMsg = "⏳ NIK, Nama & Alamat ditemukan. Menunggu data tambahan...";
    } else if (nikValid) {
      borderColor = Colors.blueAccent;
      statusMsg = "🔍 NIK ditemukan. Mencari Nama & Alamat...";
    }


    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scan KTP"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(_controller!)),
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _KtpOverlayPainter(
              context: context,
              borderColor: borderColor,
            ),
          ),
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: foundCount / totalFields,
                  backgroundColor: Colors.white24,
                  color: borderColor,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 6),
                Text(
                  "$foundCount / $totalFields field terdeteksi",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Center(
              child: GestureDetector(
                onTap: canConfirm && !_hasNavigated ? _navigateToFinal : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: canConfirm ? Colors.greenAccent.withOpacity(0.15) : Colors.black45,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: borderColor.withOpacity(canConfirm ? 1.0 : 0.5),
                      width: canConfirm ? 2 : 1,
                    ),
                    boxShadow: canConfirm
                        ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)]
                        : [],
                  ),
                  child: Text(
                    statusMsg,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: borderColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KtpOverlayPainter extends CustomPainter {
  final BuildContext context;
  final Color borderColor;

  _KtpOverlayPainter({required this.context, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double cardW = size.width * 0.9;
    final double cardH = cardW * 0.63;
    final double left = (size.width - cardW) / 2;
    final double top = (size.height - cardH) / 2;
    final Rect cardRect = Rect.fromLTWH(left, top, cardW, cardH);
    final RRect cardRRect =
        RRect.fromRectAndRadius(cardRect, const Radius.circular(16));

    final Paint overlay = Paint()..color = Colors.black.withOpacity(0.55);
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(cardRRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlay);

    final Paint border = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(cardRRect, border);

    final Paint corner = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const double cs = 24.0;
    final List<List<Offset>> corners = [
      [Offset(left, top + cs), Offset(left, top), Offset(left + cs, top)],
      [
        Offset(left + cardW - cs, top),
        Offset(left + cardW, top),
        Offset(left + cardW, top + cs)
      ],
      [
        Offset(left + cardW, top + cardH - cs),
        Offset(left + cardW, top + cardH),
        Offset(left + cardW - cs, top + cardH)
      ],
      [
        Offset(left + cs, top + cardH),
        Offset(left, top + cardH),
        Offset(left, top + cardH - cs)
      ],
    ];

    for (final pts in corners) {
      final p = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(p, corner);
    }
  }

  @override
  bool shouldRepaint(_KtpOverlayPainter old) => old.borderColor != borderColor;
}