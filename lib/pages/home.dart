import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});
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
  Widget build(BuildContext context) {
    List<String> matkul = [
      'Pemrograman Web 1',
      'Struktur Data',
      'Basis Data',
      'Pemrograman Terstruktur',
      'Algoritma dan Pemrograman',
      'Pemrograman Berorientasi Objek',
      'Fisika Terapan',
      'Elektronika Digital',
      'Pengenalan Teknologi Informasi dan Ilmu Komputer',
      'Sistem Tertanam',
      'Sistem Operasi Komputer',
    ];
    return WillPopScope(
      onWillPop: () {
        return _onExitConfirmation(context);
      },
      child: Scaffold(
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
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
                  leading: Icon(Icons.logout),
                  title: Text('Sign Out'),
                  onTap: () {
                    Navigator.pop(context);
                    _logout(context);
                  }),
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
          child: ListView.builder(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            itemCount: matkul.length,
            itemBuilder: (context, index) {
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
                      matkul[index],
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('Pertemuan ke-1'),
                    trailing: Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/record',
                        arguments: matkul[index],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
