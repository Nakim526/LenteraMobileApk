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
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

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
  final List<Map<String, dynamic>> _uploadedFiles = [];
  final List<File> _selectedFiles = [];
  Map<dynamic, dynamic>? _task;
  DateTime? deadlineDate;
  bool _isLoading = false;
  bool _isFirst = true;
  bool _isAdmin = true;
  String? _category;
  String? _matkul;
  String? _taskId;
  File? _file;
  int? _selectedDateTime;
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
      final data = ModalRoute.of(context)!.settings.arguments as Map;

      setState(() {
        _isFirst = false;
        _matkul = data['matkul'];
      });

      if (data.keys.contains('key')) {
        setState(() {
          _task = data['data'];
          _taskId = data['data']['id'];
        });
        syncData();
      }
      if (data['users'] != null) {
        setState(() {
          _isAdmin = false;
        });
      }
      return;
    }
  }

  Future<String?> downloadFile(String url, String fileName) async {
    try {
      // Minta izin penyimpanan (hanya untuk Android)
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          print('Status izin penyimpanan: ${status.toString()}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status: ${status.toString()}'),
            ),
          );
          return null;
        }
      }

      Directory? directory = await getExternalStorageDirectory();
      String filePath = '${directory!.path}/$fileName';

      // Unduh file menggunakan dio
      Dio dio = Dio();
      await dio.download(url, filePath);

      return filePath; // Kembalikan path file yang diunduh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunduh file: $e'),
        ),
      );
      return null;
    }
  }

  Future<void> syncData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      setState(() {
        _titleController.text = _task!['title'];
        _descriptionController.text = _task!['description'];
        _category = _task!['type'];
        _selectedDateTime = _task!['deadline'];
      });
      if (_task!['files'] != null) {
        for (int i = 0; i < _task!['files'].length; i++) {
          String fileUrl = _task!['files'][i]['downloadUrl'];
          String fileName = _task!['files'][i]['name'];

          String? downloadedFilePath = await downloadFile(fileUrl, fileName);
          if (downloadedFilePath != null) {
            setState(() {
              _selectedFiles.add(File(downloadedFilePath));
            });
          }
        }
      }
    } finally {
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

  Icon getFileIcon(String filePath) {
    final mimeType = lookupMimeType(filePath);

    if (mimeType == null) {
      return Icon(Icons.insert_drive_file, color: Colors.grey);
    }
    if (mimeType.startsWith("image/")) {
      return Icon(Icons.image, size: 20, color: Colors.blue);
    } else if (mimeType.startsWith("video/")) {
      return Icon(Icons.video_file, size: 20, color: Colors.orange);
    } else if (mimeType.startsWith("audio/")) {
      return Icon(Icons.audiotrack, size: 20, color: Colors.green);
    } else if (mimeType == "application/pdf") {
      return Icon(Icons.picture_as_pdf, size: 20, color: Colors.red);
    } else if (mimeType.contains("word")) {
      return Icon(Icons.description, size: 20, color: Colors.blue);
    } else if (mimeType.contains("spreadsheet")) {
      return Icon(Icons.table_chart, size: 20, color: Colors.green);
    } else if (mimeType.contains("presentation")) {
      return Icon(Icons.slideshow, size: 20, color: Colors.orange);
    } else if (mimeType.contains("zip") || mimeType.contains("rar")) {
      return Icon(Icons.archive, size: 20, color: Colors.grey);
    } else if (mimeType == 'text/plain') {
      return Icon(Icons.text_snippet, size: 20, color: Colors.blueGrey);
    } else if (mimeType == 'application/json') {
      return Icon(Icons.code, size: 20, color: Colors.deepPurple);
    } else {
      return Icon(Icons.insert_drive_file, size: 20, color: Colors.grey);
    }
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
    if (_category == 'Pengumuman') {
      setState(() {
        _selectedDateTime = 0;
      });
    }
    if (_taskId != null) {
      await _dbRef.child('$_matkul/$_taskId').update({
        'title': _titleController.text.trim(),
        'type': _category,
        'description': _descriptionController.text.trim(),
        'files': _uploadedFiles,
        'deadline': _selectedDateTime ?? 0,
        'timestamp': ServerValue.timestamp,
      });
      return;
    }
    String? task = _dbRef.child(_matkul!).push().key;
    if (_isAdmin) {
      await _dbRef.child('$_matkul/$task').set({
        'title': _titleController.text.trim(),
        'type': _category,
        'description': _descriptionController.text.trim(),
        'files': _uploadedFiles,
        'deadline': _selectedDateTime ?? 0,
        'timestamp': ServerValue.timestamp,
        'id': task,
      });
    } else {
      await _dbRef.child('$_matkul/$task').set({
        'title': _titleController.text.trim(),
        'type': 'Postingan',
        'description': _descriptionController.text.trim(),
        'files': _uploadedFiles,
        'timestamp': ServerValue.timestamp,
        'id': task,
      });
    }
  }

  Future<void> uploadNewTask() async {
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
                  'name': file.path.split('/').last,
                  'mimeType': lookupMimeType(file.path),
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
                    _selectedDateTime = null;
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
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sedang mengunduh data, silahkan tunggu...'),
            ),
          );
          return false;
        }
        return true;
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              title: Text(
                _isAdmin ? 'Tugas' : 'Posting',
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
            body: ListView(
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
                                text: 'Judul',
                                style: TextStyle(
                                  color: Colors.grey[900],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: TextStyle(
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        _isAdmin
                            ? Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: DropdownButtonFormField(
                                      decoration: InputDecoration(
                                        labelText: "Kategori",
                                        labelStyle: TextStyle(
                                          color: Colors.grey[900],
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(4.0),
                                        ),
                                      ),
                                      value: _category == 'Postingan'
                                          ? null
                                          : _category,
                                      items: [
                                        DropdownMenuItem(
                                          value: "Pengumuman",
                                          child: Text(
                                            "Pengumuman",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: "Kehadiran",
                                          child: Text(
                                            "Kehadiran",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: "Tugas",
                                          child: Text(
                                            "Tugas",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _category = value;
                                        });
                                      },
                                      validator: (value) {
                                        if (_category == 'Postingan') {
                                          return null;
                                        }
                                        if (value == null) {
                                          return 'Please select an option';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 20),
                                ],
                              )
                            : SizedBox(height: 0),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 6,
                          decoration: InputDecoration(
                            alignLabelWithHint: true,
                            labelText: 'Deskripsi',
                            labelStyle: TextStyle(
                              color: Colors.grey[900],
                              fontSize: 16.0,
                              fontWeight: FontWeight.w400,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a description';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(color: Colors.grey[600]!),
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
                                            getFileIcon(
                                              _selectedFiles[index].path,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: GestureDetector(
                                                onTap: () async {
                                                  await OpenFile.open(
                                                    _selectedFiles[index].path,
                                                  );
                                                },
                                                child: Text(
                                                  _selectedFiles[index]
                                                      .path
                                                      .split('/')
                                                      .last,
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 14,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
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
                        SizedBox(height: 20),
                        _isAdmin
                            ? Column(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4.0),
                                      border:
                                          Border.all(color: Colors.grey[600]!),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          margin: const EdgeInsets.all(8.0),
                                          padding: EdgeInsets.zero,
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey[600]!),
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
                                                ? formatTimestamp(
                                                    _selectedDateTime!)
                                                : 'Batas Waktu',
                                            style: _selectedDateTime != null
                                                ? TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w400,
                                                    fontSize: 16,
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
                                  SizedBox(height: 20),
                                ],
                              )
                            : SizedBox(height: 0),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                await uploadNewTask();
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              elevation: 4,
                              backgroundColor: Colors.green[900],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                            ),
                            child: Text(
                              _isAdmin ? 'Tambah Tugas' : 'Tambah Postingan',
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
