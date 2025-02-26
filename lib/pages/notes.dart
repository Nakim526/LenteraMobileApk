import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final GlobalKey<FormFieldState> fieldKey = GlobalKey<FormFieldState>();
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('users');
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _fillController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Map<dynamic, dynamic>? _data;
  List<String> _selectedItems = [];
  List<String> _uidList = [];
  String? keyId;
  String? _sort;
  bool _isOpen = false;
  bool _isSelect = false;
  bool _isEditing = false;
  bool _isAdding = false;
  bool _isRenaming = false;
  bool _isLoading = false;
  bool _isSaved = true;
  bool _isDelete = false;

  @override
  void initState() {
    super.initState();
    _sort = 'asc';
    _refresh();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _fillController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentData() async {
    setState(() {
      _titleController.text = _data![keyId]['title'];
      _subtitleController.text = _data![keyId]['subtitle'] ?? '';
      _fillController.text = _data![keyId]['fill'] ?? '';
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (_sort == 'asc' || _sort == 'desc') {
          final snapshot = await _dbRef
              .child('${user.uid}/notes')
              .orderByChild('title')
              .get();
          if (snapshot.exists) {
            final rawData = Map<String, dynamic>.from(snapshot.value as Map);

            List<MapEntry<String, dynamic>> sortedList =
                rawData.entries.toList();

            sortedList.sort((a, b) {
              return a.value['title']
                  .toString()
                  .compareTo(b.value['title'].toString());
            });

            if (_sort == 'desc') {
              sortedList = sortedList.reversed.toList();
            }

            final sortedData = Map<String, dynamic>.fromEntries(sortedList);

            setState(() {
              _data = sortedData;
            });

            setState(() {
              _uidList = _data!.keys.cast<String>().toList();
            });
          } else {
            setState(() {
              _data = null;
            });
          }
        } else if (_sort == 'baru' || _sort == 'lama') {
          final snapshot = await _dbRef
              .child('${user.uid}/notes')
              .orderByChild('timestamp')
              .get();
          if (snapshot.exists) {
            final rawData = Map<String, dynamic>.from(snapshot.value as Map);

            List<MapEntry<String, dynamic>> sortedList =
                rawData.entries.toList();

            sortedList.sort((a, b) {
              return a.value['timestamp'].compareTo(b.value['timestamp']);
            });

            if (_sort == 'baru') {
              sortedList = sortedList.reversed.toList();
            }

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

  Future<void> addNotes() async {
    setState(() {
      _isAdding = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final notesRef = _dbRef.child('${user.uid}/notes');

      await notesRef.push().set({
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim(),
        'fill': _fillController.text.trim(),
        "timestamp": ServerValue.timestamp,
      });

      setState(() {
        _isSaved = true;
        _refresh();
      });
    }
  }

  Future<void> renameNotes() async {
    setState(() {
      _isRenaming = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = _dbRef.child('${user.uid}/notes/$keyId');

      await userRef.update({
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim(),
      });

      setState(() {
        _refresh();
      });
    }
  }

  Future<void> saveNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = _dbRef.child('${user.uid}/notes/$keyId');

      await userRef.update({
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim(),
        'fill': _fillController.text.trim(),
        "timestamp": ServerValue.timestamp,
      });

      setState(() {
        _isSaved = true;
        _refresh();
      });
    }
  }

  Future<void> deleteNotes(String uid) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = _dbRef.child('${user.uid}/notes/$uid');

      await userRef.remove();

      setState(() {
        _refresh();
      });
    }
  }

  Future<void> _showDialog() async {
    if (!_isSaved) {
      return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Peringatan!'),
            content: const Text(
              'Catatan belum disimpan. Apakah kamu ingin meninggalkan halaman ini?',
            ),
            actions: [
              TextButton(
                child: const Text('Batal'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              TextButton(
                child: const Text('Simpan & Keluar'),
                onPressed: () {
                  setState(() {
                    saveNotes();
                    _isOpen = false;
                    _isEditing = false;
                    _isSaved = true;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    } else if (_isDelete) {
      return showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              _selectedItems.isEmpty
                  ? 'Hapus Note'
                  : '${_selectedItems.length} item dipilih',
            ),
            content: const Text('Anda yakin ingin menghapus note ini?'),
            actions: <Widget>[
              TextButton(
                child: const Text('Batal'),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedItems.clear();
                    _isSelect = false;
                    _isDelete = false;
                  });
                },
              ),
              TextButton(
                child: const Text('Hapus'),
                onPressed: () {
                  if (_selectedItems.isNotEmpty) {
                    for (int i = 0; i < _selectedItems.length; i++) {
                      String uid = _selectedItems[i];
                      deleteNotes(uid);
                    }
                  } else {
                    deleteNotes(keyId!);
                  }
                  setState(() {
                    _selectedItems.clear();
                    _isSelect = false;
                    _isDelete = false;
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

  Future<void> _navigateAndRefresh(String routeName, Object? object) async {
    Navigator.pushReplacementNamed(context, routeName, arguments: object);
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
    Navigator.pushReplacementNamed(context, '/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    double screenHeight = MediaQuery.of(context).size.height;
    double statusBarHeight = MediaQuery.of(context).padding.top;
    double appBarHeight = kToolbarHeight;
    double availableHeight = screenHeight - statusBarHeight - appBarHeight;
    return WillPopScope(
      onWillPop: () async {
        if (_isAdding || _isRenaming) {
          setState(() {
            _isAdding = false;
            _isRenaming = false;
          });
          return false;
        } else if (_isSelect) {
          setState(() {
            _isSelect = false;
            _selectedItems.clear();
          });
          return false;
        } else if (_isOpen) {
          if (_titleController.text != _data![keyId]['title'] ||
              _subtitleController.text != _data![keyId]['subtitle'] ||
              _fillController.text != _data![keyId]['fill']) {
            setState(() {
              _isSaved = false;
              _showDialog();
            });
          } else {
            setState(() {
              _isOpen = false;
              _isEditing = false;
            });
          }
          return false;
        }

        Navigator.pushReplacementNamed(context, '/home');
        return false;
      },
      child: Scaffold(
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
            _isOpen
                ? _data![keyId]['title']
                : _isSelect
                    ? '${_selectedItems.length} dipilih'
                    : 'Catatan',
            style: const TextStyle(
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
                if (_isAdding || _isRenaming) {
                  setState(() {
                    _isAdding = false;
                    _isRenaming = false;
                    _isOpen = false;
                  });
                } else if (_isOpen) {
                  if (_titleController.text != _data![keyId]['title'] ||
                      _subtitleController.text != _data![keyId]['subtitle'] ||
                      _fillController.text != _data![keyId]['fill']) {
                    setState(() {
                      _isSaved = false;
                      _showDialog();
                    });
                  } else {
                    setState(() {
                      _isOpen = false;
                      _isEditing = false;
                    });
                  }
                } else if (_isSelect) {
                  setState(() {
                    _isSelect = false;
                  });
                } else {
                  Navigator.pushReplacementNamed(context, '/home');
                }
              },
            ),
          ),
          actions: [
            if (!_isOpen)
              Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: !_isSelect
                      ? Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _isAdding = true;
                                  _titleController.clear();
                                  _subtitleController.clear();
                                  _fillController.clear();
                                });
                              },
                            ),
                            PopupMenuButton(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white),
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
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.delete, color: Colors.white),
                              onPressed: () {
                                if (_selectedItems.isEmpty) {
                                  return;
                                }
                                setState(() {
                                  _isDelete = true;
                                  _showDialog();
                                });
                              },
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  if (_selectedItems.length !=
                                      _uidList.length) {
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
                        )),
            if (_isOpen)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.save, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        saveNotes();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.exit_to_app, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        saveNotes();
                        _isOpen = false;
                      });
                    },
                  ),
                ],
              ),
          ],
        ),
        body: Stack(
          children: [
            if (_data != null)
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
                  itemCount: _data?.length,
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
                        child: Stack(
                          children: [
                            ListTile(
                              title: Text(
                                _data![key]['title'],
                                style: TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_data![key]['subtitle'] != null &&
                                      _data![key]['subtitle']!.isNotEmpty)
                                    Text(
                                      _data![key]['subtitle'],
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
                              contentPadding: EdgeInsets.only(
                                left: 16.0,
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
                                    keyId = key;
                                    _isOpen = true;
                                    _isEditing = false;
                                    _getCurrentData();
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
                                  : PopupMenuButton<int>(
                                      menuPadding: EdgeInsets.zero,
                                      icon: Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        // Tindakan ketika item dipilih
                                        if (value == 1) {
                                          setState(() {
                                            keyId = key;
                                            _isOpen = true;
                                            _isEditing = true;
                                            _getCurrentData();
                                          });
                                        } else if (value == 2) {
                                          setState(() {
                                            keyId = key;
                                            _isRenaming = true;
                                            _titleController.text =
                                                _data![key]['title'];
                                            _subtitleController.text =
                                                _data![key]['subtitle'];
                                            _fillController.text =
                                                _data![key]['fill'];
                                          });
                                        } else if (value == 3) {
                                          setState(() {
                                            keyId = key;
                                            _isDelete = true;
                                            _showDialog();
                                          });
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          value: 1,
                                          child: Text("Edit"),
                                        ),
                                        PopupMenuItem(
                                          value: 2,
                                          child: Text("Rename"),
                                        ),
                                        PopupMenuItem(
                                          value: 3,
                                          child: Text("Delete"),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
                child: Center(
                  child: Text(
                    "Not notes yet",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (_isAdding || _isRenaming)
              Container(
                color: Colors.black45,
                child: Center(
                  child: Form(
                    key: _formKey,
                    child: IntrinsicHeight(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        padding: EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              margin: EdgeInsets.symmetric(
                                vertical: 5,
                              ),
                              child: TextFormField(
                                key: fieldKey,
                                controller: _titleController,
                                decoration: InputDecoration(
                                  label: RichText(
                                    text: TextSpan(
                                      text: 'Title',
                                      style: TextStyle(
                                          color: Colors.black,
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
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a title';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(
                                vertical: 5,
                              ),
                              child: TextFormField(
                                controller: _subtitleController,
                                decoration: InputDecoration(
                                  labelText: 'Subtitle (optional)',
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                if (_isAdding) {
                                  if (_formKey.currentState!.validate()) {
                                    setState(() {
                                      addNotes();
                                    });
                                  }
                                } else if (_isRenaming) {
                                  if (_formKey.currentState!.validate()) {
                                    setState(() {
                                      renameNotes();
                                    });
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                minimumSize: Size(100, 50),
                                elevation: 5,
                                shadowColor: Colors.grey,
                              ),
                              child: Text(
                                _isAdding ? 'Buat' : 'Ubah',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_isOpen)
              Form(
                key: _formKey,
                child: Stack(
                  children: [
                    Container(
                      height: availableHeight,
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      color: Colors.white,
                      child: ListView(
                        children: [
                          Column(
                            children: [
                              Container(
                                margin: EdgeInsets.only(top: 8.0),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Last saved: ${_data![keyId]['timestamp']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w200,
                                  ),
                                ),
                              ),
                              TextFormField(
                                controller: _titleController,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                decoration: InputDecoration(
                                  hintText: 'Title',
                                ),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                enabled: _isEditing ? true : false,
                              ),
                              TextFormField(
                                controller: _subtitleController,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                decoration: InputDecoration(
                                  hintText: 'Subtitle...',
                                ),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                                enabled: _isEditing ? true : false,
                              ),
                              TextFormField(
                                controller: _fillController,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Type here...',
                                  contentPadding: EdgeInsets.only(
                                    top: 16,
                                    bottom: availableHeight * 0.7,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                                enabled: _isEditing ? true : false,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 25,
                      right: 25,
                      child: IconButton(
                        onPressed: () {
                          if (_isEditing) {
                            setState(() {
                              _isEditing = false;
                            });
                          } else {
                            setState(() {
                              _isEditing = true;
                            });
                          }
                        },
                        icon: Icon(_isEditing ? Icons.check : Icons.edit),
                        iconSize: 30,
                        color: Colors.white,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 5,
                          shadowColor: Colors.grey,
                          padding: EdgeInsets.all(16),
                        ),
                      ),
                    )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
