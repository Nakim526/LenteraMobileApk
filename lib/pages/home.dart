import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController(viewportFraction: 1.0);
  Map<String, dynamic>? _userData;
  double? currentProgress = 0.0;
  bool _isLoading = false;
  bool toClose = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef = FirebaseDatabase.instance.ref('users/${user.uid}');

        final snapshot = await userRef.get();
        if (snapshot.exists && snapshot.value != null) {
          final data = snapshot.value as Map;
          Map<String, dynamic> mataKuliahData = {};

          data.forEach((key, value) {
            if (value is Map && value.containsKey('jadwal')) {
              mataKuliahData[key] = value;
            }
          });
          setState(() {
            _userData = mataKuliahData;
          });
        }
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> getTask(String idKey) async {}

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
                onPressed: () => Navigator.of(context).pop(false),
                child: Text("Batal"),
              ),
              TextButton(
                onPressed: () => SystemNavigator.pop(), // Keluar
                child: Text("Keluar"),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _navigateAndRefresh(String routeName, Object? object) async {
    await Navigator.pushNamed(context, routeName, arguments: object);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!toClose) {
          Navigator.pop(context);
          toClose = true;
          return false;
        } else {
          return _onExitConfirmation(context);
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
                      child: Text(
                        'LENTERA MOBILE APP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.home),
                    title: Text('Home'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushReplacementNamed(context, '/home');
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
                    leading: Icon(Icons.history),
                    title: Text('Data Log'),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateAndRefresh('/datalog', null);
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
                        toClose = false;
                      },
                    );
                  },
                ),
              ),
              title: Text(
                'LENTERA MOBILE APP',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  Container(
                    alignment: Alignment.center,
                    height: MediaQuery.of(context).size.height * 0.3,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: 30,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20.0),
                            border: Border.all(color: Colors.black, width: 5.0),
                            color: Colors
                                .primaries[index % Colors.primaries.length],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Belum ada tugas',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.primaries[index %
                                                  Colors.primaries.length]
                                              .computeLuminance() >
                                          0.24
                                      ? Colors.black
                                      : Colors.white,
                                ),
                              ),
                              Icon(Icons.check, size: 75.0),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  _userData == null
                      ? Container()
                      : ListView.builder(
                          padding: EdgeInsets.only(bottom: 16.0),
                          itemCount: _userData!.length,
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final key = _userData!.keys.elementAt(index);
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
                                    _userData![key]['jadwal'],
                                    style: TextStyle(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  trailing: Stack(
                                    children: [
                                      CircularProgressIndicator(
                                        value: _userData![key]['percentage']
                                            .toDouble(),
                                        strokeWidth: 5.0,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.primaries[index %
                                                          Colors
                                                              .primaries.length]
                                                      .computeLuminance() >
                                                  0.24
                                              ? Colors.white
                                              : Colors.green[900]!,
                                        ),
                                        backgroundColor: Colors.white,
                                      ),
                                      Positioned.fill(
                                        child: Center(
                                          child: Text(
                                            '${_userData![key]['percentText']}%',
                                            style: TextStyle(
                                              fontSize: 10.0,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    _navigateAndRefresh(
                                      '/lesson',
                                      <String, dynamic>{
                                        'matkul': key,
                                        'jadwal': _userData![key]['jadwal'],
                                        'color': Colors
                                            .primaries[
                                                index % Colors.primaries.length]
                                            .value,
                                      },
                                    );
                                  },
                                ),
                              ),
                            );
                          },
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
