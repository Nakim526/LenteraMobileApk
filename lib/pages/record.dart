import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as Img;
import 'package:url_launcher/url_launcher.dart';

class RecordPage extends StatefulWidget {
  @override
  _RecordPageState createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  CameraController? _cameraController;
  String? _location;
  String? _photoPath;
  bool _isProcessing = false;
  List<CameraDescription>? cameras;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
    if (cameras!.isNotEmpty) {
      _initializeCamera(frontCamera: true);
    } else {
      setState(() {
        _location = 'Kamera tidak tersedia di perangkat ini.';
      });
    }
  }

  Future<void> _initializeCamera({required bool frontCamera}) async {
    final camera = cameras!.firstWhere(
      (cam) => frontCamera
          ? cam.lensDirection == CameraLensDirection.front
          : cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras!.first,
    );

    _cameraController = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      setState(() {
        _location = 'Error kamera: $e';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureLocationAndPhoto() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await _checkAndRequestLocationPermission();

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!_cameraController!.value.isInitialized) {
        throw 'Kamera belum siap.';
      }

      final image = await _cameraController!.takePicture();
      final imageBytes = await File(image.path).readAsBytes();
      final img = Img.decodeImage(imageBytes)!;
      final mirroredImg = Img.flipHorizontal(img);

      // Simpan gambar hasil
      final processedImagePath = '${image.path}_processed.jpg';
      final processedImageFile = File(processedImagePath);
      processedImageFile.writeAsBytesSync(Img.encodeJpg(mirroredImg));

      setState(() {
        _location =
            'Lat: ${position.latitude.toStringAsFixed(6)}, Long: ${position.longitude.toStringAsFixed(6)}';
        _photoPath = processedImagePath;
      });
    } catch (e) {
      setState(() {
        _location = 'Gagal mengambil data: $e';
        _photoPath = null;
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Layanan lokasi tidak aktif. Aktifkan untuk melanjutkan.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
    }
  }

  Future<void> _openMaps() async {
    if (_location != null) {
      final coordinates = _location!.split(', ');
      if (coordinates.length == 2) {
        final lat = coordinates[0].split(': ')[1];
        final long = coordinates[1].split(': ')[1];
        final mapsUrl = 'https://www.google.com/maps?q=$lat,$long';

        if (await canLaunch(mapsUrl)) {
          await launch(mapsUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tidak dapat membuka peta.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Format lokasi tidak valid.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Koordinat belum tersedia.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lokasi & Swafoto'),
      ),
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_cameraController != null &&
                  _cameraController!.value.isInitialized)
                AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..rotateZ(90 * 3.14159 / 180)
                      ..rotateY(3.14159),
                    child: CameraPreview(_cameraController!),
                  ),
                )
              else
                Center(child: CircularProgressIndicator()),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _captureLocationAndPhoto,
                child: Text('Ambil Lokasi & Swafoto'),
              ),
              const SizedBox(height: 20),
              if (_location != null)
                Column(
                  children: [
                    Text(
                      'Lokasi: $_location',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    ElevatedButton(
                      onPressed: _openMaps,
                      child: Text('Buka di Google Maps'),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              if (_photoPath != null)
                Column(
                  children: [
                    Text('Swafoto berhasil diambil!',
                        style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 10),
                    Image.file(
                      File(_photoPath!),
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ],
                ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
