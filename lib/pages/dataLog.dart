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
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("uploads");
  List<String> _selectedItems = [];
  List<String> _uidList = [];
  List<dynamic> _temp = [];
  Map<dynamic, dynamic>? _data;
  String? _sort;
  String? keyId;
  bool _isSelect = false;
  bool _isLoading = false;
  bool _isOpen = false;
  bool _isProcessing = false;

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DatabaseReference userRef =
            FirebaseDatabase.instance.ref('users/${user.uid}');

        final role = await userRef.child('role').get();
        if (role.exists && role.value == 'admin') {
          if (_sort == 'asc' || _sort == 'desc') {
            final snapshot = await _dbRef.orderByChild('name').get();
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
            final snapshot = await _dbRef.orderByChild('timestamp').get();
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
          final postRef = await userRef.child('attendance').get();
          if (postRef.exists) {
            final uploadsMap = Map<String, dynamic>.from(postRef.value as Map);
            final List<String> uploadsList =
                uploadsMap.keys.map((key) => key.toString()).toList();

            for (int i = 0; i < uploadsList.length; i++) {
              final uploadId = uploadsList[i];
              final uploadRef =
                  await userRef.child('attendance/$uploadId').get();

              if (uploadRef.exists) {
                final uploadIds =
                    Map<String, dynamic>.from(uploadRef.value as Map);

                _temp.add(uploadIds['uid']);
              }
            }

            // Cek apakah _temp memiliki UID yang sudah tersimpan
            if (_temp.isNotEmpty) {
              if (_sort == 'asc' || _sort == 'desc') {
                final snapshot = await _dbRef.orderByChild('name').get();
                if (snapshot.exists && snapshot.value != null) {
                  // Konversi snapshot menjadi Map<String, dynamic>
                  final rawData =
                      Map<String, dynamic>.from(snapshot.value as Map);

                  // Filter hanya data dengan UID yang ada di _temp
                  List<MapEntry<String, dynamic>> filteredData = rawData.entries
                      .where((entry) => _temp.contains(entry.value['uid']))
                      .toList();

                  // Urutkan data berdasarkan "name"
                  filteredData.sort((a, b) =>
                      (a.value['name']?.toString() ?? '')
                          .compareTo(b.value['name']?.toString() ?? ''));

                  // Jika DESC, balikkan urutannya
                  if (_sort == 'desc') {
                    filteredData = filteredData.reversed.toList();
                  }

                  // Ubah kembali menjadi Map
                  final sortedData =
                      Map<String, dynamic>.fromEntries(filteredData);

                  setState(() {
                    _data = sortedData;
                  });
                }
              } else if (_sort == 'baru' || _sort == 'lama') {
                final snapshot = await _dbRef.orderByChild('timestamp').get();
                if (snapshot.exists && snapshot.value != null) {
                  // Konversi snapshot menjadi Map<String, dynamic>
                  final rawData =
                      Map<String, dynamic>.from(snapshot.value as Map);

                  // Filter hanya data dengan UID yang ada di _temp
                  List<MapEntry<String, dynamic>> filteredData = rawData.entries
                      .where((entry) => _temp.contains(entry.value['uid']))
                      .toList();

                  // Urutkan data berdasarkan "timestamp"
                  filteredData.sort((a, b) => (a.value['timestamp'] ?? 0)
                      .compareTo(b.value['timestamp'] ?? 0));

                  // Jika "baru" (DESC), balikkan urutannya
                  if (_sort == 'baru') {
                    filteredData = filteredData.reversed.toList();
                  }

                  // Ubah kembali menjadi Map
                  final sortedData =
                      Map<String, dynamic>.fromEntries(filteredData);

                  setState(() {
                    _data = sortedData;
                  });
                }
              }
            }
          } else if (!postRef.exists) {
            setState(() {
              _data = null;
            });
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

  @override
  void initState() {
    super.initState();
    _sort = 'asc';
    _refresh();
  }

  String formatTimestamp(int timestamp) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  Future<void> deleteData() async {
    final user = FirebaseAuth.instance.currentUser;
    String? uid = keyId;
    try {
      if (user != null) {
        if (_selectedItems.isEmpty) {
          return;
        } else {
          DatabaseReference postUser = FirebaseDatabase.instance.ref('users');
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text(
                  keyId == null
                      ? 'Hapus Riwayat'
                      : '${_selectedItems.length} item dipilih',
                ),
                content: Text('Anda yakin ingin menghapus riwayat ini?'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Batal'),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  TextButton(
                    child: const Text('Hapus'),
                    onPressed: () {
                      if (uid != null) {
                        _dbRef.child(keyId!).remove();
                      } else {
                        for (int i = 0; i < _selectedItems.length; i++) {
                          uid = _selectedItems[i];
                          String postId = _data![uid]['post'];
                          String userId = _data![uid]['user'];
                          postUser.child('$userId/attendance/$postId').remove();
                          _dbRef.child(uid!).remove();
                        }
                      }
                      setState(() {
                        _isOpen = false;
                        _isSelect = false;
                        _refresh();
                      });
                      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isOpen) {
          setState(() {
            _isOpen = false;
            keyId = null;
          });
          return false;
        } else if (_isSelect) {
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
                if (_isOpen) {
                  setState(() {
                    _isOpen = false;
                    keyId = null;
                  });
                } else if (_isSelect) {
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
                              _refresh();
                            });
                          } else if (value == 'asc') {
                            setState(() {
                              _sort = 'asc';
                              _refresh();
                            });
                          } else if (value == 'desc') {
                            setState(() {
                              _sort = 'desc';
                              _refresh();
                            });
                          } else if (value == 'terbaru') {
                            setState(() {
                              _sort = 'baru';
                              _refresh();
                            });
                          } else if (value == 'terlama') {
                            setState(() {
                              _sort = 'lama';
                              _refresh();
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
                                fontSize: 16.0,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _data![key]['lesson'],
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  formatTimestamp(
                                    _data![key]['timestamp'],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            onLongPress: () {
                              setState(() {
                                _isSelect = true;
                                _selectedItems.clear();
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
                        if (_isProcessing)
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        Container(
                          height: MediaQuery.of(context).size.height * 0.4,
                          margin: EdgeInsets.only(bottom: 10.0),
                          child: Image.network(
                            _data![keyId]['photoUrl'],
                            loadingBuilder: (context, child, loadingProgress) {
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
                                      _data![keyId]['lesson'],
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
                                "Mata Kuliah",
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
                                      _data![keyId]['attendance'],
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
                                "Waktu",
                                style: TextStyle(
                                  fontSize: 12.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (keyId != null) {
                              final locationUrl = _data![keyId]['location'];
                              if (locationUrl != null &&
                                  locationUrl.isNotEmpty) {
                                launch(locationUrl); // Membuka URL lokasi
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text("URL lokasi tidak tersedia")),
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
                        SizedBox(height: 30),
                      ],
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
              )
            else if (_data == null)
              Container(
                color: Colors.white,
                child: Center(
                  child: Text(
                    "Not Attendance yet",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
