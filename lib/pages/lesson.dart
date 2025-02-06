import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({super.key});

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('tasks');
  Map<dynamic, dynamic>? _data;
  Map<dynamic, dynamic>? _matkul;
  String? postUser;
  bool _isAdmin = false;
  bool _isLoading = false;
  bool _isFirst = true;

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
        _matkul = matkul;
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
        final databaseRef = FirebaseDatabase.instance.ref('users/${user.uid}');
        final role = await databaseRef.child('role').get();
        if (role.exists && role.value == 'admin') {
          setState(() {
            _isAdmin = true;
          });
        }
        final DatabaseReference taskRef = _dbRef.child(_matkul!['matkul']);
        final snapshot = await taskRef.orderByChild('timestamp').get();
        if (snapshot.exists) {
          final rawData = Map<String, dynamic>.from(snapshot.value as Map);
          List<MapEntry<String, dynamic>> sortedList = rawData.entries.toList();

          sortedList.sort((a, b) {
            return a.value['timestamp'].compareTo(b.value['timestamp']);
          });
          sortedList = sortedList.reversed.toList();
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
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateAndRefresh(String routeName, Object? object) async {
    await Navigator.pushNamed(context, routeName, arguments: object);
    _loadData();
  }

  String formatTimestamp(int timestamp) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  Future<String?> userCheck(String idKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot =
          await _dbRef.child('${_matkul!['matkul']}/$idKey/presences').get();
      if (snapshot.exists) {
        final outerMap = Map.from(snapshot.value as Map);
        for (var key in outerMap.keys) {
          if (outerMap[key]['user'] == user.uid) {
            setState(() {
              _data = outerMap;
            });
            return key;
          }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    double luminance = Color(_matkul!['color']).computeLuminance();
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat kembali saat sedang memuat...'),
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
                _matkul!['matkul']!,
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
                  child: CustomScrollView(
                    slivers: [
                      /// 🔹 Header Tetap Bisa Discroll
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Container(
                              margin: EdgeInsets.all(20.0),
                              padding: EdgeInsets.all(20.0),
                              height: MediaQuery.of(context).size.height * 0.25,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.0),
                                border: Border.all(
                                  color: Colors.black,
                                  width: 5.0,
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    Color(_matkul!['color']).withOpacity(0.5),
                                    Color(_matkul!['color']),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _matkul!['matkul']!,
                                    style: TextStyle(
                                      fontSize: 24.0,
                                      fontWeight: FontWeight.bold,
                                      color: luminance > 0.24
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                  Text(
                                    _matkul!['jadwal']!,
                                    style: TextStyle(
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                      color: luminance > 0.24
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 20.0),
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isFirst = true;
                                  });
                                  _navigateAndRefresh('/task', _matkul);
                                },
                                style: ElevatedButton.styleFrom(
                                  elevation: 4,
                                  backgroundColor: Colors.green[900],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
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
                            SizedBox(height: 16.0),
                          ],
                        ),
                      ),

                      /// 🔹 Jika Ada Data, Tampilkan List
                      if (_data != null && _data!.isNotEmpty)
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            childCount: _data!.length + 1,
                            (context, index) {
                              if (index == _data!.length) {
                                return SizedBox(height: 25.0);
                              }
                              final key = _data!.keys.toList()[index];
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
                                    contentPadding: EdgeInsets.only(left: 16.0),
                                    title: Text(
                                      'Tugas Baru: ${_data![key]['title']}',
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      "Terakhir diubah: ${formatTimestamp(_data![key]['timestamp'])}",
                                      style: TextStyle(
                                        fontSize: 12.0,
                                      ),
                                    ),
                                    trailing: PopupMenuButton(
                                      menuPadding: EdgeInsets.zero,
                                      icon: Icon(Icons.more_vert),
                                      itemBuilder: (context) {
                                        return [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Hapus'),
                                          ),
                                        ];
                                      },
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          setState(() {
                                            _isFirst = true;
                                          });
                                          _navigateAndRefresh(
                                              '/task', _data![key]);
                                        }
                                        if (value == 'delete') {
                                          setState(() {
                                            // _data!.remove(key);
                                          });
                                        }
                                      },
                                    ),
                                    onTap: () async {
                                      final set = await userCheck(key);
                                      if (_isAdmin) {
                                        _navigateAndRefresh('/datalog', {
                                          'matkul': _matkul!['matkul'],
                                          'uid': key
                                        });
                                      } else if (!_isAdmin) {
                                        if (set != null) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                            content: Text(set.toString()),
                                          ));
                                          _navigateAndRefresh('/datalog', {
                                            'matkul': _matkul!['matkul'],
                                            'uid': key,
                                            'postUser': _data![set]['userPost'],
                                          });
                                        } else {
                                          _navigateAndRefresh(
                                            '/presence',
                                            {
                                              'matkul': _matkul!['matkul'],
                                              'uid': key,
                                            },
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Stack(
                            children: [
                              _isLoading
                                  ? Container()
                                  : Center(
                                      child: Container(
                                        margin: EdgeInsets.symmetric(
                                            horizontal: 50.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.calendar_month_rounded,
                                              size: 100.0,
                                            ),
                                            SizedBox(height: 16.0),
                                            Text(
                                              'Belum ada tugas ditambahkan',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 8.0),
                                            Text(
                                              'Silahkan menambahkan tugas terlebih dahulu untuk diberikan kepada mahasiswa.',
                                              style: TextStyle(
                                                fontSize: 16,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            SizedBox(height: 16.0),
                                          ],
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                    ],
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
