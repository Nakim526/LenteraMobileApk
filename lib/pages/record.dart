import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as Img;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';

class RecordPage extends StatefulWidget {
  @override
  _RecordPageState createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("uploads");
  final _nameController = TextEditingController();
  final _nimController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  static const String clientId = "ca88e99d5b919db";
  CameraController? _cameraController;
  String? _location;
  String? _photoPath;
  bool _isProcessing = false;
  bool _isSending = false;
  bool _isCaptured = false;
  List<CameraDescription>? cameras;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  void _retakePhoto() {
    setState(() {
      _photoPath = null;
    });
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
      setState(() {
        _isProcessing = true;
      });
      await _cameraController!.initialize();
    } catch (e) {
      setState(() {
        _location = 'Error kamera: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
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

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final databaseRef = FirebaseDatabase.instance.ref();
      final snapshot = await databaseRef.child('users/${user.uid}').get();
      if (snapshot.exists) {
        setState(() {
          _userData = Map<String, dynamic>.from(snapshot.value as Map);
          _nameController.text = _userData?['name'] ?? '';
          _nimController.text = _userData?['nim'] ?? '';
        });
      }
    }
  }

  Future<void> _sendData() async {
    if (_formKey.currentState!.validate())
      setState(() {
        _isSending = true;
      });
    if (_location != null) {
      final coordinates = _location!.split(', ');
      if (coordinates.length == 2) {
        final lat = coordinates[0].split(': ')[1];
        final long = coordinates[1].split(': ')[1];
        final mapsUrl = 'https://www.google.com/maps?q=$lat,$long';

        if (await canLaunch(mapsUrl)) {
          _location = mapsUrl;
          setState(() {
            _uploadData();
          });
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

  Future<void> saveData(
      String name, String nim, String location, String photoUrl) async {
    await _dbRef.push().set(
      {
        "name": name,
        "nim": nim,
        "location": location,
        "photoUrl": photoUrl,
        "timestamp": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      },
    );
  }

  Future<List<Map>> fetchData() async {
    final snapshot = await _dbRef.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      return data.entries.map(
        (e) {
          final key = e.key;
          final value = e.value as Map;
          return {
            "id": key,
            ...value,
          };
        },
      ).toList();
    }
    return [];
  }

  static Future<String> uploadImage(File imageFile) async {
    final url = Uri.parse('https://api.imgur.com/3/image');
    final request = http.MultipartRequest('POST', url)
      ..fields['type'] = 'file'
      ..headers['Authorization'] = 'Client-ID $clientId'
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final response = await request.send();
    final responseData = await http.Response.fromStream(response);

    if (response.statusCode == 200) {
      final data = jsonDecode(responseData.body);
      return data['data']['link'];
    } else {
      throw Exception('Failed to upload image to Imgur');
    }
  }

  Future<void> _uploadData() async {
    if (_nameController.text.isNotEmpty && _nimController.text.isNotEmpty) {
      try {
        // 1. Upload foto ke Imgur
        final photoUrl = await uploadImage(File(_photoPath!));

        // 2. Simpan data ke Firebase
        await saveData(
          _nameController.text,
          _nimController.text,
          _location!,
          photoUrl,
        );

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Upload Berhasil"),
              content: Text(
                  "Data berhasil disimpan. Silahkan kembali ke halaman utama."),
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
        Navigator.pushReplacementNamed(context, "/home");
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload data: $e")),
        );
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
          setState(() {
            _isCaptured = false;
            _photoPath = null;
          });
          return false; // Mencegah aplikasi keluar, hanya tutup tampilan detail.
        }
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.green[900],
              title: Text(
                'Isi Daftar Hadir',
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
                        Container(
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
                                onPressed: () {
                                  _captureLocationAndPhoto();
                                  _loadUserData();
                                  setState(() {
                                    _isCaptured = true;
                                  });
                                },
                                style: ButtonStyle(
                                  padding: WidgetStatePropertyAll(
                                      EdgeInsets.all(16.0)),
                                  shadowColor:
                                      WidgetStatePropertyAll(Colors.black),
                                  shape: MaterialStateProperty.all<
                                      RoundedRectangleBorder>(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30.0),
                                    ),
                                  ),
                                  backgroundColor:
                                      MaterialStateProperty.all<Color>(
                                          Colors.white),
                                  elevation:
                                      MaterialStateProperty.all<double>(2.0),
                                ),
                                icon: Icon(Icons.camera_alt),
                              ),
                              SizedBox(height: 75),
                            ],
                          ),
                        )
                      else
                        Center()
                    else if (_photoPath != null)
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 20.0),
                              child: Text(
                                "Isi Data Anda",
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Image.file(
                              File(_photoPath!),
                              width: MediaQuery.of(context).size.width * 0.7,
                              fit: BoxFit.cover,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () => setState(() {
                                    _isCaptured = false;
                                    _photoPath = null;
                                  }),
                                  style: ButtonStyle(
                                    padding: WidgetStatePropertyAll(
                                        EdgeInsets.all(8.0)),
                                    shape: MaterialStateProperty.all<
                                        RoundedRectangleBorder>(
                                      RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(30.0),
                                      ),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isCaptured = false;
                                      _photoPath = null;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                  ),
                                  child: Text(
                                    "Ambil Ulang",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900]),
                                  ),
                                ),
                                SizedBox(width: 20),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40.0,
                                vertical: 10.0,
                              ),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'Nama',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(
                                    height: 20,
                                  ),
                                  TextFormField(
                                    controller: _nimController,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'NIM',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your NIM';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _sendData,
                              child: Text(
                                'Kirim',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                minimumSize: Size(125, 50),
                                elevation: 5,
                                shadowColor: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_isProcessing || _isSending)
            Container(
              color: Colors.black45,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
