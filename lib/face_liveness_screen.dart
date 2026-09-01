import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'landing_page_screen.dart';
import 'pin_creation_screen.dart'; 


// Enum untuk melacak tahapan Liveness
enum LivenessStep { lookFront, lookRight, lookLeft, success }

class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({super.key});

  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  // Variabel ML Kit Face Detection
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableTracking: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isDetecting = false;
  XFile? _capturedImage;

  // State Liveness
  LivenessStep _currentStep = LivenessStep.lookFront;
  String _instructionText = "Tatap lurus ke depan & posisikan wajah di oval";
  Color _instructionColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset
            .medium, // Medium lebih ringan untuk pemrosesan AI real-time
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888, // Format wajib untuk ML Kit
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
        _startFaceDetection(); // Mulai streaming AI
      }
    } catch (e) {
      debugPrint("Error camera: $e");
    }
  }

  // Fungsi untuk membaca video stream
  void _startFaceDetection() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (_isDetecting) return; // Mencegah proses bertumpuk
      _isDetecting = true;

      try {
        final inputImage = _convertCameraImageToInputImage(image);
        if (inputImage == null) {
          _isDetecting = false;
          return;
        }

        final faces = await _faceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          final face = faces.first;
          _processFaceLogic(face.headEulerAngleY ?? 0.0);
        }
      } catch (e) {
        debugPrint("Error deteksi wajah: $e");
      } finally {
        _isDetecting = false; // Buka gerbang untuk frame selanjutnya
      }
    });
  }

  // LOGIKA KECERDASAN BUATAN (STATE MACHINE)
  void _processFaceLogic(double eulerY) async {
    if (_currentStep == LivenessStep.lookFront) {
      // Jika wajah menghadap lurus (Toleransi kemiringan -5 sampai 5 derajat)
      if (eulerY > -5 && eulerY < 5) {
        setState(() {
          _instructionText = "Wajah terdeteksi! Toleh ke KANAN";
          _instructionColor = Colors.greenAccent;
          _currentStep = LivenessStep.lookRight;
        });

        // Jepret foto KTP menghadap depan diam-diam (simpan di background)
        _cameraController?.stopImageStream();
        _capturedImage = await _cameraController?.takePicture();
        _startFaceDetection(); // Lanjutkan stream untuk deteksi gerakan
      }
    } else if (_currentStep == LivenessStep.lookRight) {
      // Jika menoleh ke kanan (Euler Y < -25)
      if (eulerY < -25) {
        setState(() {
          _instructionText = "Bagus! Sekarang toleh ke KIRI";
          _instructionColor = Colors.orangeAccent;
          _currentStep = LivenessStep.lookLeft;
        });
      }
    } else if (_currentStep == LivenessStep.lookLeft) {
      // Jika menoleh ke kiri (Euler Y > 25)
      if (eulerY > 25) {
        setState(() {
          _instructionText = "Verifikasi Berhasil!";
          _instructionColor = Colors.blueAccent;
          _currentStep = LivenessStep.success;
        });

        // Hentikan stream dan masuk ke halaman Preview
        await _cameraController?.stopImageStream();
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {}); // Picu UI untuk pindah ke Preview
      }
    }
  }

  // Fungsi Konversi Gambar Kamera bawaan ke format ML Kit Google
  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = sensorOrientation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + 0) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21))
      return null;

    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: image.planes[0].bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _isDetecting = false; // Hentikan flag deteksi
    _faceDetector.close(); // Tutup ML Kit
    _cameraController?.dispose(); // Langsung buang controllernya
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Liveness Check',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      // Jika sudah melewati semua step (success), tampilkan hasilnya
      body: _currentStep == LivenessStep.success && _capturedImage != null
          ? _buildPreview()
          : _buildLiveCamera(),
    );
  }

  Widget _buildLiveCamera() {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }

    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: CameraPreview(_cameraController!),
        ),
        // Overlay Oval Gelap
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.8),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(color: Colors.transparent),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 300,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(200),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Teks Instruksi Dinamis
        Positioned(
          top: 60,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _instructionText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _instructionColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(File(_capturedImage!.path), fit: BoxFit.cover),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 50),
              const SizedBox(height: 10),
              const Text(
                'Liveness Check Berhasil!\nWajah Anda telah terverifikasi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.blue,
                ),
                onPressed: () async { // <-- Tambahkan async
                  // 1. Matikan pendeteksian wajah agar tidak ada proses berulang
                  _isDetecting = false;
                  
                  // 2. Hentikan kamera dengan aman SEBELUM pindah halaman
                  if (_cameraController != null && _cameraController!.value.isStreamingImages) {
                    try {
                      await _cameraController!.stopImageStream();
                    } catch (e) {
                      debugPrint('Abaikan error stop stream: $e');
                    }
                  }

                  if (!mounted) return; // Pastikan widget masih aktif

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Wajah terverifikasi! Mari buat PIN Keamanan Anda.'),
                    ),
                  );
                  
                  Future.delayed(const Duration(seconds: 1), () {
                    if (!mounted) return;
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PinCreationScreen(),
                      ),
                    );
                  });
                },
                child: const Text(
                  'Lanjutkan Buat PIN', // <--- Ganti teks tombolnya
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
