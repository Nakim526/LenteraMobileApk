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
  bool toClose = false;

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

  @override
  Widget build(BuildContext context) {
    Map<String, String> matkul = {
      'Pemrograman Web 1': 'Senin, 08.00-09.40',
      'Struktur Data': 'Selasa, 09.45-11.25',
      'Basis Data': 'Rabu, 12.50-14.30',
      'Pemrograman Terstruktur': 'Kamis, 14.35-16.15',
      'Algoritma dan Pemrograman': 'Jum\'at, 08.00-09.40',
      'Pemrograman Berorientasi Objek': 'Senin, 09.45-11.25',
      'Fisika Terapan': 'Selasa, 12.50-14.30',
      'Elektronika Digital': 'Rabu, 14.35-16.15',
      'Pengenalan Teknologi Informasi dan Ilmu Komputer': 'Kamis, 08.00-09.40',
      'Sistem Tertanam': 'Jum\'at, 09.45-11.25',
      'Sistem Operasi Komputer': 'Senin, 12.50-14.30',
    };
    return WillPopScope(
      onWillPop: () {
        return _onExitConfirmation(context);
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
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              ListTile(
                leading: Icon(Icons.history),
                title: Text('Data Log'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/dataLog');
                },
              ),
              ListTile(
                leading: Icon(Icons.description),
                title: Text('Notes'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/notes');
                },
              ),
              ListTile(
                leading: Icon(Icons.chat),
                title: Text('Chat'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/chat');
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
                  onPressed: () => Scaffold.of(context).openDrawer(),
                );
              },
            ),
          ),
          title: Text(
            'LENTERA MOBILE APP',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                height: MediaQuery.of(context).size.height * 0.25,
                margin: const EdgeInsets.all(20.0),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        color: Colors.white,
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
                            ),
                          ),
                          Icon(Icons.check, size: 75.0),
                        ],
                      ),
                    );
                  },
                ),
              ),
              ListView.builder(
                padding: EdgeInsets.only(bottom: 16.0),
                itemCount: matkul.length,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final key = matkul.keys.elementAt(index);
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
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(matkul[key]!),
                        trailing: Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/lesson',
                            arguments: <String, String>{
                              'matkul': key,
                              'jadwal': matkul[key]!
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
    );
  }
}
