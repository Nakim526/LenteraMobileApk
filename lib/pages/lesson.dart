import 'dart:math';

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
  Map<dynamic, dynamic>? _status;
  Map<dynamic, dynamic>? _type;
  double? currentProgress = 0.0;
  double? totalProgress = 30.0;
  String? keyId;
  String? postUser;
  bool _isAdmin = false;
  bool _isLoading = false;
  bool _isFirst = true;
  bool _isOpen = false;

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
        await getProgress();
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

  Future<void> getProgress() async {
    Map status = {};
    Map type = {};
    double progress = 0;
    double total = 0;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseDatabase.instance
          .ref('users/${user.uid}/${_matkul!['matkul']}');
      final snapshot = await _dbRef.child(_matkul!['matkul']).get();
      if (snapshot.exists) {
        final outerMap = Map.from(snapshot.value as Map);
        for (var key in outerMap.keys) {
          if (outerMap[key]['type'] == 'Tugas' ||
              outerMap[key]['type'] == 'Kehadiran') {
            total += 1;
            if (_isAdmin) {
              progress += 1;
            } else {
              final userSnapshot = await userRef.child('presences').get();
              if (userSnapshot.exists) {
                final userProgress = Map.from(userSnapshot.value as Map);
                for (var uid in userProgress.keys) {
                  if (userProgress[uid] is Map) {
                    if (userProgress[uid]['taskUid'] == key) {
                      if (userProgress[uid]['status'] == 'Selesai') {
                        progress += 1;
                      } else if (userProgress[uid]['status'] == 'Terlambat') {
                        progress += 0.5;
                      }
                      setState(() {
                        status.addAll({
                          userProgress[uid]['taskUid']: userProgress[uid]
                              ['status'],
                        });
                      });
                    }
                  }
                }
              }
            }
          }
          setState(() {
            type.addAll({
              key: outerMap[key]['type'],
            });
          });
        }
        setState(() {
          _type = type;
          _status = status;
          if (total == 0) total = 0.01;
          currentProgress = progress;
          totalProgress = _isAdmin ? 30 : total;
        });
      }
      double percentage = currentProgress! / totalProgress!;
      int percentText = (percentage * 100).toInt();
      await userRef.update({
        'progress': progress,
        'total': _isAdmin ? 30 : total,
        'percentage': percentage,
        'percentText': percentText,
        'jadwal': _matkul!['jadwal'],
      });
    }
  }

  Future<void> _navigateAndRefresh(String routeName, Object? object) async {
    await Navigator.pushNamed(context, routeName, arguments: object);
    _loadData();
  }

  String formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'Tidak ada batas waktu';
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
            return key;
          }
        }
      }
    }
    return null;
  }

  IconData getIconType(String type) {
    switch (type) {
      case 'Tugas':
        return Icons.assignment;
      case 'Kehadiran':
        return Icons.event;
      case 'Postingan':
        return Icons.announcement_outlined;
      default:
        return Icons.announcement;
    }
  }

  IconData getIconStatus(String status) {
    switch (status) {
      case 'Selesai':
        return Icons.check_circle_outline_rounded;
      case 'Terlambat':
        return Icons.warning_amber_rounded;
      default:
        return Icons.dangerous_outlined;
    }
  }

  Future<void> deleteTask(String idKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = _dbRef.child('${user.uid}/${_matkul!['matkul']}');
    }
    await _dbRef.child('${_matkul!['matkul']}/$idKey').remove();
  }

  @override
  Widget build(BuildContext context) {
    double luminance = Color(_matkul!['color']).computeLuminance();
    double percentage = currentProgress! / totalProgress!;
    int percentText = (percentage * 100).toInt();
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tidak dapat kembali saat sedang memuat...'),
            ),
          );
          return false;
        } else if (_isOpen) {
          setState(() {
            _isOpen = false;
          });
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
                !_isOpen
                    ? Container(
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
                                    height: MediaQuery.of(context).size.height *
                                        0.25,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20.0),
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 5.0,
                                      ),
                                      gradient: LinearGradient(
                                        colors: [
                                          luminance < 0.24
                                              ? Colors.grey[700]!
                                              : Colors.grey[300]!,
                                          Color(_matkul!['color']),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.center,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        Expanded(child: Container()),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: LinearProgressIndicator(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  10.0,
                                                ),
                                                value: percentage,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(
                                                  luminance > 0.24
                                                      ? Colors.black
                                                      : Colors.white,
                                                ),
                                                minHeight: 5.0,
                                                backgroundColor:
                                                    luminance > 0.24
                                                        ? Colors.white
                                                        : Colors.black,
                                              ),
                                            ),
                                            SizedBox(width: 10.0),
                                            Text(
                                              '$percentText%',
                                              style: TextStyle(
                                                fontSize: 12.0,
                                                fontWeight: FontWeight.bold,
                                                color: luminance > 0.24
                                                    ? Colors.black
                                                    : Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isAdmin)
                                    Column(
                                      children: [
                                        Container(
                                          margin: EdgeInsets.symmetric(
                                              horizontal: 20.0),
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              _navigateAndRefresh(
                                                  '/task', _matkul);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              elevation: 4,
                                              backgroundColor:
                                                  Colors.green[900],
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
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
                                    )
                                  else if (!_isLoading)
                                    Column(
                                      children: [
                                        Container(
                                          margin: EdgeInsets.symmetric(
                                            horizontal: 20.0,
                                          ),
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              _navigateAndRefresh(
                                                '/task',
                                                {
                                                  'matkul': _matkul!['matkul'],
                                                  'users': true,
                                                },
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              elevation: 4,
                                              backgroundColor:
                                                  Colors.green[900],
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: 20.0,
                                                horizontal: 16.0,
                                              ),
                                              alignment: Alignment.centerLeft,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.post_add_rounded,
                                                  size: 20.0,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 10.0),
                                                Expanded(
                                                  child: Text(
                                                    'Posting sesuatu kepada seluruh peserta',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 12.0,
                                                    ),
                                                    textAlign: TextAlign.left,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 16.0),
                                      ],
                                    ),
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
                                        borderRadius:
                                            BorderRadius.circular(16.0),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.only(
                                            left: 16.0,
                                            right: 8.0,
                                          ),
                                          leading: Icon(
                                            getIconType(
                                              _type?[key] ?? '',
                                            ),
                                            size: 25,
                                            color: Colors.green[900],
                                          ),
                                          title: Text(
                                            _data![key]['title'],
                                            style: TextStyle(
                                              fontSize: 15.0,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            "Diubah: ${formatTimestamp(_data![key]['timestamp'])}",
                                            style: TextStyle(
                                              fontSize: 12.0,
                                            ),
                                          ),
                                          trailing: _isAdmin
                                              ? Container(
                                                  child: PopupMenuButton(
                                                    menuPadding:
                                                        EdgeInsets.zero,
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
                                                        _navigateAndRefresh(
                                                          '/task',
                                                          {
                                                            'matkul': _matkul![
                                                                'matkul'],
                                                            'key': key,
                                                            'data': _data![key]
                                                          },
                                                        );
                                                      }
                                                      if (value == 'delete') {
                                                        setState(() {
                                                          // _data!.remove(key);
                                                        });
                                                      }
                                                    },
                                                  ),
                                                )
                                              : _type?[key] == 'Postingan'
                                                  ? PopupMenuButton(
                                                      itemBuilder: (context) {
                                                        return [
                                                          PopupMenuItem(
                                                            value: 'edit',
                                                            child: Text('Edit'),
                                                          ),
                                                          PopupMenuItem(
                                                            value: 'delete',
                                                            child:
                                                                Text('Hapus'),
                                                          ),
                                                        ];
                                                      },
                                                      onSelected: (value) {
                                                        if (value == 'edit') {
                                                          _navigateAndRefresh(
                                                            '/task',
                                                            {
                                                              'matkul':
                                                                  _matkul![
                                                                      'matkul'],
                                                              'key': key,
                                                              'data':
                                                                  _data![key],
                                                              'users': true
                                                            },
                                                          );
                                                        }
                                                        if (value == 'delete') {
                                                          setState(() {
                                                            // _data!.remove(key);
                                                          });
                                                        }
                                                      },
                                                    )
                                                  : Container(
                                                      margin: EdgeInsets.only(
                                                          right: 12.0),
                                                      child: Icon(
                                                        getIconStatus(
                                                          _status?[key] ?? '',
                                                        ),
                                                        color: _status?[key] ==
                                                                'Selesai'
                                                            ? Colors.green[900]
                                                            : _status?[key] ==
                                                                    'Terlambat'
                                                                ? Colors
                                                                    .amber[900]
                                                                : Colors.redAccent[
                                                                    700],
                                                        size: 24.0,
                                                      ),
                                                    ),
                                          onTap: () async {
                                            setState(() {
                                              keyId = key;
                                              _isOpen = true;
                                            });
                                            // final set = await userCheck(key);
                                            // if (_isAdmin) {
                                            //   _navigateAndRefresh('/datalog', {
                                            //     'matkul': _matkul!['matkul'],
                                            //     'uid': key
                                            //   });
                                            // } else if (!_isAdmin) {
                                            //   if (set != null) {
                                            //     _navigateAndRefresh(
                                            //         '/datalog', {
                                            //       'matkul': _matkul!['matkul'],
                                            //       'uid': key,
                                            //       'postUser': _data![key]
                                            //               ['presences'][set]
                                            //           ['userPost'],
                                            //     });
                                            //   } else {
                                            //     _navigateAndRefresh(
                                            //       '/presence',
                                            //       {
                                            //         'matkul':
                                            //             _matkul!['matkul'],
                                            //         'uid': key,
                                            //       },
                                            //     );
                                            //   }
                                            // }
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
                                                    Icons
                                                        .calendar_month_rounded,
                                                    size: 100.0,
                                                  ),
                                                  SizedBox(height: 16.0),
                                                  Text(
                                                    'Belum ada tugas ditambahkan',
                                                    style: TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                      )
                    : Stack(
                        children: [
                          // if (_data![keyId]['type'] == 'Tugas')
                          Container(
                            margin: EdgeInsets.all(20),
                            child: ListView(
                              children: [
                                IntrinsicHeight(
                                  child: Container(
                                    padding: EdgeInsets.all(8.0),
                                    width: double.infinity,
                                    height: min(500, 200),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          width: 2.0,
                                          color: Colors.black12,
                                        ),
                                      ),
                                    ),
                                    // alignment: Alignment.topLeft,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _data![keyId]['title'],
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        _data![keyId]['description'] != ''
                                            ? Column(
                                                children: [
                                                  SizedBox(height: 8.0),
                                                  Text(
                                                    _data![keyId]
                                                        ['description'],
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : SizedBox(height: 0),
                                      ],
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                      'Batas Waktu: ${formatTimestamp(_data![keyId]['deadline'] ?? 0)}'),
                                )
                              ],
                            ),
                          ),
                        ],
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
