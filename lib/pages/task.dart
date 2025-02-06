import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key});

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('tasks');
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<File> _selectedFiles = [];
  final List<Map<String, dynamic>> _uploadedFiles = [];
  int? _selectedDateTime;
  DateTime? deadlineDate;
  bool _isLoading = false;
  bool _isFirst = true;
  File? _file;
  String? _matkul;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isFirst) {
      // Pindahkan akses ModalRoute.of(context) ke sini
      final matkul = ModalRoute.of(context)!.settings.arguments as Map;

      setState(() {
        _isFirst = false;
        _matkul = matkul['matkul'];
      });

      syncData();
      return;
    }
  }

  Future<void> syncData() async {
    setState(() {
      _isLoading = true;
    });

    try {} finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        _file = File(result.files.single.path!);
        _selectedFiles.add(_file!);
      });
    }
  }

  IconData getFileIcon(String filePath) {
    final mimeType = lookupMimeType(filePath);

    if (mimeType == null) {
      return Icons.insert_drive_file;
    }

    if (mimeType.startsWith("image/")) return Icons.image;
    if (mimeType.startsWith("video/")) return Icons.video_library;
    if (mimeType.startsWith("audio/")) return Icons.audiotrack;
    if (mimeType == "application/pdf") return Icons.picture_as_pdf;
    if (mimeType.contains("word")) return Icons.description;
    if (mimeType.contains("spreadsheet")) return Icons.table_chart;
    if (mimeType.contains("presentation")) return Icons.slideshow;
    if (mimeType.contains("zip") || mimeType.contains("rar")) {
      return Icons.archive;
    }

    return Icons.insert_drive_file; // Default untuk file lainnya
  }

  Future<drive.DriveApi?> getDriveApi({bool forceSignIn = false}) async {
    try {
      GoogleSignInAccount? googleUser = _googleSignIn.currentUser;

      if (googleUser == null || forceSignIn) {
        googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return null; // User batal login
        }
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final auth.AuthClient authClient = auth.authenticatedClient(
        http.Client(),
        auth.AccessCredentials(
          auth.AccessToken(
            'Bearer',
            googleAuth.accessToken!,
            DateTime.now().add(Duration(hours: 1)).toUtc(),
          ),
          googleAuth.idToken,
          [drive.DriveApi.driveFileScope],
        ),
      );

      return drive.DriveApi(authClient);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
      return null;
    }
  }

  Future<String?> uploadFile(File file) async {
    final driveApi = await getDriveApi();

    final mimeType = lookupMimeType(file.path) ?? "application/octet-stream";

    final fileMetadata = drive.File(
      name: file.uri.pathSegments.last,
      mimeType: mimeType,
    );

    final media = drive.Media(
      http.ByteStream(Stream.value(await file.readAsBytes())),
      await file.length(),
    );

    final drive.File uploadedFile = await driveApi!.files.create(
      fileMetadata,
      uploadMedia: media,
    );

    return uploadedFile.id; // ID file yang diunggah
  }

  Future<Map<String, String>> getDriveFileLink(String fileId) async {
    final driveApi = await getDriveApi();

    // Mengubah izin file agar bisa diakses siapa saja
    await driveApi!.permissions.create(
      drive.Permission()
        ..type = "anyone"
        ..role = "reader",
      fileId,
    );

    final file = await driveApi.files
        .get(fileId, $fields: "webViewLink,webContentLink") as drive.File;
    return {
      "viewLink": file.webViewLink ?? "", // Link untuk melihat file
      "downloadLink": file.webContentLink ?? "", // Link untuk mengunduh file
    };
  }

  Future<void> sendToDatabase() async {
    String? task = _dbRef.child(_matkul!).push().key;
    await _dbRef.child('$_matkul/$task!').set({
      'title': _titleController.text,
      'description': _descriptionController.text,
      'files': _uploadedFiles,
      'deadline': _selectedDateTime,
      'timestamp': ServerValue.timestamp,
      'isCompleted': false,
      'id': task,
    });
  }

  Future<void> uploadNewTask() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        if (_selectedFiles.isNotEmpty) {
          for (int i = 0; i < _selectedFiles.length; i++) {
            File file = _selectedFiles[i];
            String? fileId = await uploadFile(file);
            if (fileId != null) {
              final fileLink = await getDriveFileLink(fileId);
              String? viewLink = fileLink["viewLink"];
              String? downloadLink = fileLink["downloadLink"];
              if (viewLink != null && downloadLink != null) {
                setState(() {
                  _uploadedFiles.add({
                    'viewUrl': viewLink,
                    'downloadUrl': downloadLink,
                    'name': file.path.split('/').last, // Simpan nama file
                  });
                });
              }
            }
          }
        }
        await sendToDatabase();

        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Upload Berhasil"),
              content: Text(
                "Tugas baru berhasil ditambahkan.",
              ),
              actions: [
                TextButton(
                  child: Text("OK"),
                  onPressed: () {
                    setState(() {
                      _formKey.currentState!.reset();
                      _selectedFiles.clear();
                      _uploadedFiles.clear();
                      _file = null;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    DateTime now = DateTime.now();

    // Pilih tanggal
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now, // Tidak bisa pilih sebelum hari ini
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return; // Jika batal memilih

    // Pilih waktu
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (pickedTime == null) return; // Jika batal memilih

    // Gabungkan tanggal dan waktu
    setState(() {
      deadlineDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _selectedDateTime = deadlineDate!.millisecondsSinceEpoch;
    });
  }

  String formatTimestamp(int timestamp) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tugas',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.green[900],
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            children: [
              Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          label: RichText(
                            text: TextSpan(
                              text: 'Tugas',
                              style: TextStyle(
                                  color: Colors.grey[900],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400),
                              children: [
                                TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Tugas harus diisi';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      TextFormField(
                        controller: _descriptionController,
                        scrollPadding: const EdgeInsets.all(16),
                        maxLines: 5,
                        decoration: const InputDecoration(
                          alignLabelWithHint: true,
                          labelText: 'Deskripsi',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: Colors.grey[600]!),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            pickFile();
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                            padding: const EdgeInsets.all(0),
                          ),
                          child: Column(
                            children: [
                              if (_selectedFiles.isNotEmpty)
                                Container(
                                  margin: EdgeInsets.all(8.0),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _selectedFiles.length,
                                    physics: NeverScrollableScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      return Container(
                                        width: double.infinity,
                                        height: 20,
                                        alignment: Alignment.centerLeft,
                                        decoration: BoxDecoration(),
                                        child: Row(
                                          children: [
                                            Icon(
                                              getFileIcon(
                                                  _selectedFiles[index].path),
                                              size: 20,
                                              color: Colors.red,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _selectedFiles[index]
                                                    .path
                                                    .split('/')
                                                    .last,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              child: Icon(
                                                Icons.close,
                                                size: 20,
                                                color: Colors.red,
                                              ),
                                              onTap: () {
                                                setState(() {
                                                  _selectedFiles
                                                      .removeAt(index);
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              Row(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.all(8.0),
                                    padding: EdgeInsets.zero,
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: Colors.grey[600]!),
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        pickFile();
                                      },
                                      icon: Icon(
                                        Icons.upload_file,
                                        size: 20,
                                        color: Colors.green[900],
                                      ),
                                      style: IconButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.zero,
                                        ),
                                        elevation: 0,
                                      ),
                                      constraints: BoxConstraints(),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        left: 4,
                                        right: 12,
                                      ),
                                      child: Text(
                                        'Unggah File',
                                        style: TextStyle(
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w400,
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: Colors.grey[600]!),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            _selectDateTime(context);
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            backgroundColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                            ),
                            padding: const EdgeInsets.all(0),
                          ),
                          child: Row(
                            children: [
                              Container(
                                margin: const EdgeInsets.all(8.0),
                                padding: EdgeInsets.zero,
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[600]!),
                                ),
                                child: IconButton(
                                  onPressed: () {
                                    _selectDateTime(context);
                                  },
                                  icon: Icon(
                                    Icons.calendar_month,
                                    size: 20,
                                    color: Colors.green[900],
                                  ),
                                  style: IconButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    elevation: 0,
                                  ),
                                  constraints: BoxConstraints(),
                                ),
                              ),
                              Container(
                                margin: EdgeInsets.only(
                                  left: 4,
                                  right: 12,
                                ),
                                child: Text(
                                  _selectedDateTime != null
                                      ? formatTimestamp(_selectedDateTime!)
                                      : 'Batas Akhir',
                                  style: _selectedDateTime != null
                                      ? TextStyle(
                                          color: Colors.black,
                                        )
                                      : TextStyle(
                                          color: Colors.grey[800],
                                          fontWeight: FontWeight.w400,
                                          fontSize: 16,
                                        ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await uploadNewTask();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            elevation: 4,
                            backgroundColor: Colors.green[900],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                          child: Text(
                            'Tambah Tugas',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
