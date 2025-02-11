import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class DataLogPage extends StatefulWidget {
  const DataLogPage({super.key});

  @override
  _DataLogPageState createState() => _DataLogPageState();
}

class _DataLogPageState extends State<DataLogPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("tasks");
  List<String> _selectedItems = [];
  List<String> _uidList = [];
  Map<dynamic, dynamic>? _data;
  String? keyId;
  String? _sort;
  String? _type;
  String? _titile;
  String? _matkul;
  String? _taskId;
  String? _postUser;
  bool _isSelect = false;
  bool _isLoading = false;
  bool _isOpen = false;
  bool _isProcessing = false;
  bool _isFirst = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
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
        _taskId = matkul['uid'];
        _postUser = matkul['postUser'];
        _type = matkul['type'];
        _titile = matkul['title'];
      });

      _loadData();
      return;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final roleRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        final role = await roleRef.child('role').get();

        if (role.exists && role.value == 'admin') {
          setState(() {
            _isAdmin = true;
            _sort = 'asc';
          });
          if (_sort == 'asc' || _sort == 'desc') {
            final snapshot = await _dbRef
                .child('$_matkul/$_taskId/$_type')
                .orderByChild('name')
                .get();
            print(snapshot.key);
            if (snapshot.exists) {
              // Konversi snapshot menjadi Map<String, dynamic>
              final rawData = Map<String, dynamic>.from(snapshot.value as Map);

              // Ubah Map menjadi List untuk sorting
              List<MapEntry<String, dynamic>> sortedList =
                  rawData.entries.toList();

              // Urutkan data berdasarkan "name"
              sortedList.sort((a, b) {
                return a.value['name']
                    .toString()
                    .compareTo(b.value['name'].toString());
              });

              // Jika DESC, balikkan urutannya
              if (_sort == 'desc') {
                sortedList = sortedList.reversed.toList();
              }

              // Ubah kembali menjadi Map
              final sortedData = Map<String, dynamic>.fromEntries(sortedList);

              setState(() {
                _data = sortedData;
                _uidList = _data!.keys.cast<String>().toList();
              });
            } else {
              setState(() {
                _data = null;
              });
            }
          } else if (_sort == 'baru' || _sort == 'lama') {
            final snapshot = await _dbRef
                .child('$_matkul/$_taskId/$_type')
                .orderByChild('timestamp')
                .get();
            if (snapshot.exists) {
              // Konversi snapshot menjadi Map<String, dynamic>
              final rawData = Map<String, dynamic>.from(snapshot.value as Map);

              // Ubah Map menjadi List untuk sorting
              List<MapEntry<String, dynamic>> sortedList =
                  rawData.entries.toList();

              // Urutkan data berdasarkan "timestamp"
              sortedList.sort((a, b) {
                return a.value['timestamp'].compareTo(b.value['timestamp']);
              });

              // Jika DESC, balikkan urutannya
              if (_sort == 'baru') {
                sortedList = sortedList.reversed.toList();
              }

              // Ubah kembali menjadi Map
              final sortedData = Map<String, dynamic>.fromEntries(sortedList);

              setState(() {
                _data = sortedData;
              });
            } else {
              setState(() {
                _data = null;
              });
            }
          }
        } else if (role.exists && role.value == 'user') {
          if (_postUser != null) {
            final userRef = FirebaseDatabase.instance
                .ref('users/${user.uid}/$_matkul/$_type/$_postUser');
            final postUser = await userRef.get();
            final data = Map.from(postUser.value as Map);
            String postUid = data['postUid'];
            final snapshot =
                await _dbRef.child('$_matkul/$_taskId/$_type').get();
            if (snapshot.exists) {
              setState(() {
                _isOpen = true;
                _data = Map.from(snapshot.value as Map);
                keyId = postUid;
              });
            }
          } else {
            Navigator.of(context).pop();
          }
        } else {
          setState(() {
            _data = null;
          });
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String formatTimestamp(int timestamp) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  Future<void> deleteData() async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      if (user != null) {
        if (_selectedItems.isEmpty && keyId == null) {
          return;
        } else {
          setState(() {
            _isLoading = true;
          });
          final postUser = FirebaseDatabase.instance.ref('users');
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  keyId != null
                      ? 'Hapus Riwayat'
                      : '${_selectedItems.length} item dipilih',
                ),
                content: Text('Anda yakin ingin menghapus riwayat ini?'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Batal'),
                    onPressed: () {
                      setState(() {
                        _isLoading = false;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  TextButton(
                    child: const Text('Hapus'),
                    onPressed: () async {
                      if (keyId != null) {
                        setState(() {
                          _selectedItems.clear();
                          _selectedItems.add(keyId!);
                          _postUser = null;
                          keyId = null;
                        });
                      }
                      for (int i = 0; i < _selectedItems.length; i++) {
                        String uid = _selectedItems[i];
                        String postId = _data![uid]['userPost'];
                        String userId = _data![uid]['user'];
                        postUser
                            .child('$userId/$_matkul/$_type/$postId')
                            .remove();
                        _dbRef.child('$_matkul/$_taskId/$_type/$uid').remove();
                      }
                      if (_isAdmin) {
                        setState(() {
                          _isOpen = false;
                          _isSelect = false;
                        });
                      }
                      Navigator.pop(context);
                      _loadData();
                    },
                  ),
                ],
              );
            },
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Terjadi kesalahan saat menghapus note: $e'),
      ));
    }
  }

  Icon getFileIcon(String mimeType) {
    if (mimeType.startsWith("image/")) {
      return Icon(
        Icons.image,
        size: 20,
        color: Colors.blue,
      );
    } else if (mimeType.startsWith("video/")) {
      return Icon(
        Icons.video_file,
        size: 20,
        color: Colors.orange,
      );
    } else if (mimeType.startsWith("audio/")) {
      return Icon(
        Icons.audiotrack,
        size: 20,
        color: Colors.green,
      );
    } else if (mimeType == "application/pdf") {
      return Icon(
        Icons.picture_as_pdf,
        size: 20,
        color: Colors.red,
      );
    } else if (mimeType.contains("word")) {
      return Icon(
        Icons.description,
        size: 20,
        color: Colors.blue,
      );
    } else if (mimeType.contains("spreadsheet")) {
      return Icon(
        Icons.table_chart,
        size: 20,
        color: Colors.green,
      );
    } else if (mimeType.contains("presentation")) {
      return Icon(
        Icons.slideshow,
        size: 20,
        color: Colors.orange,
      );
    } else if (mimeType.contains("zip") || mimeType.contains("rar")) {
      return Icon(
        Icons.archive,
        size: 20,
        color: Colors.grey,
      );
    } else if (mimeType == 'text/plain') {
      return Icon(
        Icons.text_snippet,
        size: 20,
        color: Colors.blueGrey,
      );
    } else if (mimeType == 'application/json') {
      return Icon(
        Icons.code,
        size: 20,
        color: Colors.deepPurple,
      );
    } else {
      return Icon(
        Icons.insert_drive_file,
        size: 20,
        color: Colors.grey,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_isAdmin) {
          return true;
        } else if (_isLoading) {
          setState(() {
            _isLoading = false;
          });
          return false;
        } else if (_isOpen && _isAdmin) {
          setState(() {
            _isOpen = false;
            keyId = null;
          });
          return false;
        } else if (_isSelect && _isAdmin) {
          setState(() {
            _isSelect = false;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green[900],
          title: Text(
            _isSelect
                ? '${_selectedItems.length.toString()} dipilih'
                : 'Riwayat',
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
                if (_isLoading) {
                  setState(() {
                    _isLoading = false;
                  });
                } else if (_isOpen && _isAdmin) {
                  setState(() {
                    _isOpen = false;
                    keyId = null;
                  });
                } else if (_isSelect && _isAdmin) {
                  setState(() {
                    _isSelect = false;
                  });
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          actions: [
            if (!_isOpen)
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: !_isSelect
                    ? PopupMenuButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) {
                          if (value == 'pilih') {
                            setState(() {
                              _isSelect = true;
                              _selectedItems = [];
                            });
                          } else if (value == 'refresh') {
                            setState(() {
                              _loadData();
                            });
                          } else if (value == 'asc') {
                            setState(() {
                              _sort = 'asc';
                              _loadData();
                            });
                          } else if (value == 'desc') {
                            setState(() {
                              _sort = 'desc';
                              _loadData();
                            });
                          } else if (value == 'terbaru') {
                            setState(() {
                              _sort = 'baru';
                              _loadData();
                            });
                          } else if (value == 'terlama') {
                            setState(() {
                              _sort = 'lama';
                              _loadData();
                            });
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'pilih',
                            child: Text("Pilih"),
                          ),
                          PopupMenuItem(
                            value: 'refresh',
                            child: Text("Refresh"),
                          ),
                          PopupMenuItem(
                            padding: EdgeInsets.all(0),
                            value: 'asc',
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: _sort == 'asc'
                                  ? Colors.grey.shade300
                                  : Colors.transparent,
                              child: Row(
                                children: [
                                  Text("Urutkan A-Z"),
                                  Spacer(),
                                  if (_sort == 'asc')
                                    Icon(
                                      Icons.done,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            padding: EdgeInsets.all(0),
                            value: 'desc',
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: _sort == 'desc'
                                  ? Colors.grey.shade300
                                  : Colors.transparent,
                              child: Row(
                                children: [
                                  Text("Urutkan Z-A"),
                                  Spacer(),
                                  if (_sort == 'desc')
                                    Icon(
                                      Icons.done,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            padding: EdgeInsets.all(0),
                            value: 'terbaru',
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: _sort == 'baru'
                                  ? Colors.grey.shade300
                                  : Colors.transparent,
                              child: Row(
                                children: [
                                  Text("Urutkan Terbaru"),
                                  Spacer(),
                                  if (_sort == 'baru')
                                    Icon(
                                      Icons.done,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            padding: EdgeInsets.all(0),
                            value: 'terlama',
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              color: _sort == 'lama'
                                  ? Colors.grey.shade300
                                  : Colors.transparent,
                              child: Row(
                                children: [
                                  Text("Urutkan Terlama"),
                                  Spacer(),
                                  if (_sort == 'lama')
                                    Icon(
                                      Icons.done,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                deleteData();
                              });
                            },
                            icon: Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (_selectedItems.length != _uidList.length) {
                                  _selectedItems.clear();
                                  _selectedItems.addAll(_uidList);
                                } else {
                                  _selectedItems.clear();
                                }
                              });
                            },
                            icon: Icon(
                              _selectedItems.length == _uidList.length
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              )
            else
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      deleteData();
                    });
                  },
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            if (!_isOpen && _data != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green,
                      Colors.lightGreenAccent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: _data!.length,
                  itemBuilder: (context, index) {
                    final key = _data!.keys.elementAt(index);
                    return Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 8.0,
                      ),
                      child: Material(
                        color: Colors.green.shade100,
                        elevation: 4.0,
                        clipBehavior: Clip.hardEdge,
                        borderRadius: BorderRadius.circular(16.0),
                        child: ListTile(
                            title: Text(
                              _data![key]['name'],
                              style: TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              formatTimestamp(
                                _data![key]['timestamp'],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            onLongPress: () {
                              setState(() {
                                _isSelect = true;
                                _selectedItems.add(key);
                              });
                            },
                            onTap: () {
                              if (_isSelect) {
                                setState(() {
                                  if (_selectedItems.contains(key)) {
                                    _selectedItems.remove(key);
                                  } else {
                                    _selectedItems.add(key);
                                  }
                                });
                              } else {
                                setState(() {
                                  _isOpen = true;
                                  _isProcessing = true;
                                  keyId = key;
                                });
                              }
                            },
                            trailing: _isSelect
                                ? Checkbox(
                                    shape: CircleBorder(),
                                    value: _selectedItems.contains(key),
                                    onChanged: (bool? selected) {
                                      setState(() {
                                        if (selected == true) {
                                          _selectedItems.add(key);
                                        } else {
                                          _selectedItems.remove(key);
                                        }
                                      });
                                    },
                                  )
                                : Icon(Icons.arrow_forward_ios)),
                      ),
                    );
                  },
                ),
              ),
            if (_isOpen && keyId != null)
              ListView(
                children: [
                  Container(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        if (_type == 'presences')
                          Stack(
                            children: [
                              if (_isProcessing)
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.4,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.4,
                                margin: EdgeInsets.only(bottom: 10.0),
                                child: Image.network(
                                  _data![keyId]['photoUrl'],
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    try {
                                      if (loadingProgress == null) {
                                        return child; // Tampilkan gambar
                                      } else {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                          setState(() {
                                            _isProcessing = false;
                                          });
                                        });
                                        return Container(
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      return child; // Tampilkan gambar
                                    } finally {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        setState(() {
                                          _isProcessing = false;
                                        });
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: EdgeInsets.only(
                                top: 30.0,
                                bottom: 16.0,
                                left: 16.0,
                                right: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.5),
                                    spreadRadius: 1,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _titile!,
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Text(
                                "Judul",
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: EdgeInsets.only(
                                top: 30.0,
                                bottom: 16.0,
                                left: 16.0,
                                right: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.5),
                                    spreadRadius: 1,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _data![keyId]['name'],
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Text(
                                "Nama",
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: EdgeInsets.only(
                                top: 30.0,
                                bottom: 16.0,
                                left: 16.0,
                                right: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.5),
                                    spreadRadius: 1,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _data![keyId]['nim'],
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Text(
                                "NIM",
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        _type == 'presences'
                            ? Stack(
                                children: [
                                  Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    padding: EdgeInsets.only(
                                      top: 30.0,
                                      bottom: 16.0,
                                      left: 16.0,
                                      right: 16.0,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(color: Colors.grey),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.5),
                                          spreadRadius: 1,
                                          blurRadius: 5,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _data![keyId]['presence'],
                                            style: TextStyle(
                                              fontSize: 16.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    top: 16,
                                    left: 16,
                                    child: Text(
                                      "Keterangan",
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Stack(
                                children: [],
                              ),
                        Stack(
                          children: [
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: EdgeInsets.only(
                                top: 30.0,
                                bottom: 16.0,
                                left: 16.0,
                                right: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.grey),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.5),
                                    spreadRadius: 1,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      formatTimestamp(
                                        _data![keyId]['timestamp'],
                                      ),
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Text(
                                "Diserahkan",
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_type == 'assignments')
                          Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: EdgeInsets.only(
                                  top: 30.0,
                                  bottom: 16.0,
                                  left: 16.0,
                                  right: 16.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.grey),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.5),
                                      spreadRadius: 1,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: List.generate(
                                      _data![keyId]['files'].length, (index) {
                                    return Container(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 4),
                                      margin: EdgeInsets.zero,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          getFileIcon(_data![keyId]['files']
                                              [index]['mimeType']),
                                          SizedBox(width: 8.0),
                                          TextButton(
                                            onPressed: () {
                                              launchUrl(
                                                Uri.parse(
                                                  _data![keyId]['files'][index]
                                                      ['viewUrl'],
                                                ),
                                              );
                                            },
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.all(0),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.zero,
                                              ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: Text(
                                              _data![keyId]['files'][index]
                                                  ['name'],
                                              style: TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Text(
                                  "Lampiran",
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        if (_data![keyId]['comment'] != null)
                          Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: EdgeInsets.only(
                                  top: 30.0,
                                  bottom: 16.0,
                                  left: 16.0,
                                  right: 16.0,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.grey),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.5),
                                      spreadRadius: 1,
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _data![keyId]['comment'],
                                        style: TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Text(
                                  "Komentar",
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: 24),
                        if (_type == 'presences')
                          Column(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (keyId != null) {
                                    final locationUrl =
                                        _data![keyId]['location'];
                                    if (locationUrl != null &&
                                        locationUrl.isNotEmpty) {
                                      launch(locationUrl); // Membuka URL lokasi
                                    } else {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "URL lokasi tidak tersedia")),
                                      );
                                    }
                                  }
                                },
                                label: Text(
                                  "Lihat Lokasi",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                icon: Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  minimumSize: Size(175, 50),
                                  elevation: 5,
                                  shadowColor: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 24),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            _isLoading
                ? Container(
                    color: Colors.black45,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  )
                : Container(),
            if (!_isOpen && _data == null && !_isLoading)
              Container(
                color: Colors.white,
                child: Center(
                  child: Text(
                    _type == 'presences'
                        ? "Not presence yet"
                        : "Not assignment yet",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
