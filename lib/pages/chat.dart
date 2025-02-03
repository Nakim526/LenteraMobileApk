import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('users');
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _data;
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  List<String> _filteredUsers = [];
  bool _contactDenied = false;
  bool _isLooked = true;
  bool _isContact = false;
  bool _isLoading = false;
  bool _isSearching = false;
  int? usersLength;

  @override
  void initState() {
    super.initState();
    _refresh();
    _searchController.addListener(_filterContacts);
  }

  void _filterContacts() {
    String query = _searchController.text.toLowerCase();
    if (_isContact) {
      setState(() {
        _filteredContacts = _contacts.where((contact) {
          final name = contact.displayName.toLowerCase();
          return name.contains(query);
        }).toList();
      });
    } else {
      setState(() {
        _filteredUsers = _data!.keys.where((key) {
          final name = _data![key]['name'].toLowerCase();
          return name.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await _dbRef.get();
        if (snapshot.exists) {
          setState(() {
            _data = Map<String, dynamic>.from(snapshot.value as Map);
            usersLength = snapshot.children.length;
          });
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (_contacts.isNotEmpty) return;
      if (!await FlutterContacts.requestPermission()) {
        setState(() => _contactDenied = true);
        return;
      }
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
        sorted: true,
      );
      setState(() {
        _contacts = contacts;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        if (_isSearching) {
          setState(() {
            _isSearching = false;
          });
          return Future.value(false);
        }
        return Future.value(true);
      },
      child: Stack(
        children: [
          Scaffold(
            appBar: _isSearching
                ? AppBar(
                    title: TextField(
                      controller: _searchController,
                      style: TextStyle(color: Colors.white, fontSize: 20),
                      decoration: InputDecoration(
                        hintText: 'Cari...',
                        hintStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    backgroundColor: Colors.green[900],
                    leading: Container(
                      margin: const EdgeInsets.only(left: 16),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                          });
                        },
                      ),
                    ),
                  )
                : AppBar(
                    title: Text(
                      'Pesan',
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
                    actions: [
                      Container(
                        margin: const EdgeInsets.only(right: 16),
                        child: IconButton(
                          icon: const Icon(
                            Icons.search,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _isSearching = true;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
            body: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(0),
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.black,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLooked = true;
                              _isContact = false;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, double.infinity),
                            backgroundColor:
                                _isLooked ? Colors.green : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: BorderSide(
                                color: Colors.black,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Text(
                            "Dilihat",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLooked = false;
                              _isContact = true;
                              _loadContacts();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, double.infinity),
                            backgroundColor:
                                _isContact ? Colors.green : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(0),
                              side: BorderSide(
                                color: Colors.black,
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Text(
                            "Kontak",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _isContact
                    ? _contactDenied
                        ? Expanded(
                            child: Center(
                              child: Text(
                                "Izin kontak ditolak",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          )
                        : _isSearching
                            ? Expanded(
                                child: ListView.builder(
                                  itemCount: _filteredContacts.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      alignment: Alignment.centerLeft,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.all(12),
                                        title: Text(_filteredContacts[index]
                                            .displayName),
                                        onTap: () {},
                                        leading:
                                            _filteredContacts[index].photo !=
                                                    null
                                                ? Container(
                                                    width: 50,
                                                    height: 50,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: ClipOval(
                                                      child: Image.memory(
                                                        _filteredContacts[index]
                                                            .photo!,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  )
                                                : Container(
                                                    width: 50,
                                                    height: 50,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.grey,
                                                    ),
                                                    child: Icon(
                                                      Icons.person,
                                                      color: Colors.white,
                                                      size: 30,
                                                    ),
                                                  ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Expanded(
                                child: ListView.builder(
                                  itemCount: _contacts.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      alignment: Alignment.centerLeft,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.all(12),
                                        title:
                                            Text(_contacts[index].displayName),
                                        onTap: () {},
                                        leading: _contacts[index].photo != null
                                            ? Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                ),
                                                child: ClipOval(
                                                  child: Image.memory(
                                                    _contacts[index].photo!,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              )
                                            : Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.grey,
                                                ),
                                                child: Icon(
                                                  Icons.person,
                                                  color: Colors.white,
                                                  size: 30,
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              )
                    : Expanded(
                        child: _isSearching
                            ? ListView.builder(
                                itemCount: _filteredUsers.length,
                                itemBuilder: (context, index) {
                                  final key = _filteredUsers.elementAt(index);
                                  return Container(
                                    alignment: Alignment.centerLeft,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.black,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.all(12),
                                      title: Text(_data![key]['name']),
                                      onTap: () {},
                                      leading: _data![key]['photo'] != null
                                          ? Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                              ),
                                              child: ClipOval(
                                                child: Image.network(
                                                  _data![key]['photo'],
                                                  fit: BoxFit.cover,
                                                ),
                                              ))
                                          : Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.grey,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 30,
                                              ),
                                            ),
                                    ),
                                  );
                                },
                              )
                            : ListView.builder(
                                itemCount: usersLength ?? 0,
                                itemBuilder: (context, index) {
                                  final key = _data!.keys.toList()[index];
                                  return Container(
                                    alignment: Alignment.centerLeft,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.black,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: EdgeInsets.all(12),
                                      title: Text(_data![key]['name']),
                                      onTap: () {},
                                      leading: _data![key]['photo'] != null
                                          ? Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                              ),
                                              child: ClipOval(
                                                child: Image.network(
                                                  _data![key]['photo'],
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 50,
                                              height: 50,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.grey,
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 30,
                                              ),
                                            ),
                                    ),
                                  );
                                },
                              ),
                      )
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
        ],
      ),
    );
  }
}
