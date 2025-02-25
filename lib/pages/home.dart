import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageController = PageController(viewportFraction: 1.0);
  DateTime _selectedDay = DateTime.now();
  final DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>>? _tasks;
  Map<dynamic, dynamic>? _userData;
  Map<dynamic, dynamic>? _data;
  Map<dynamic, dynamic>? _notif;
  double? currentProgress;
  double? totalProgress;
  bool _isLoading = false;
  bool _isProgress = false;
  bool _isClose = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    print("Halaman utama aktif!");
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isProgress = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');

        final snapshot = await userRef.get();
        if (snapshot.exists && snapshot.value != null) {
          final data = Map.from(snapshot.value as Map);
          if (data.containsKey('role') && data['role'] == 'admin') {
            setState(() {
              _isAdmin = true;
            });
          }
          Map<String, dynamic> mataKuliahData = {};

          data.forEach((key, value) {
            if (value is Map && value.containsKey('jadwal')) {
              mataKuliahData[key] = value;
            }
          });
          setState(() {
            _userData = mataKuliahData;
          });
          await getProgress();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProgress = false;
        });
      }
    }
  }

  Future<void> getProgress() async {
    bool isAdmin = _isAdmin;
    Map data = {};
    Map notif = {};
    Map totalNotif = {};
    Map<String, dynamic> updates = {};
    Map<DateTime, List<Map<String, dynamic>>> tasks = {};
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final dbRef = FirebaseDatabase.instance.ref('tasks');
      final userId = FirebaseDatabase.instance.ref('users/${user.uid}');
      for (String matkul in _userData!.keys) {
        double progress = 0;
        double total = 0;
        int pengumuman = 0;
        int kehadiran = 0;
        int tugas = 0;
        final userRef = userId.child(matkul);
        final snapshot = await dbRef.child(matkul).get();
        if (snapshot.exists) {
          final listTask = Map.from(snapshot.value as Map);
          for (var keyTask in listTask.keys) {
            if (listTask[keyTask]['type'] == 'Pengumuman' &&
                listTask[keyTask]['type'] == 'Kehadiran' &&
                listTask[keyTask]['type'] == 'Tugas') {
              if (listTask[keyTask]['deadline'] != 0) {
                DateTime taskDate = DateTime.fromMillisecondsSinceEpoch(
                    listTask[keyTask]['deadline']);
                List<Map<String, dynamic>> taskCal = [];

                taskCal.add({
                  'title': listTask[keyTask]['title'],
                  'matkul': matkul,
                });

                tasks[taskDate] = taskCal;
              }
            }
            bool found = false;
            if (listTask[keyTask]['type'] == 'Tugas' ||
                listTask[keyTask]['type'] == 'Kehadiran') {
              total += 1;
              if (isAdmin) {
                progress += 1;
              } else {
                final assignments = await userRef.child('assignments').get();
                if (assignments.exists) {
                  final userProgress = Map.from(assignments.value as Map);
                  for (var uid in userProgress.keys) {
                    if (userProgress[uid] is Map) {
                      if (userProgress[uid]['taskUid'] == keyTask) {
                        if (userProgress[uid]['status'] == 'Selesai') {
                          progress += 1;
                        } else if (userProgress[uid]['status'] == 'Terlambat') {
                          progress += 0.5;
                        }
                      }
                    }
                  }
                }
                final presences = await userRef.child('presences').get();
                if (presences.exists) {
                  final userProgress = Map.from(presences.value as Map);
                  for (var uid in userProgress.keys) {
                    if (userProgress[uid] is Map) {
                      if (userProgress[uid]['taskUid'] == keyTask) {
                        if (userProgress[uid]['status'] == 'Selesai') {
                          progress += 1;
                        } else if (userProgress[uid]['status'] == 'Terlambat') {
                          progress += 0.5;
                        }
                      }
                    }
                  }
                }
              }
              if (listTask[keyTask]['type'] == 'Tugas') {
                tugas += 1;
                final taskAssignment =
                    await dbRef.child('$matkul/$keyTask/assignments').get();
                if (taskAssignment.exists) {
                  final userAssignment = Map.from(taskAssignment.value as Map);
                  userAssignment.forEach((key, value) {
                    if (value['user'] == user.uid) {
                      found = true;
                    }
                  });
                }
                if (!found) {
                  notif[keyTask] = listTask[keyTask];
                }
              }
              if (listTask[keyTask]['type'] == 'Kehadiran') {
                kehadiran += 1;
                final taskPresence =
                    await dbRef.child('$matkul/$keyTask/presences').get();
                if (taskPresence.exists) {
                  final userPresence = Map.from(taskPresence.value as Map);
                  userPresence.forEach((key, value) {
                    if (value['user'] == user.uid) {
                      found = true;
                    }
                  });
                }
                if (!found) {
                  notif[keyTask] = listTask[keyTask];
                }
              }
            } else if (listTask[keyTask]['type'] == 'Pengumuman') {
              total += 0.5;
              if (isAdmin) {
                progress += 0.5;
              } else {
                final announcements =
                    await userRef.child('announcements').get();
                if (announcements.exists) {
                  final userProgress = Map.from(announcements.value as Map);
                  for (var uid in userProgress.keys) {
                    if (userProgress[uid] is Map) {
                      if (userProgress[uid]['taskUid'] == keyTask) {
                        if (userProgress[uid]['status'] == 'Selesai') {
                          progress += 0.5;
                        }
                      }
                    }
                  }
                }
              }
              final taskAnnouncement =
                  await dbRef.child('$matkul/$keyTask/announcements').get();
              if (taskAnnouncement.exists) {
                pengumuman += 1;
                final userAnnouncement =
                    Map.from(taskAnnouncement.value as Map);
                userAnnouncement.forEach((key, value) {
                  if (value['user'] == user.uid) {
                    found = true;
                  }
                });
              }
              if (!found) {
                notif[keyTask] = listTask[keyTask];
              }
            }
          }
        }
        setState(() {
          if (total == 0) total = 0.01;
          currentProgress = progress;
          totalProgress = isAdmin ? 30 : total;
        });
        double percentage = currentProgress! / totalProgress!;
        int percentText = (percentage * 100).toInt();
        updates = {
          matkul: {
            'progress': progress,
            'total': isAdmin ? 30 : total,
            'percentage': percentage,
            'percentText': percentText,
            'jadwal': _userData![matkul]['jadwal'],
          }
        };
        data[matkul] = {
          'progress': progress,
          'total': isAdmin ? 30 : total,
          'percentage': percentage,
          'percentText': percentText,
          'jadwal': _userData![matkul]['jadwal'],
          'pengumuman': pengumuman,
          'kehadiran': kehadiran,
          'tugas': tugas,
        };
        if (notif.isEmpty) continue;
        totalNotif[snapshot.key] = Map.from(notif);
        notif.clear();
      }
      setState(() {
        _isLoading = false;
        _data = data;
        _notif = totalNotif;
        _tasks = tasks;
      });
      await userId.update(updates);
    }
  }

  Future<void> _logout(BuildContext context) async {
    // Hapus status login dari SharedPreferences
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // Navigasi kembali ke halaman login
    Navigator.pushReplacementNamed(context, '/sign-in');
  }

  Future<bool> _onExitConfirmation(BuildContext context) async {
    return await showDialog(
          barrierDismissible: false,
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Keluar Aplikasi"),
            content: Text("Apakah Anda yakin ingin keluar?"),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text("Batal"),
              ),
              TextButton(
                onPressed: () {
                  SystemNavigator.pop();
                }, // Keluar
                child: Text("Keluar"),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _navigateAndRefresh(String routeName, Object? object) async {
    Navigator.pushReplacementNamed(context, routeName, arguments: object);
  }

  String formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'Tidak ada batas waktu';
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  String getDifference(int start, int? end) {
    if (end == 0) return '(Tidak ada batas waktu)';
    Duration difference = Duration(milliseconds: end! - start);
    int days = difference.inDays;
    int hours = difference.inHours - (days * 24);
    int minutes = difference.inMinutes - (days * 24 * 60) - (hours * 60);
    if (days > 0) return '(Sisa $days hari lagi)';
    if (hours > 0) return '(Sisa $hours jam lagi)';
    if (minutes > 0) return '(Sisa $minutes menit lagi)';
    return '(Sisa waktu habis)';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        print("onPopInvoked DIPANGGIL!");
        if (!_isClose) {
          Navigator.of(context).pop();
          setState(() {
            _isClose = true;
          });
          return;
        }

        if (_isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Mohon tunggu sebentar...")));
          return;
        }

        // Menampilkan dialog konfirmasi keluar
        bool shouldExit = await _onExitConfirmation(context);
        if (shouldExit) {
          SystemNavigator.pop(); // Keluar dari aplikasi
        }
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
            appBar: AppBar(
              backgroundColor: Colors.green[900],
              leading: Container(
                margin: const EdgeInsets.only(left: 16.0),
                child: Builder(
                  builder: (context) {
                    return IconButton(
                      icon: Icon(
                        Icons.menu,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                        _isClose = false;
                      },
                    );
                  },
                ),
              ),
              title: Text(
                'Lentera Mobile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Crestwood',
                ),
              ),
            ),
            body: Container(
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
              child: ListView(
                physics: ClampingScrollPhysics(),
                children: [
                  if (_notif != null)
                    Container(
                      alignment: Alignment.center,
                      height: MediaQuery.of(context).size.height * 0.35,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _isAdmin
                            ? _data!.length
                            : _notif!.isEmpty
                                ? 1
                                : _notif!.length,
                        itemBuilder: (context, index) {
                          if (_isAdmin) {
                            final key = _data!.keys.elementAt(index);
                            return Container(
                              margin: EdgeInsets.all(20.0),
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.0),
                                border:
                                    Border.all(color: Colors.black, width: 5.0),
                                color: Colors
                                    .primaries[index % Colors.primaries.length],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.only(
                                      top: 12.0,
                                      bottom: 12.0,
                                    ),
                                    margin: EdgeInsets.only(bottom: 8.0),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.withOpacity(0.8),
                                          width: 4.0,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      key,
                                      style: TextStyle(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.primaries[index %
                                                        Colors.primaries.length]
                                                    .computeLuminance() >
                                                0.24
                                            ? Colors.black
                                            : Colors.white,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pengumuman: ${_data![key]['pengumuman']}',
                                          style: TextStyle(
                                            color: Colors.primaries[index %
                                                            Colors.primaries
                                                                .length]
                                                        .computeLuminance() >
                                                    0.24
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'Kehadiran: ${_data![key]['kehadiran']}',
                                          style: TextStyle(
                                            color: Colors.primaries[index %
                                                            Colors.primaries
                                                                .length]
                                                        .computeLuminance() >
                                                    0.24
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                        Text(
                                          'Tugas: ${_data![key]['tugas']}',
                                          style: TextStyle(
                                            fontSize: 14.0,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.primaries[index %
                                                            Colors.primaries
                                                                .length]
                                                        .computeLuminance() >
                                                    0.24
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    alignment: Alignment.center,
                                    margin: EdgeInsets.symmetric(vertical: 8.0),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _navigateAndRefresh(
                                          '/lesson',
                                          <String, dynamic>{
                                            'matkul': key,
                                            'jadwal': _data![key]['jadwal'],
                                            'color': Colors
                                                .primaries[index %
                                                    Colors.primaries.length]
                                                .value,
                                          },
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        elevation: 4.0,
                                        backgroundColor: Colors.green[900],
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                      ),
                                      child: Text(
                                        'Lihat Aktivitas',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            );
                          } else {
                            if (_notif!.isEmpty) {
                              return Container(
                                margin: EdgeInsets.all(20.0),
                                padding: EdgeInsets.symmetric(horizontal: 24.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20.0),
                                  border: Border.all(
                                      color: Colors.black, width: 5.0),
                                  color: Colors.primaries[
                                      index % Colors.primaries.length],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Tidak ada tugas yang akan jatuh tempo',
                                        style: TextStyle(
                                          fontSize: 20.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.primaries[index %
                                                          Colors
                                                              .primaries.length]
                                                      .computeLuminance() >
                                                  0.24
                                              ? Colors.black
                                              : Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            final key = _notif!.keys.elementAt(index);
                            return Container(
                              margin: EdgeInsets.all(20.0),
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20.0),
                                border:
                                    Border.all(color: Colors.black, width: 5.0),
                                color: Colors
                                    .primaries[index % Colors.primaries.length],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.only(
                                      top: 12.0,
                                      bottom: 12.0,
                                    ),
                                    margin: EdgeInsets.only(bottom: 8.0),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.withOpacity(0.8),
                                          width: 4.0,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      key,
                                      style: TextStyle(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.primaries[index %
                                                        Colors.primaries.length]
                                                    .computeLuminance() >
                                                0.24
                                            ? Colors.black
                                            : Colors.white,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: ListView.builder(
                                      physics: NeverScrollableScrollPhysics(),
                                      itemCount: _notif![key].length,
                                      itemBuilder: (context, index) {
                                        final keyTask =
                                            _notif![key].keys.elementAt(index);
                                        if (index >= 3) {
                                          int length = _notif![key].length - 3;
                                          return Container(
                                            child: Text(
                                              'dan $length lainnya...',
                                              style: TextStyle(
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors
                                                              .primaries[index %
                                                                  Colors
                                                                      .primaries
                                                                      .length]
                                                              .computeLuminance() >
                                                          0.24
                                                      ? Colors.black
                                                      : Colors.white,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ),
                                          );
                                        }
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _notif![key][keyTask]['title'],
                                                style: TextStyle(
                                                  fontSize: 14.0,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors
                                                              .primaries[index %
                                                                  Colors
                                                                      .primaries
                                                                      .length]
                                                              .computeLuminance() >
                                                          0.24
                                                      ? Colors.black
                                                      : Colors.white,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              getDifference(
                                                DateTime.now()
                                                    .millisecondsSinceEpoch,
                                                _notif![key][keyTask]
                                                    ['deadline'],
                                              ),
                                              style: TextStyle(
                                                fontSize: 14.0,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.primaries[index %
                                                                Colors.primaries
                                                                    .length]
                                                            .computeLuminance() >
                                                        0.24
                                                    ? Colors.black
                                                    : Colors.white,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  Container(
                                    alignment: Alignment.center,
                                    margin: EdgeInsets.symmetric(vertical: 8.0),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        _navigateAndRefresh(
                                          '/lesson',
                                          <String, dynamic>{
                                            'matkul': key,
                                            'jadwal': _data![key]['jadwal'],
                                            'color': Colors
                                                .primaries[index %
                                                    Colors.primaries.length]
                                                .value,
                                          },
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        elevation: 4.0,
                                        backgroundColor: Colors.green[900],
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                      ),
                                      child: Text(
                                        'Lihat Aktivitas',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  _data == null
                      ? Container()
                      : Column(
                          children: [
                            ListView.builder(
                              itemCount: _data!.length,
                              shrinkWrap: true,
                              physics: NeverScrollableScrollPhysics(),
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
                                        key,
                                        style: TextStyle(
                                          fontSize: 15.0,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        _data![key]['jadwal'],
                                        style: TextStyle(
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      trailing: Stack(
                                        children: [
                                          _isProgress
                                              ? CircularProgressIndicator()
                                              : Stack(
                                                  children: [
                                                    CircularProgressIndicator(
                                                      value: _data![key]
                                                              ['percentage']
                                                          .toDouble(),
                                                      strokeWidth: 5.0,
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                              Color>(
                                                        Colors.green[900]!,
                                                      ),
                                                      backgroundColor:
                                                          Colors.white,
                                                    ),
                                                    Positioned.fill(
                                                      child: Center(
                                                        child: Text(
                                                          '${_data![key]['percentText']}%',
                                                          style: TextStyle(
                                                            fontSize: 10.0,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ],
                                      ),
                                      onTap: () {
                                        _navigateAndRefresh(
                                          '/lesson',
                                          <String, dynamic>{
                                            'matkul': key,
                                            'jadwal': _data![key]['jadwal'],
                                            'color': Colors
                                                .primaries[index %
                                                    Colors.primaries.length]
                                                .value,
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16.0,
                              ),
                              height: 8.0,
                              decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(4.0)),
                            ),
                            Container(
                              margin: EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 8.0,
                              ),
                              child: Material(
                                color: Colors.green.shade100,
                                elevation: 4.0,
                                clipBehavior: Clip.hardEdge,
                                borderRadius: BorderRadius.circular(16.0),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: TableCalendar(
                                    focusedDay: _selectedDay,
                                    firstDay: DateTime.utc(2000, 1, 1),
                                    lastDay: DateTime.utc(2100, 12, 12),
                                    calendarFormat: CalendarFormat.month,
                                    selectedDayPredicate: (day) {
                                      return isSameDay(_selectedDay, day);
                                    },
                                    onDaySelected: (selectedDay, focusedDay) {
                                      setState(() {
                                        _selectedDay = selectedDay;
                                      });
                                    },
                                    availableCalendarFormats: const {
                                      CalendarFormat.month: 'Month',
                                    },
                                    calendarStyle: CalendarStyle(),
                                    eventLoader: (day) {
                                      return _tasks![day] ?? [];
                                    },
                                  ),
                                ),
                              ),
                            ),
                            ListView.builder(
                              physics: NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: _tasks![_selectedDay]?.length ?? 0,
                              itemBuilder: (context, index) {
                                return ListTile(
                                  title: Text(
                                      _tasks![_selectedDay]![index]["title"]!),
                                  subtitle: Text(_tasks![_selectedDay]![index]
                                      ["description"]!),
                                );
                              },
                            ),
                            SizedBox(height: 8.0),
                          ],
                        ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
