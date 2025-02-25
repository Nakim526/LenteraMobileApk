import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../src/mqtt_service.dart';
import 'package:vibration/vibration.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('users');
  final _pageController = PageController(viewportFraction: 1.0);
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final MqttService mqttService = MqttService();
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _lastMessagesSubscription;
  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _last;
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  List<String> _filteredUsers = [];
  final List<String> _selectedItems = [];
  bool _contactDenied = false;
  bool _isOpen = false;
  bool _isLooked = true;
  bool _isContact = false;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isSearching = false;
  String? _messageId;
  String? receiverId;
  String? selectedMessage;
  int? usersLength;

  @override
  void initState() {
    super.initState();
    _refresh();
    listenForLastMessages();
    scrollToBottom();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _messageController.dispose();
    _messagesSubscription?.cancel();
    _lastMessagesSubscription?.cancel();
    mqttService.disconnect();
    super.dispose();
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

  void sendMessage(String message, String chatId) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user!.uid;
    String messageId =
        FirebaseDatabase.instance.ref("messages/$chatId").push().key!;

    final newMessage = {
      "messageId": messageId, // ✅ Gunakan ID unik
      "senderId": userId,
      "receiverId": receiverId,
      "message": message,
      "timestamp": DateTime.now().millisecondsSinceEpoch
    };

    DatabaseReference messagesRef =
        FirebaseDatabase.instance.ref("messages/$chatId/$messageId");

    messagesRef.set(newMessage).then((_) {
      // ✅ Perbarui daftar chat
      DatabaseReference chatRef =
          FirebaseDatabase.instance.ref("chats/$chatId");
      chatRef.update({
        "lastMessage": message,
        "lastSender": userId,
        "timestamp": DateTime.now().millisecondsSinceEpoch
      });

      // ✅ Kirim notifikasi via MQTT
      sendMQTTMessage(chatId, newMessage);
    });
  }

  void sendMQTTMessage(String chatId, Map<String, dynamic> message) {
    final mqttClient = MqttServerClient('broker.hivemq.com',
        'flutter_client_${DateTime.now().millisecondsSinceEpoch}');

    mqttClient.connect().then((_) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode({
        "chatId": chatId,
        "message": message
      })); // ✅ Pastikan dalam format JSON

      mqttClient.publishMessage(
          "chat/$chatId", MqttQos.atLeastOnce, builder.payload!);
      mqttClient.disconnect();
    });
  }

  String getChatId(String senderId, String receiverId) {
    int comparison = senderId.compareTo(receiverId);

    if (comparison > 0) {
      return "$senderId>$receiverId";
    } else if (comparison < 0) {
      return "$receiverId>$senderId";
    } else {
      return "$senderId=$receiverId";
    }
  }

  void listenForMessages(String chatId) {
    _messagesSubscription?.cancel();
    DatabaseReference messagesRef =
        FirebaseDatabase.instance.ref("messages/$chatId");

    // ✅ Tambahkan pesan baru
    _messagesSubscription =
        messagesRef.orderByChild("timestamp").onChildAdded.listen((event) {
      try {
        final rawData = event.snapshot.value as Map<dynamic, dynamic>;
        final newMessage =
            rawData.map((key, value) => MapEntry(key.toString(), value));

        setState(() {
          if (!messages
              .any((msg) => msg["timestamp"] == newMessage["timestamp"])) {
            messages.add(newMessage);
            updateLastMessage(chatId, newMessage); // ✅ Update lastMessage
            scrollToBottom();
          }
        });
      } catch (e) {
        print("🔥 Error parsing message: $e");
      }
    });

    // ✅ Update pesan jika diedit
    messagesRef.onChildChanged.listen((event) {
      try {
        final updatedData = event.snapshot.value as Map<dynamic, dynamic>;
        final updatedMessage =
            updatedData.map((key, value) => MapEntry(key.toString(), value));

        setState(() {
          int index = messages.indexWhere(
              (msg) => msg["messageId"] == updatedMessage["messageId"]);
          if (index != -1) {
            messages[index] = updatedMessage;
            updateLastMessage(chatId, updatedMessage); // ✅ Update lastMessage
          }
        });
      } catch (e) {
        print("🔥 Error updating message: $e");
      }
    });

    // ✅ Hapus pesan
    messagesRef.onChildRemoved.listen((event) {
      try {
        final deletedData = event.snapshot.value as Map<dynamic, dynamic>;
        final deletedMessageId = deletedData["messageId"];

        setState(() {
          messages.removeWhere((msg) => msg["messageId"] == deletedMessageId);
        });

        // ✅ Jika semua pesan sudah dihapus, update lastMessage jadi null
        if (messages.isEmpty) {
          updateLastMessage(chatId, null);
        } else {
          updateLastMessage(chatId, messages.last);
        }
      } catch (e) {
        print("🔥 Error deleting message: $e");
      }
    });
  }

  void updateLastMessage(String chatId, Map<String, dynamic>? lastMessage) {
    DatabaseReference chatRef = FirebaseDatabase.instance.ref("chats/$chatId");

    if (lastMessage != null) {
      // ✅ Perbarui lastMessage jika ada pesan baru
      chatRef.update({
        "lastMessage": lastMessage["message"],
        "lastSender": lastMessage["senderId"],
        "timestamp": lastMessage["timestamp"],
      });
    } else {
      // ✅ Hapus lastMessage jika semua pesan sudah dihapus
      chatRef.update({
        "lastMessage": null,
        "lastSender": null,
        "timestamp": null,
      });
    }
  }

  void listenForLastMessages() {
    _lastMessagesSubscription?.cancel();
    DatabaseReference chatsRef = FirebaseDatabase.instance.ref("chats");

    // ✅ Jika ada perubahan di "lastMessage", update UI
    _lastMessagesSubscription = chatsRef.onValue.listen((event) async {
      await Future.delayed(Duration(milliseconds: 100));
      if (event.snapshot.exists && event.snapshot.value != null) {
        final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);

        setState(() {
          _last = rawData.map((key, value) => MapEntry(key.toString(), value));
        });
      } else {
        setState(() {
          _last!.clear();
        });
      }
    });

    chatsRef.onChildChanged.listen((event) {
      try {
        if (event.snapshot.exists && event.snapshot.value != null) {
          final updatedData =
              Map<String, dynamic>.from(event.snapshot.value as Map);
          final chatId = event.snapshot.key;

          setState(() {
            if (_last!.containsKey(chatId)) {
              _last![chatId!] = updatedData;
            }
          });
        }
      } catch (e) {
        print("🔥 Error updating lastMessage: $e");
      }
    });

    chatsRef.onChildRemoved.listen((event) {
      try {
        final chatId = event.snapshot.key;

        setState(() {
          _last!.remove(chatId);
        });
      } catch (e) {
        print("🔥 Error deleting lastMessage: $e");
      }
    });
  }

  String getTime(int? timestamp) {
    if (timestamp == 0 || timestamp == null) return '';
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('HH:mm').format(date);
  }

  String? getLastTime(int? timestamp, bool? isOpen) {
    if (timestamp == 0 || timestamp == null) return '';

    DateTime now = DateTime.now();
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    DateTime nowDate = DateTime(now.year, now.month, now.day);
    DateTime dateOnly = DateTime(date.year, date.month, date.day);
    int dayDiff = nowDate.difference(dateOnly).inDays;
    Duration timeDiff = now.difference(date);

    if (dayDiff == 0) {
      if (isOpen!) return 'Hari ini';
      if (timeDiff.inSeconds < 5) return 'Baru saja';
      return DateFormat('HH:mm').format(date); // Hari ini → 12:30
    } else if (dayDiff == 1) {
      return "Kemarin"; // Kemarin
    } else if (dayDiff < 7) {
      return DateFormat('EEEE', 'id_ID').format(date); // Senin, Selasa, dll.
    } else {
      return DateFormat('d MMM yyyy', 'id_ID').format(date); // 5 Feb 2025
    }
  }

  void scrollToBottom() {
    Future.delayed(Duration(milliseconds: 500), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMessageOptions(
      BuildContext context, String messageId, String? message) {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      builder: (BuildContext ctx) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.copy),
                title: Text('Copy'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message!));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                onTap: () {
                  setState(() {
                    selectedMessage = message!;
                    _messageController.text = message;
                    _messageId = messageId;
                    _isEditing = true;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
                onTap: () {
                  _deleteMessage(messageId); // ✅ Hapus pesan
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      // ✅ Hapus selection ketika BottomSheet tertutup
      setState(() {
        _selectedItems.clear();
      });
    });
  }

  void _deleteMessage(String messageId) {
    String senderId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = getChatId(senderId, receiverId!);
    DatabaseReference messageRef =
        FirebaseDatabase.instance.ref("messages/$chatId/$messageId");
    messageRef.remove();
  }

  void _editMessage(String messageId, String message) {
    String senderId = FirebaseAuth.instance.currentUser!.uid;
    String chatId = getChatId(senderId, receiverId!);
    DatabaseReference messageRef =
        FirebaseDatabase.instance.ref("messages/$chatId/$messageId");
    messageRef.update({
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _navigateAndRefresh(String routeName, Object? object) async {
    Navigator.pushReplacementNamed(context, routeName, arguments: object);
  }

  Future<void> _logout(BuildContext context) async {
    // Hapus status login dari SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Navigasi kembali ke halaman login
    Navigator.pushReplacementNamed(context, '/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    Set<String> displayedDates = {};
    return WillPopScope(
      onWillPop: () async {
        if (_isOpen) {
          setState(() {
            _isOpen = false;
            messages.clear();
            receiverId = null;
          });
          return false;
        }
        if (_isSearching) {
          setState(() {
            _isSearching = false;
          });
          return false;
        }
        Navigator.pushReplacementNamed(context, '/home');
        return false;
      },
      child: Stack(
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
                      receiverId != null ? _data![receiverId]['name'] : 'Pesan',
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
                          if (_isOpen) {
                            setState(() {
                              _isOpen = false;
                              messages.clear();
                              receiverId = null;
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
            body: Stack(
              children: [
                Column(
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
                                _pageController.jumpToPage(0);
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize:
                                    Size(double.infinity, double.infinity),
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
                                _pageController.jumpToPage(1);
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize:
                                    Size(double.infinity, double.infinity),
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
                    Expanded(
                      child: PageView.builder(
                        physics: ClampingScrollPhysics(),
                        controller: _pageController,
                        itemCount: 2,
                        onPageChanged: (index) {
                          setState(() {
                            _isLooked = index == 0;
                            _isContact = index == 1;
                            _loadContacts();
                          });
                        },
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return _isSearching
                                ? ListView.builder(
                                    itemCount: _filteredUsers.length,
                                    itemBuilder: (context, index) {
                                      final key =
                                          _filteredUsers.elementAt(index);
                                      return Container(
                                        margin: EdgeInsets.symmetric(
                                            horizontal: 4.0),
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
                                          onTap: () {
                                            final user = FirebaseAuth
                                                .instance.currentUser;
                                            listenForMessages(
                                                getChatId(user!.uid, key));
                                            setState(() {
                                              receiverId = key;
                                              _isOpen = true;
                                            });
                                          },
                                          title: Text(_data![key]['name']),
                                          subtitle: Text(_last?[getChatId(
                                                  FirebaseAuth.instance
                                                      .currentUser!.uid,
                                                  key)]?['lastMessage'] ??
                                              ''),
                                          trailing: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Text(
                                                getLastTime(
                                                      _last?[getChatId(
                                                          FirebaseAuth.instance
                                                              .currentUser!.uid,
                                                          key)]?['timestamp'],
                                                      false,
                                                    ) ??
                                                    '',
                                              ),
                                            ],
                                          ),
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
                                        margin: EdgeInsets.symmetric(
                                            horizontal: 4.0),
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
                                          onTap: () {
                                            final user = FirebaseAuth
                                                .instance.currentUser;
                                            listenForMessages(
                                                getChatId(user!.uid, key));
                                            setState(() {
                                              receiverId = key;
                                              _isOpen = true;
                                            });
                                          },
                                          title: Text(_data![key]['name']),
                                          subtitle: Text(_last?[getChatId(
                                                  FirebaseAuth.instance
                                                      .currentUser!.uid,
                                                  key)]?['lastMessage'] ??
                                              ''),
                                          trailing: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Text(
                                                getLastTime(
                                                      _last?[getChatId(
                                                          FirebaseAuth.instance
                                                              .currentUser!.uid,
                                                          key)]?['timestamp'],
                                                      false,
                                                    ) ??
                                                    '',
                                              ),
                                            ],
                                          ),
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
                                  );
                          } else if (index == 1) {
                            if (_contactDenied) {
                              return Expanded(
                                child: Center(
                                  child: Text(
                                    "Izin kontak ditolak",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              if (_isSearching) {
                                return ListView.builder(
                                  itemCount: _filteredContacts.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      margin:
                                          EdgeInsets.symmetric(horizontal: 4.0),
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
                                        onTap: () {
                                          setState(() {
                                            _isOpen = true;
                                          });
                                        },
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
                                );
                              } else {
                                return ListView.builder(
                                  itemCount: _contacts.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      margin:
                                          EdgeInsets.symmetric(horizontal: 4.0),
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
                                        onTap: () {
                                          setState(() {
                                            _isOpen = true;
                                          });
                                        },
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
                                );
                              }
                            }
                          }
                          return Container();
                        },
                      ),
                    ),
                  ],
                ),
                if (_isOpen)
                  GestureDetector(
                    onTap: () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        _selectedItems.clear();
                      });
                    },
                    child: Stack(
                      children: [
                        Container(
                          color: Colors.white,
                          child: ListView.builder(
                            key: ValueKey(messages.length),
                            physics: AlwaysScrollableScrollPhysics(),
                            controller: _scrollController,
                            itemCount: messages.length + 1,
                            itemBuilder: (context, index) {
                              if (index == messages.length) {
                                return Container(
                                  height: _isEditing
                                      ? kToolbarHeight * 2.885
                                      : kToolbarHeight * 1.6,
                                );
                              }
                              final message = messages[index];
                              final key = messages[index]['messageId'];
                              String dateLabel =
                                  getLastTime(message['timestamp'], true) ?? '';

                              bool showDate =
                                  !displayedDates.contains(dateLabel);
                              if (showDate) {
                                displayedDates.add(dateLabel);
                              }
                              return Column(
                                children: [
                                  if (showDate)
                                    Container(
                                      margin: EdgeInsets.only(
                                        top: 8,
                                        bottom: 4,
                                      ),
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        getLastTime(
                                                message['timestamp'], true) ??
                                            '',
                                        style: TextStyle(
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  GestureDetector(
                                    onLongPress: () async {
                                      if (await Vibration.hasVibrator()) {
                                        Vibration.vibrate(
                                            duration: 100); // ✅ Getaran 100ms
                                      }
                                      setState(() {
                                        _selectedItems.clear();
                                        _selectedItems.add(key);
                                        _showMessageOptions(
                                            context, key, message['message']);
                                      });
                                    },
                                    child: Container(
                                      margin: EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 16,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            message['senderId'] ==
                                                    FirebaseAuth.instance
                                                        .currentUser!.uid
                                                ? CrossAxisAlignment.end
                                                : CrossAxisAlignment.start,
                                        children: [
                                          IntrinsicWidth(
                                            child: Container(
                                              padding: EdgeInsets.all(10),
                                              constraints: BoxConstraints(
                                                maxWidth: MediaQuery.of(context)
                                                        .size
                                                        .width *
                                                    0.8,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _selectedItems
                                                        .contains(key)
                                                    ? Colors.amber
                                                    : message['senderId'] ==
                                                            FirebaseAuth
                                                                .instance
                                                                .currentUser!
                                                                .uid
                                                        ? Colors
                                                            .greenAccent[700]
                                                        : Colors.grey[300],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                message['message'],
                                                style: TextStyle(
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                message['senderId'] ==
                                                        FirebaseAuth.instance
                                                            .currentUser!.uid
                                                    ? MainAxisAlignment.end
                                                    : MainAxisAlignment.start,
                                            children: [
                                              Text(
                                                getTime(message['timestamp']),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                              Icon(
                                                Icons.check,
                                                size: 12,
                                                color: Colors.grey,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        if (_isEditing)
                          Container(
                            color: Colors.black45,
                          ),
                        Positioned(
                          bottom: 0.0,
                          left: 0.0,
                          right: 0.0,
                          child: Container(
                            height: _isEditing
                                ? kToolbarHeight * 2.885
                                : kToolbarHeight * 1.6,
                            color: Colors.green[900],
                            child: Column(
                              children: [
                                SizedBox(height: 8.0),
                                if (_isEditing)
                                  Column(
                                    children: [
                                      Container(
                                        margin: EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[300]!
                                              .withOpacity(0.8),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: 8.0,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                selectedMessage!,
                                                style: TextStyle(
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(Icons.close),
                                              color: Colors.black,
                                              onPressed: () {
                                                setState(() {
                                                  _isEditing = false;
                                                  _messageController.clear();
                                                });
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 8.0),
                                    ],
                                  ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                  ),
                                  child: TextField(
                                    controller: _messageController,
                                    maxLines: 4,
                                    minLines: 1,
                                    onTap: () {
                                      setState(() {
                                        scrollToBottom();
                                      });
                                    },
                                    style: TextStyle(
                                      color: Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(20.0),
                                        borderSide: BorderSide(
                                          color: Colors.grey[300]!,
                                          width: 4.0,
                                        ),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: EdgeInsets.all(20.0),
                                      hintText: 'Ketik pesan...',
                                      hintStyle: TextStyle(
                                        color: Colors.grey,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          Icons.send,
                                          color: Colors.black,
                                        ),
                                        onPressed: () {
                                          if (_messageController
                                              .text.isNotEmpty) {
                                            final user = FirebaseAuth
                                                .instance.currentUser;
                                            String message =
                                                _messageController.text;
                                            if (_isEditing) {
                                              _editMessage(
                                                  _messageId!, message);
                                            } else {
                                              sendMessage(
                                                  message,
                                                  getChatId(
                                                      user!.uid, receiverId!));
                                            }
                                            setState(() {
                                              _messageController.clear();
                                              _selectedItems.clear();
                                              _isEditing = false;
                                              scrollToBottom();
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16.0),
                              ],
                            ),
                          ),
                        ),
                      ],
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
