import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final GlobalKey<FormFieldState> fieldKey = GlobalKey<FormFieldState>();
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();
  final _titleController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _fillController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Map<dynamic, dynamic>? _data;
  bool _isOpen = false;
  bool _isEditing = false;
  bool _isAdding = false;
  bool _isRenaming = false;
  bool _isLoading = false;
  bool _isSaved = false;
  bool _isDelete = false;
  String? keyId;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _getCurrentData() async {
    setState(() {
      _titleController.text = _data![keyId]['title'] ?? '';
      _subtitleController.text = _data![keyId]['subtitle'] ?? '';
      _fillController.text = _data![keyId]['fill'] ?? '';
    });
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await _databaseRef
            .child('users')
            .child(user.uid)
            .child('notes')
            .get();
        if (snapshot.exists) {
          setState(() {
            _data = snapshot.value as Map<dynamic, dynamic>;
          });
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

  Future<void> addNotes() async {
    setState(() {
      _isAdding = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final databaseRef = FirebaseDatabase.instance.ref();
      final userRef = databaseRef.child('users/${user.uid}/notes');

      await userRef.push().set({
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim().toString(),
        'fill': '',
        "timestamp": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      });

      setState(() {
        _refreshData();
      });
    }
  }

  Future<void> renameNotes() async {
    setState(() {
      _isRenaming = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final databaseRef = FirebaseDatabase.instance.ref();
      final userRef = databaseRef.child('users/${user.uid}/notes/${keyId}');

      await userRef.update({
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim().toString(),
      });

      setState(() {
        _refreshData();
      });
    }
  }

  Future<void> saveNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final databaseRef = FirebaseDatabase.instance.ref();
      final userRef = databaseRef.child('users/${user.uid}/notes/${keyId}');

      await userRef.update({
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim().toString(),
        'fill': _fillController.text.trim().toString(),
        "timestamp": DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      });

      setState(() {
        _isSaved = true;
        _refreshData();
      });
    }
  }

  Future<void> deleteNotes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final databaseRef = FirebaseDatabase.instance.ref();
      final userRef = databaseRef.child('users/${user.uid}/notes/${keyId}');

      await userRef.remove();

      setState(() {
        _refreshData();
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
            title: const Text('Hapus Note'),
            content: const Text('Anda yakin ingin menghapus note ini?'),
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
                  deleteNotes();
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
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
        if (_isAdding || _isRenaming) {
          setState(() {
            _isAdding = false;
            _isRenaming = false;
          });
          return false;
        } else if (_isOpen) {
          if (_titleController.text != _data![keyId]['title'] ||
              _subtitleController.text != _data![keyId]['subtitle'] ||
              _fillController.text != _data![keyId]['fill']) {
            setState(() {
              _isSaved = false;
            });
            await _showDialog();
          } else {
            setState(() {
              _isOpen = false;
              _isEditing = false;
            });
          }
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isOpen ? _data![keyId]['title'] : "Notes",
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
                if (_isAdding || _isRenaming || _isOpen) {
                  setState(() {
                    _isAdding = false;
                    _isRenaming = false;
                    _isOpen = false;
                  });
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          actions: [
            if (!_isOpen)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _isAdding = true;
                        _titleController.clear();
                        _subtitleController.clear();
                      });
                    },
                  ),
                  Container(
                    margin: EdgeInsets.only(right: 16),
                    child: IconButton(
                      icon: Icon(Icons.refresh, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _refreshData();
                          _isLoading = true;
                        });
                      },
                    ),
                  ),
                ],
              ),
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
                  Container(
                    margin: EdgeInsets.only(right: 16),
                    child: IconButton(
                      icon: const Icon(Icons.exit_to_app, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          saveNotes();
                          _isOpen = false;
                        });
                      },
                    ),
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
                                  fontSize: 16.0,
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
                                    _data![key]['timestamp'],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              contentPadding: EdgeInsets.only(
                                left: 16.0,
                                right: 8.0,
                              ),
                              onTap: () {
                                setState(() {
                                  keyId = key;
                                  _isOpen = true;
                                  _isEditing = false;
                                  _getCurrentData();
                                });
                              },
                              trailing: PopupMenuButton<int>(
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
              )
            else if (_data == null)
              Stack(
                children: [
                  _isLoading
                      ? Container(
                          color: Colors.black45,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Container(
                          child: Center(
                            child: Text(
                              "Not notes yet",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                ],
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
