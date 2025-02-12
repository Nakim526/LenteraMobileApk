import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:intl/intl.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../src/mqtt_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('users');
  final PageController _pageController = PageController(viewportFraction: 1.0);
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final MqttService mqttService = MqttService();
  final String topic = "flutter/chat";
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _lastMessagesSubscription;
  List<Map<String, dynamic>> messages = [];
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _last;
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  List<String> _filteredUsers = [];
  bool _contactDenied = false;
  bool _isOpen = false;
  bool _isLooked = true;
  bool _isContact = false;
  bool _isLoading = false;
  bool _isSearching = false;
  String? receiverId;
  int? usersLength;

  @override
  void initState() {
    super.initState();
    _refresh();
    listenForLastMessages();
    _searchController.addListener(_filterContacts);
  }

  @override
  void dispose() {
    mqttService.disconnect();
    _pageController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _messagesSubscription?.cancel();
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

    _messagesSubscription =
        messagesRef.orderByChild("timestamp").onChildAdded.listen((event) {
      try {
        // ✅ Pastikan casting ke Map<String, dynamic>
        final rawData = event.snapshot.value as Map<dynamic, dynamic>;
        final newMessage =
            rawData.map((key, value) => MapEntry(key.toString(), value));

        setState(() {
          if (!messages
              .any((msg) => msg["timestamp"] == newMessage["timestamp"])) {
            messages.add(newMessage);
            print('berapa kali');
          }
        });
      } catch (e) {
        print("🔥 Error parsing message: $e");
      }
    });
  }

  void listenForLastMessages() {
    _lastMessagesSubscription?.cancel(); // Hentikan listener lama
    DatabaseReference chatsRef = FirebaseDatabase.instance.ref("chats");

    _lastMessagesSubscription = chatsRef.onValue.listen((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final rawData = Map<String, dynamic>.from(event.snapshot.value as Map);

        setState(() {
          _last = rawData.map((key, value) => MapEntry(key.toString(), value));
        });
      }
    });
  }

  String getTime(int? timestamp) {
    if (timestamp == 0 || timestamp == null) return '';
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isOpen) {
          setState(() {
            _isOpen = false;
            messages.clear();
          });
          return false;
        }
        if (_isSearching) {
          setState(() {
            _isSearching = false;
          });
          return false;
        }
        return true;
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
                                                getTime(
                                                  _last?[getChatId(
                                                      FirebaseAuth.instance
                                                          .currentUser!.uid,
                                                      key)]['timestamp'],
                                                ),
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
                                                  key)]['lastMessage'] ??
                                              ''),
                                          trailing: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Text(
                                                getTime(
                                                  _last?[getChatId(
                                                      FirebaseAuth.instance
                                                          .currentUser!.uid,
                                                      key)]['timestamp'],
                                                ),
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
                  Stack(
                    children: [
                      Container(
                        color: Colors.white,
                        child: ListView.builder(
                          key: ValueKey(messages.length),
                          itemCount: messages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == messages.length) {
                              return Container(
                                height: 100,
                              );
                            }
                            final message = messages[index];
                            return Container(
                              margin: EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: message['senderId'] ==
                                        FirebaseAuth.instance.currentUser!.uid
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  IntrinsicWidth(
                                    child: Container(
                                      padding: EdgeInsets.all(10),
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.of(context).size.width *
                                                0.8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: message['senderId'] ==
                                                FirebaseAuth
                                                    .instance.currentUser!.uid
                                            ? Colors.green
                                            : Colors.grey[300],
                                        borderRadius: BorderRadius.circular(8),
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
                                    mainAxisAlignment: message['senderId'] ==
                                            FirebaseAuth
                                                .instance.currentUser!.uid
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
                            );
                          },
                        ),
                      ),
                      Positioned(
                        bottom: 0.0,
                        left: 0.0,
                        right: 0.0,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 16.0,
                          ),
                          color: Colors.white,
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.0),
                              ),
                              contentPadding: EdgeInsets.all(20.0),
                              hintText: 'Ketik pesan...',
                              suffixIcon: IconButton(
                                icon: Icon(Icons.send),
                                onPressed: () {
                                  if (_messageController.text.isNotEmpty) {
                                    final user =
                                        FirebaseAuth.instance.currentUser;
                                    String message = _messageController.text;
                                    _messageController.clear();
                                    sendMessage(message,
                                        getChatId(user!.uid, receiverId!));
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
