import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AnswerPage extends StatefulWidget {
  const AnswerPage({super.key});

  @override
  State<AnswerPage> createState() => _AnswerPageState();
}

class _AnswerPageState extends State<AnswerPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('tasks');
  final _draggableController = DraggableScrollableController();
  final _nameController = TextEditingController();
  final _nimController = TextEditingController();
  final _emailController = TextEditingController();
  final _commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<Map<String, dynamic>> _uploadedFiles = [];
  final List<File> _selectedFiles = [];
  static const String clientId = "ca88e99d5b919db";
  Map<dynamic, dynamic>? _data;
  List<CameraDescription>? cameras;
  String? timeLeft;
  String? _attendance;
  String? _location;
  String? _photoPath;
  String? _matkul;
  String? _this;
  String? _key;
  File? _file;
  int? sent;
  bool _isExpanded = false;
  bool _isLoading = false;
  bool _isReady = false;
  bool _isAdmin = false;
  bool _isFirst = true;
  bool _isOpen = false;
  bool _isSent = false;
  bool _isEdit = true;
  bool photoError = false;
  bool fileError = false;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nimController.dispose();
    _emailController.dispose();
    _commentController.dispose();
    _draggableController.dispose();
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
        _matkul = matkul['name'];
        _key = matkul['key'];
        _data = matkul['data'];
        _isAdmin = matkul['user'];
      });

      _loadData();
      return;
    }
  }

  void expandSheet(bool isExpanded) {
    _draggableController.animateTo(
      isExpanded ? 0.125 : 1.0,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        _file = File(result.files.single.path!);
        _selectedFiles.add(_file!);
        fileError = false;
      });
    }
  }

  Future<String?> downloadFile(String url, String fileName) async {
    try {
      // Minta izin penyimpanan (hanya untuk Android)
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
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

  Future<void> syncData(String category, String? uid) async {
    final user = FirebaseAuth.instance.currentUser;
    final userRef =
        await FirebaseDatabase.instance.ref('users/${user!.uid}/email').get();
    final snapshot = userRef.value as String;
    String? type;
    if (category == 'Tugas') {
      type = 'assignments';
    } else if (category == 'Kehadiran') {
      type = 'presences';
    }
    if (type == null) return;
    if (uid == null) return;
    setState(() {
      _nameController.text = _data![type][uid]['name'];
      _nimController.text = _data![type][uid]['nim'];
      _emailController.text = snapshot;
      _commentController.text = _data![type][uid]['comment'] ?? '';
      sent = _data![type][uid]['timestamp'];
    });
    if (_isFirst) {
      if (_data!['type'] == 'Tugas') {
        if (_data![type][uid]['files'] != null) {
          for (int i = 0; i < _data![type][uid]['files'].length; i++) {
            String fileUrl = _data![type][uid]['files'][i]['downloadUrl'];
            String fileName = _data![type][uid]['files'][i]['name'];

            String? downloadedFilePath = await downloadFile(fileUrl, fileName);
            if (downloadedFilePath != null) {
              setState(() {
                _selectedFiles.add(File(downloadedFilePath));
              });
            }
          }
        }
      } else if (_data!['type'] == 'Kehadiran') {
        final photoPath = await downloadFile(_data![type][uid]['photoUrl'],
            'photo ${ServerValue.timestamp}.jpg');
        setState(() {
          _attendance = _data![type][uid]['presence'];
          _photoPath = photoPath;
        });
      }
      setState(() {
        timeLeft = getDifference(sent!, _data!['deadline'] ?? 0);
        _isFirst = false;
        _isSent = true;
        _isEdit = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // Minta izin penyimpanan (hanya untuk Android)
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pastikan izin penyimpanan diberikan.'),
            ),
          );
        }
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef =
            FirebaseDatabase.instance.ref('users/${user.uid}/$_matkul');
        final announcementRef = await userRef.child('announcements').get();
        final assignmentRef = await userRef.child('assignments').get();
        final presenceRef = await userRef.child('presences').get();
        final snapshot = await _dbRef.child(_matkul!).child(_key!).get();

        if (snapshot.exists) {
          setState(() {
            _data = Map.from(snapshot.value as Map);
          });
          if (_data!['type'] == 'Pengumuman') {
            if (announcementRef.exists) {
              final announcements = Map.from(announcementRef.value as Map);

              for (var uid in announcements.keys) {
                if (announcements[uid]['status'] != null &&
                    announcements[uid]['taskUid'] == _key) {
                  return;
                }
              }
            }
            final refUser = FirebaseDatabase.instance.ref('users/${user.uid}');
            String? userId = refUser.child('$_matkul/announcements').push().key;
            String? postId =
                _dbRef.child('$_matkul/$_key/announcements').push().key;
            await _dbRef.child('$_matkul/$_key/announcements/$postId').set({
              'timestamp': ServerValue.timestamp,
              'user': user.uid,
              'userPost': userId,
            });
            await refUser.child('$_matkul/announcements/$userId').set({
              'taskUid': _key,
              'postUid': postId,
              'status': "Selesai",
            });
          } else if (_data!['type'] == 'Tugas') {
            if (assignmentRef.exists) {
              final assignments = Map.from(assignmentRef.value as Map);

              for (var uid in assignments.keys) {
                if (assignments[uid]['status'] != null &&
                    assignments[uid]['taskUid'] == _key) {
                  setState(() {
                    _isFirst = true;
                    _this = assignments[uid]['postUid'];
                  });
                  await syncData(_data!['type'], _this);
                  return;
                }
              }
            }
          } else if (_data!['type'] == 'Kehadiran') {
            if (presenceRef.exists) {
              final presences = Map.from(presenceRef.value as Map);

              for (var uid in presences.keys) {
                if (presences[uid]['status'] != null &&
                    presences[uid]['taskUid'] == _key) {
                  setState(() {
                    _isFirst = true;
                    _this = presences[uid]['postUid'];
                  });
                  await syncData(_data!['type'], _this);
                  return;
                }
              }
            }
          }
          await _loadUserData();
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');
      final userFill = await userRef.get();
      if (userFill.exists) {
        final userData = Map<String, dynamic>.from(userFill.value as Map);
        setState(() {
          _nameController.text = userData['name'] ?? '';
          _nimController.text = userData['nim'] ?? '';
          _emailController.text = userData['email'];
        });
      }
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
      throw Exception('Failed to upload image: ${response.statusCode}');
    }
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

  Future<void> sendAssignment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String status = "Selesai";
      final refUser = FirebaseDatabase.instance.ref('users/${user.uid}');
      final deadline = await _dbRef.child('$_matkul/$_key/deadline').get();
      if (deadline.exists) {
        final deadlineTimestamp = deadline.value as int;
        if (deadlineTimestamp < DateTime.now().millisecondsSinceEpoch) {
          status = "Terlambat";
        }
      }
      if (_isEdit && _isSent) {
        await _dbRef.child('$_matkul/$_key/assignments/$_this').update({
          "name": _nameController.text,
          "nim": _nimController.text,
          "email": _emailController.text,
          "comment": _commentController.text,
          "files": _uploadedFiles,
          "timestamp": ServerValue.timestamp,
        });
        return;
      }
      String? userId = refUser.child('$_matkul/assignments').push().key;
      String? postId = _dbRef.child('$_matkul/$_key/assignments').push().key;
      await _dbRef.child('$_matkul/$_key/assignments/$postId').set({
        'name': _nameController.text.trim(),
        'nim': _nimController.text.trim(),
        'email': _emailController.text.trim(),
        'comment': _commentController.text.trim(),
        'files': _uploadedFiles,
        'timestamp': ServerValue.timestamp,
        'user': user.uid,
        'userPost': userId,
      });
      await refUser.child('$_matkul/assignments/$userId').set({
        'taskUid': _key,
        'postUid': postId,
        'status': status,
      });
    }
  }

  Future<void> sendPresence(String photoUrl) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String status = "Selesai";
      final refUser = FirebaseDatabase.instance.ref('users/${user.uid}');
      final deadline = await _dbRef.child('$_matkul/$_key/deadline').get();
      if (deadline.exists) {
        final deadlineTimestamp = deadline.value as int;
        if (deadlineTimestamp < DateTime.now().millisecondsSinceEpoch) {
          status = "Terlambat";
        }
      }
      if (_isEdit && _isSent) {
        await _dbRef.child('$_matkul/$_key/presences/$_this').update({
          "name": _nameController.text,
          "nim": _nimController.text,
          "comment": _commentController.text,
          "presence": _attendance,
          "location": _location,
          "photoUrl": photoUrl,
          "timestamp": ServerValue.timestamp,
        });
        return;
      }
      String? userId = refUser.child('$_matkul/presences').push().key;
      String? postId = _dbRef.child('$_matkul/$_key/presences').push().key;
      await _dbRef.child('$_matkul/$_key/presences/$postId').set({
        "name": _nameController.text,
        "nim": _nimController.text,
        "comment": _commentController.text,
        "presence": _attendance,
        "location": _location,
        "photoUrl": photoUrl,
        "timestamp": ServerValue.timestamp,
        "user": user.uid,
        "userPost": userId,
      });
      await refUser.child('$_matkul/presences/$userId').set({
        "taskUid": _key,
        "postUid": postId,
        "status": status,
      });
    }
  }

  Future<void> uploadNewTask() async {
    setState(() {
      _isLoading = true;
    });
    try {
      String? photoUrl;
      if (_isEdit && _isSent) {
        if (_selectedFiles.isNotEmpty) {
          setState(() {
            _uploadedFiles.clear();
          });
        }
      }
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
      } else if (_photoPath != null) {
        photoUrl = await uploadImage(File(_photoPath!));
      }
      if (_data!['type'] == 'Tugas') {
        await sendAssignment();
      } else if (_data!['type'] == 'Kehadiran') {
        await sendPresence(photoUrl!);
      }
      await showDialog(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Upload Berhasil"),
            content: Text("Data anda berhasil dikirimkan"),
            actions: [
              TextButton(
                child: Text("OK"),
                onPressed: () async {
                  setState(() {
                    _selectedFiles.clear();
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
        ),
      );
      print(e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Icon getFileIcon(String mimeType, bool isAnswer) {
    if (mimeType.startsWith("image/")) {
      return Icon(
        Icons.image,
        size: isAnswer ? 20 : 32,
        color: Colors.blue,
      );
    } else if (mimeType.startsWith("video/")) {
      return Icon(
        Icons.video_file,
        size: isAnswer ? 20 : 32,
        color: Colors.orange,
      );
    } else if (mimeType.startsWith("audio/")) {
      return Icon(
        Icons.audiotrack,
        size: isAnswer ? 20 : 32,
        color: Colors.green,
      );
    } else if (mimeType == "application/pdf") {
      return Icon(
        Icons.picture_as_pdf,
        size: isAnswer ? 20 : 32,
        color: Colors.red,
      );
    } else if (mimeType.contains("word")) {
      return Icon(
        Icons.description,
        size: isAnswer ? 20 : 32,
        color: Colors.blue,
      );
    } else if (mimeType.contains("spreadsheet")) {
      return Icon(
        Icons.table_chart,
        size: isAnswer ? 20 : 32,
        color: Colors.green,
      );
    } else if (mimeType.contains("presentation")) {
      return Icon(
        Icons.slideshow,
        size: isAnswer ? 20 : 32,
        color: Colors.orange,
      );
    } else if (mimeType.contains("zip") || mimeType.contains("rar")) {
      return Icon(
        Icons.archive,
        size: isAnswer ? 20 : 32,
        color: Colors.grey,
      );
    } else if (mimeType == 'text/plain') {
      return Icon(
        Icons.text_snippet,
        size: isAnswer ? 20 : 32,
        color: Colors.blueGrey,
      );
    } else if (mimeType == 'application/json') {
      return Icon(
        Icons.code,
        size: isAnswer ? 20 : 32,
        color: Colors.deepPurple,
      );
    } else {
      return Icon(
        Icons.insert_drive_file,
        size: isAnswer ? 20 : 32,
        color: Colors.grey,
      );
    }
  }

  String formatTimestamp(int? timestamp) {
    if (timestamp == 0) return 'Tidak ada batas waktu';
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp!);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  Future<void> getPhotoPath(Object? object) async {
    final result =
        await Navigator.pushNamed(context, '/presence', arguments: object)
            as Map?;
    if (result == null) return;
    setState(() {
      photoError = false;
      _photoPath = result['photo'];
      _location = result['location'];
    });
  }

  String getDifference(int start, int? end) {
    if (end == 0) return '-';
    Duration difference = Duration(milliseconds: end! - start);
    int days = difference.inDays;
    int hours = difference.inHours - (days * 24);
    int minutes = difference.inMinutes - (days * 24 * 60) - (hours * 60);
    int seconds = difference.inSeconds -
        (days * 24 * 60 * 60) -
        (hours * 60 * 60) -
        (minutes * 60);
    return '$days hari $hours jam $minutes menit $seconds detik';
  }

  Future<String?> userCheck(String idKey, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await _dbRef.child('$_matkul/$idKey/$type').get();
      if (snapshot.exists) {
        final outerMap = Map.from(snapshot.value as Map);
        for (var key in outerMap.keys) {
          if (outerMap[key]['user'] == user.uid) {
            return key;
          }
        }
      }
    }
    return null;
  }

  Future<void> _navigateAndRefresh(String routeName, Object? object) async {
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false,
        arguments: object);
  }

  Future<void> _logout(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String status = 'Offline';
    FirebaseDatabase.instance.ref("users/${user.uid}").update({
      "status": status,
      "lastSeen": DateTime.now().millisecondsSinceEpoch,
    });

    // Hapus status login dari SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Navigasi kembali ke halaman login
    Navigator.pushNamedAndRemoveUntil(context, '/sign-in', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double statusBarHeight = MediaQuery.of(context).padding.top;
    double appBarHeight = kToolbarHeight;
    double availableHeight = screenHeight - statusBarHeight - appBarHeight;
    return Stack(
      children: [
        Scaffold(
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: 125,
                  child: DrawerHeader(
                    decoration: BoxDecoration(
                      color: Colors.green[900],
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          "lib/assets/logo UINAM.png",
                          width: 50,
                          height: 50,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Lentera Mobile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Crestwood',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.home),
                  title: Text('Home'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateAndRefresh('/home', null);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateAndRefresh('/profile', null);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.description),
                  title: Text('Notes'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateAndRefresh('/notes', null);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.chat),
                  title: Text('Chat'),
                  onTap: () {
                    Navigator.pop(context);
                    _navigateAndRefresh('/chat', null);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign Out'),
                  onTap: () {
                    Navigator.pop(context);
                    _logout(context);
                  },
                ),
              ],
            ),
          ),
          appBar: AppBar(
            title: Text(
              _data!['type'],
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
                  if (_isLoading) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Tidak dapat kembali saat sedang memuat...'),
                      ),
                    );
                  } else if (_isOpen) {
                    setState(() {
                      _isOpen = false;
                    });
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
          body: Stack(
            children: [
              Container(
                child: ListView(
                  children: [
                    Container(
                      margin: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          IntrinsicHeight(
                            child: Container(
                              constraints: BoxConstraints(
                                minHeight: 250,
                              ),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    width: 4.0,
                                    color: Colors.black12,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    color: Colors.green[900],
                                    padding: EdgeInsets.all(16.0),
                                    width: double.infinity,
                                    child: Text(
                                      _data!['title'],
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(height: 16.0),
                                  Expanded(
                                    child: Container(
                                      color: Colors.green.shade100,
                                      width: double.infinity,
                                      padding: EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.description,
                                                size: 28.0,
                                              ),
                                              SizedBox(width: 8.0),
                                              Text(
                                                'Deskripsi:',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 16.0),
                                          Text(
                                            _data!['description'],
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_data!['type'] == 'Tugas' ||
                                      _data!['type'] == 'Kehadiran')
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      width: double.infinity,
                                      color: Colors.green.shade100,
                                      child: Text(
                                        'Batas Waktu: ${formatTimestamp(
                                          _data!['deadline'] ?? 0,
                                        )}',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(
                              top: 24.0,
                              bottom: 12.0,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link,
                                  size: 28.0,
                                ),
                                SizedBox(width: 8.0),
                                Text(
                                  'Lampiran:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ListView.builder(
                            physics: NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: _data!['files'] == null
                                ? 0
                                : _data!['files'].length,
                            itemBuilder: (context, index) {
                              return Container(
                                margin: EdgeInsets.only(bottom: 8.0),
                                child: ElevatedButton(
                                  onPressed: () {
                                    launchUrl(
                                      Uri.parse(
                                        _data!['files'][index]['downloadUrl'],
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    padding: EdgeInsets.all(8.0),
                                  ),
                                  child: Row(
                                    children: [
                                      getFileIcon(
                                          _data!['files'][index]['mimeType'],
                                          false),
                                      SizedBox(width: 8.0),
                                      Expanded(
                                        child: Container(
                                          child: Text(
                                            _data!['files'][index]['name'],
                                            style: TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          if ((_data!['type'] == 'Tugas' ||
                                  _data!['type'] == 'Kehadiran') &&
                              _isAdmin)
                            Container(
                              margin: EdgeInsets.symmetric(
                                vertical: 30,
                              ),
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  String type = _data!['type'];
                                  if (type == 'Tugas') {
                                    type = 'assignments';
                                  } else if (type == 'Kehadiran') {
                                    type = 'presences';
                                  }
                                  await Navigator.pushNamed(
                                    context,
                                    '/datalog',
                                    arguments: {
                                      'uid': _key,
                                      'type': type,
                                      'matkul': _matkul,
                                      'title': _data!['title'],
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 4.0,
                                  backgroundColor: Colors.green[900],
                                  padding: EdgeInsets.symmetric(
                                    vertical: 12.0,
                                    // horizontal: 8.0,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.search,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8.0),
                                    Text(
                                      'Lihat Riwayat',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8.0),
                                  ],
                                ),
                              ),
                            )
                          else if ((_data!['type'] == 'Tugas' ||
                                  _data!['type'] == 'Kehadiran') &&
                              !_isAdmin)
                            SizedBox(height: 60.0),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if ((_data!['type'] == 'Tugas' ||
                      _data!['type'] == 'Kehadiran') &&
                  !_isAdmin)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: availableHeight,
                    width: double.infinity,
                    child: DraggableScrollableSheet(
                      controller: _draggableController,
                      initialChildSize: 0.125,
                      minChildSize: 0.125,
                      maxChildSize: 1.0,
                      builder: (context, scrollController) {
                        return Form(
                          key: _formKey,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(32.0),
                                topRight: Radius.circular(32.0),
                              ),
                              color: Colors.grey.shade100,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey[400]!,
                                  blurRadius: 4.0,
                                  spreadRadius: 2.0,
                                ),
                              ],
                            ),
                            child: ListView(
                              controller: scrollController,
                              padding: EdgeInsets.symmetric(horizontal: 24.0),
                              primary: false,
                              shrinkWrap: true,
                              children: [
                                Column(
                                  children: [
                                    IconButton(
                                      onPressed: () {
                                        expandSheet(_isExpanded);
                                        setState(() {
                                          _isExpanded = !_isExpanded;
                                        });
                                      },
                                      color: Colors.grey[600],
                                      padding: EdgeInsets.zero,
                                      icon: Icon(
                                        _isExpanded
                                            ? Icons.keyboard_arrow_down
                                            : Icons.keyboard_arrow_up,
                                      ),
                                      style: IconButton.styleFrom(
                                        // padding: EdgeInsets.zero,
                                        minimumSize:
                                            Size(double.infinity, 48.0),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Divider(
                                            color: Colors.grey[400],
                                            thickness: 4.0,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0),
                                          child: Text(
                                            _isExpanded
                                                ? 'Geser ke bawah'
                                                : 'Geser ke atas',
                                            style: TextStyle(
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(
                                            color: Colors.grey[400],
                                            thickness: 4.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  margin: EdgeInsets.only(
                                    top: 12.0,
                                    bottom: 8.0,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.question_answer,
                                        size: 28.0,
                                      ),
                                      SizedBox(width: 8.0),
                                      Text(
                                        'Jawaban Anda:',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8.0),
                                if (!_isEdit)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16.0,
                                          horizontal: 8.0,
                                        ),
                                        width: double.infinity,
                                        color: Colors.green[600],
                                        child: Text(
                                          'Batas Waktu',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16.0,
                                          horizontal: 8.0,
                                        ),
                                        width: double.infinity,
                                        color: Colors.green.shade100,
                                        child: Text(
                                          formatTimestamp(_data!['deadline']),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16.0,
                                          horizontal: 8.0,
                                        ),
                                        width: double.infinity,
                                        color: Colors.green[600],
                                        child: Text(
                                          'Dikumpulkan',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16.0,
                                          horizontal: 8.0,
                                        ),
                                        width: double.infinity,
                                        color: Colors.green.shade100,
                                        child: Text(
                                          formatTimestamp(sent!),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16.0,
                                          horizontal: 8.0,
                                        ),
                                        width: double.infinity,
                                        color: Colors.green[600],
                                        child: Text(
                                          'Sisa Waktu',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16.0,
                                          horizontal: 8.0,
                                        ),
                                        width: double.infinity,
                                        color: Colors.green.shade100,
                                        child: Text(
                                          timeLeft!,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 24.0),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            setState(() {
                                              _isEdit = true;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            elevation: 4.0,
                                            backgroundColor: _isSent
                                                ? Colors.grey[200]
                                                : Colors.green[900],
                                            padding: EdgeInsets.all(12.0),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              side: BorderSide(
                                                color: Colors.green[900]!,
                                                width: 4.0,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            'Edit Pengumpulan',
                                            style: TextStyle(
                                              color: _isSent
                                                  ? Colors.green[900]
                                                  : Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 12.0),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            String type = _data!['type'];
                                            if (type == 'Tugas') {
                                              type = 'assignments';
                                            } else if (type == 'Kehadiran') {
                                              type = 'presences';
                                            }
                                            final set =
                                                await userCheck(_key!, type);
                                            await Navigator.pushNamed(
                                              context,
                                              '/datalog',
                                              arguments: {
                                                'uid': _key,
                                                'type': type,
                                                'matkul': _matkul!,
                                                'title': _data!['title'],
                                                'postUser': _data![type][set]
                                                    ['userPost'],
                                              },
                                            );
                                            _loadData();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            elevation: 4.0,
                                            backgroundColor: Colors.green[900],
                                            padding: EdgeInsets.symmetric(
                                              vertical: 12.0,
                                              horizontal: 8.0,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.search,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 8.0),
                                              Text(
                                                'Lihat Riwayat',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              SizedBox(width: 8.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    children: [
                                      TextFormField(
                                        controller: _nameController,
                                        enabled: false,
                                        decoration: InputDecoration(
                                          disabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.grey[600]!,
                                            ),
                                          ),
                                          labelText: 'Nama',
                                          labelStyle: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      TextFormField(
                                        controller: _nimController,
                                        enabled: false,
                                        decoration: InputDecoration(
                                          disabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.grey[600]!,
                                            ),
                                          ),
                                          labelText: 'NIM',
                                          labelStyle: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      TextFormField(
                                        controller: _emailController,
                                        enabled: false,
                                        decoration: InputDecoration(
                                          disabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.grey[600]!,
                                            ),
                                          ),
                                          labelText: 'Email',
                                          labelStyle: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(4.0),
                                          border: Border.all(
                                              color: photoError || fileError
                                                  ? Colors.red[900]!
                                                  : Colors.grey[600]!),
                                        ),
                                        child: Column(
                                          children: [
                                            if (_selectedFiles.isNotEmpty)
                                              Container(
                                                margin: EdgeInsets.all(8.0),
                                                child: ListView.builder(
                                                  shrinkWrap: true,
                                                  itemCount:
                                                      _selectedFiles.length,
                                                  physics:
                                                      NeverScrollableScrollPhysics(),
                                                  itemBuilder:
                                                      (context, index) {
                                                    return Container(
                                                      width: double.infinity,
                                                      height: 20,
                                                      alignment:
                                                          Alignment.centerLeft,
                                                      decoration:
                                                          BoxDecoration(),
                                                      child: Row(
                                                        children: [
                                                          getFileIcon(
                                                            lookupMimeType(
                                                                    _selectedFiles[
                                                                            index]
                                                                        .path)
                                                                .toString(),
                                                            true,
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child:
                                                                GestureDetector(
                                                              onTap: () async {
                                                                await OpenFile
                                                                    .open(
                                                                  _selectedFiles[
                                                                          index]
                                                                      .path,
                                                                );
                                                              },
                                                              child: Text(
                                                                _selectedFiles[
                                                                        index]
                                                                    .path
                                                                    .split('/')
                                                                    .last,
                                                                style:
                                                                    TextStyle(
                                                                  color: Colors
                                                                          .grey[
                                                                      600],
                                                                  fontSize: 14,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          GestureDetector(
                                                            child: Icon(
                                                              Icons.close,
                                                              size: 20,
                                                              color: Colors
                                                                  .red[900],
                                                            ),
                                                            onTap: () {
                                                              setState(() {
                                                                _selectedFiles
                                                                    .removeAt(
                                                                        index);
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
                                                  margin: EdgeInsets.all(8.0),
                                                  padding: EdgeInsets.zero,
                                                  width: 40,
                                                  height: 40,
                                                  child: ElevatedButton(
                                                    onPressed: () async {
                                                      _data!['type'] == 'Tugas'
                                                          ? pickFile()
                                                          : _photoPath == null
                                                              ? getPhotoPath({
                                                                  'name':
                                                                      _matkul
                                                                })
                                                              : await OpenFile
                                                                  .open(
                                                                  _photoPath,
                                                                );
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          Colors.grey.shade200,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.all(
                                                          Radius.circular(4.0),
                                                        ),
                                                        side: BorderSide(
                                                          color:
                                                              Colors.grey[600]!,
                                                        ),
                                                      ),
                                                      elevation: 1.5,
                                                      padding: EdgeInsets.zero,
                                                    ),
                                                    child: Icon(
                                                      _data!['type'] == 'Tugas'
                                                          ? Icons.upload_file
                                                          : _photoPath == null
                                                              ? Icons.camera_alt
                                                              : Icons
                                                                  .remove_red_eye,
                                                      size: 20,
                                                      color: Colors.green[900],
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Container(
                                                    margin: EdgeInsets.only(
                                                      left: 4,
                                                      right: 12,
                                                    ),
                                                    child: Text(
                                                      _data!['type'] == 'Tugas'
                                                          ? 'Unggah File'
                                                          : _photoPath == null
                                                              ? 'Ambil Foto'
                                                              : 'Lihat Foto',
                                                      style: TextStyle(
                                                        color: Colors.grey[800],
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        fontSize: 16,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                                if (_photoPath != null)
                                                  IconButton(
                                                    icon: Icon(Icons.delete),
                                                    onPressed: () {
                                                      setState(() {
                                                        _photoPath = null;
                                                      });
                                                    },
                                                    style: IconButton.styleFrom(
                                                      padding:
                                                          EdgeInsets.all(8.0),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          30.0,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (photoError)
                                        Container(
                                          width: double.infinity,
                                          margin: EdgeInsets.only(left: 12.5),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(height: 3.0),
                                              Text(
                                                'Please take your photo',
                                                style: TextStyle(
                                                  color: Colors.red[900],
                                                  fontWeight: FontWeight.w400,
                                                  fontSize: 12,
                                                ),
                                                // textAlign: TextAlign.left,
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (fileError)
                                        Container(
                                          width: double.infinity,
                                          margin: EdgeInsets.only(left: 12.5),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(height: 3.0),
                                              Text(
                                                'Please upload your file',
                                                style: TextStyle(
                                                  color: Colors.red[900],
                                                  fontWeight: FontWeight.w400,
                                                  fontSize: 12,
                                                ),
                                                // textAlign: TextAlign.left,
                                              ),
                                            ],
                                          ),
                                        ),
                                      SizedBox(height: 16.0),
                                      if (_data!['type'] == 'Kehadiran')
                                        Column(
                                          children: [
                                            DropdownButtonFormField<String>(
                                              decoration: InputDecoration(
                                                labelText: "Keterangan",
                                                labelStyle: TextStyle(
                                                  color: Colors.grey[800],
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          5.0),
                                                ),
                                              ),
                                              value: _attendance, // Nilai awal
                                              items: [
                                                DropdownMenuItem(
                                                  value: "Hadir",
                                                  child: Text(
                                                    "Hadir",
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: "Sakit",
                                                  child: Text(
                                                    "Sakit",
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: "Izin",
                                                  child: Text(
                                                    "Izin",
                                                    style: TextStyle(
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              onChanged: (value) {
                                                setState(() {
                                                  _attendance = value;
                                                });
                                              },
                                              validator: (value) {
                                                if (value == null) {
                                                  return 'Please select an option';
                                                }
                                                return null;
                                              },
                                            ),
                                            SizedBox(height: 16),
                                          ],
                                        ),
                                      TextFormField(
                                        controller: _commentController,
                                        maxLines: 4,
                                        decoration: InputDecoration(
                                          alignLabelWithHint: true,
                                          hintText: 'Tulis komentar...',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                          contentPadding: EdgeInsets.all(12.0),
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      if (_isSent)
                                        Container(
                                          margin: EdgeInsets.only(
                                            top: 24.0,
                                          ),
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () async {
                                              setState(() {
                                                _isEdit = false;
                                              });
                                            },
                                            style: ElevatedButton.styleFrom(
                                              elevation: 4.0,
                                              backgroundColor: Colors.grey[200],
                                              padding: EdgeInsets.all(12.0),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                                side: BorderSide(
                                                  color: Colors.green[900]!,
                                                  width: 4.0,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              'Batalkan',
                                              style: TextStyle(
                                                color: Colors.green[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Container(
                                        margin: EdgeInsets.only(
                                          top: _isSent ? 12.0 : 24.0,
                                          bottom: 24.0,
                                        ),
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            if (_data!['type'] == 'Kehadiran') {
                                              if (_photoPath == null) {
                                                setState(() {
                                                  photoError = true;
                                                });
                                              }
                                              if (_location == null) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Lokasi belum ditemukan! Silahkan ambil ulang foto!',
                                                    ),
                                                  ),
                                                );
                                              }
                                              if (_photoPath != null &&
                                                  (_location != null)) {
                                                setState(() {
                                                  _isReady = true;
                                                });
                                              }
                                            } else if (_data!['type'] ==
                                                'Tugas') {
                                              if (_selectedFiles.isEmpty) {
                                                setState(() {
                                                  fileError = true;
                                                });
                                              } else {
                                                setState(() {
                                                  _isReady = true;
                                                });
                                              }
                                            }
                                            if (_formKey.currentState!
                                                .validate()) {
                                              if (_isReady) {
                                                await uploadNewTask();
                                                _loadData();
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            elevation: 4.0,
                                            backgroundColor: Colors.green[900],
                                            padding: EdgeInsets.all(12.0),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8.0),
                                              side: BorderSide(
                                                color: Colors.green[900]!,
                                                width: 4.0,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            'Serahkan Tugas',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
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
    );
  }
}
