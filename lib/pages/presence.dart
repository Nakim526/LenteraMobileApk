import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as imgs;

class PresencePage extends StatefulWidget {
  const PresencePage({super.key});

  @override
  _PresencePageState createState() => _PresencePageState();
}

class _PresencePageState extends State<PresencePage> {
  CameraController? _cameraController;
  String? _location;
  String? _photoPath;
  bool _isProcessing = false;
  bool _isCaptured = false;
  bool _isCamera = false;
  List<CameraDescription>? cameras;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    setState(() {
      _isCamera = true;
      _isProcessing = true;
    });
    try {
      WidgetsFlutterBinding.ensureInitialized();
      cameras = await availableCameras();
      await _checkAndRequestLocationPermission();
      if (cameras!.isNotEmpty) {
        await _initializeCamera(frontCamera: true);
      } else {
        setState(() {
          _location = 'Kamera tidak tersedia di perangkat ini.';
        });
      }
    } finally {
      setState(() {
        _isCamera = false;
        _isProcessing = false;
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

  Future<void> _getLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final lat = position.latitude.toStringAsFixed(6);
      final long = position.longitude.toStringAsFixed(6);
      final mapsUrl = 'https://www.google.com/maps?q=$lat,$long';

      setState(() {
        _location = mapsUrl;
      });
    } catch (e) {
      setState(() {
        _location = null;
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (!_cameraController!.value.isInitialized) {
      throw 'Kamera belum siap.';
    }

    final image = await _cameraController!.takePicture();
    final imageBytes = await File(image.path).readAsBytes();
    final img = imgs.decodeImage(imageBytes)!;
    final mirroredImg = imgs.flipHorizontal(img);

    // Simpan gambar hasil
    final processedImagePath = '${image.path}_processed.jpg';
    final processedImageFile = File(processedImagePath);
    processedImageFile.writeAsBytesSync(imgs.encodeJpg(mirroredImg));

    setState(() {
      _photoPath = processedImagePath;
    });
  }

  Future<void> _checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Layanan lokasi tidak aktif. Aktifkan untuk melanjutkan.',
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double statusBarHeight = MediaQuery.of(context).padding.top;
    double appBarHeight = kToolbarHeight;
    double availableHeight = screenHeight - statusBarHeight - appBarHeight;
    return WillPopScope(
      onWillPop: () async {
        if (_isCaptured) {
          if (_isProcessing) {
            setState(() {
              _isProcessing = false;
            });
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text("Upload Gagal"),
                  content: Text("Upload dibatalkan. Data gagal disimpan."),
                  actions: [
                    TextButton(
                      child: Text("OK"),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                );
              },
            );
          } else {
            setState(() {
              _isProcessing = false;
              _photoPath = null;
              _isCaptured = false;
            });
          }
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.green[900],
              title: Text(
                'Isi Kehadiran',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              leading: Container(
                margin: const EdgeInsets.only(left: 16),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (_isCaptured) {
                      setState(() {
                        _isCaptured = false;
                        _photoPath = null;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
            body: ListView(
              children: [
                Stack(
                  children: [
                    if (_photoPath == null)
                      if (_cameraController != null &&
                          _cameraController!.value.isInitialized)
                        SizedBox(
                          height: availableHeight,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Ambil Foto Anda",
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 75),
                              AspectRatio(
                                aspectRatio:
                                    _cameraController!.value.aspectRatio,
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..rotateZ(90 * 3.14159 / 180)
                                    ..rotateY(3.14159),
                                  child: CameraPreview(_cameraController!),
                                ),
                              ),
                              SizedBox(height: 12),
                              IconButton(
                                iconSize: 30,
                                onPressed: () async {
                                  setState(() {
                                    _isProcessing = true;
                                  });
                                  await _capturePhoto();
                                  await _getLocation();
                                  Navigator.pop(context, {
                                    'photo': _photoPath,
                                    'location': _location
                                  });
                                  setState(() {
                                    _isProcessing = false;
                                    _isCaptured = true;
                                  });
                                },
                                style: IconButton.styleFrom(
                                  padding: EdgeInsets.all(16.0),
                                  shadowColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30.0),
                                  ),
                                  backgroundColor: Colors.white,
                                  elevation: 4.0,
                                ),
                                icon: Icon(Icons.camera_alt),
                              ),
                              SizedBox(height: 75),
                            ],
                          ),
                        )
                      else
                        _isCamera
                            ? Container()
                            : SizedBox(
                                height: availableHeight,
                                child: Center(
                                  child: Text(
                                    "Tidak dapat mengakses kamera",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              )
                  ],
                ),
              ],
            ),
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
